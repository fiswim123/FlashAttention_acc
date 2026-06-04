// =============================================================================
// Module: fa_softmax
// Description: Online softmax unit with 4-stage pipeline:
//              S1: tree max -> S2: ROM read -> S3: interpolation -> S4: sum/scale
// MAS: M05 | Type: compute | Deps: none (leaf)
// =============================================================================
module fa_softmax (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        sm_start,
    output logic        sm_done,
    input  logic [255:0] score,       // 16 x Q8.8
    input  logic [39:0] m_old,        // Q8.32
    input  logic [39:0] l_old,        // Q8.32
    output logic [39:0] m_new,        // Q8.32
    output logic [39:0] l_new,        // Q8.32
    output logic [15:0] correction,   // Q8.8
    output logic [255:0] exp_out,     // 16 x Q8.8
    input  logic [15:0] causal_mask   // 16-bit mask (1=valid, 0=masked)
);

    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        FIND_MAX  = 3'b001,
        EXP_TABLE = 3'b010,
        SUM_EXP   = 3'b011,
        SCALE_ACC = 3'b100,
        DONE      = 3'b101
    } sm_state_t;

    sm_state_t state, next;

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next;
    end

    // Next state logic
    always_comb begin
        next = state;
        case (state)
            IDLE:      next = sm_start ? FIND_MAX : IDLE;
            FIND_MAX:  next = EXP_TABLE;
            EXP_TABLE: next = SUM_EXP;
            SUM_EXP:   next = SCALE_ACC;
            SCALE_ACC: next = DONE;
            DONE:      next = IDLE;
            default:   next = IDLE;
        endcase
    end

    // Output assignments (Moore)
    assign sm_done = (state == DONE);

    // =========================================================================
    // Score elements unpacking
    // =========================================================================
    logic signed [15:0] score_elem [0:15];

    always_comb begin
        for (int i = 0; i < 16; i++)
            score_elem[i] = score[i*16 +: 16];
    end

    // =========================================================================
    // Stage 1: FIND_MAX - 4-level tree comparison (16 -> 8 -> 4 -> 2 -> 1)
    // =========================================================================
    logic signed [15:0] max_score;
    logic signed [39:0] m_new_comb;

    // Apply causal mask: masked elements get -inf (0x8000 in Q8.8)
    logic signed [15:0] masked_score [0:15];

    always_comb begin
        for (int i = 0; i < 16; i++)
            masked_score[i] = causal_mask[i] ? score_elem[i] : 16'sh8000;
    end

    // 4-level max tree
    logic signed [15:0] max_lvl1 [0:7];
    logic signed [15:0] max_lvl2 [0:3];
    logic signed [15:0] max_lvl3 [0:1];

    always_comb begin
        // Level 1: 16 -> 8
        for (int i = 0; i < 8; i++) begin
            max_lvl1[i] = (masked_score[2*i] >= masked_score[2*i+1]) ?
                          masked_score[2*i] : masked_score[2*i+1];
        end
        // Level 2: 8 -> 4
        for (int i = 0; i < 4; i++) begin
            max_lvl2[i] = (max_lvl1[2*i] >= max_lvl1[2*i+1]) ?
                          max_lvl1[2*i] : max_lvl1[2*i+1];
        end
        // Level 3: 4 -> 2
        max_lvl3[0] = (max_lvl2[0] >= max_lvl2[1]) ? max_lvl2[0] : max_lvl2[1];
        max_lvl3[1] = (max_lvl2[2] >= max_lvl2[3]) ? max_lvl2[2] : max_lvl2[3];
        // Level 4: 2 -> 1
        max_score = (max_lvl3[0] >= max_lvl3[1]) ? max_lvl3[0] : max_lvl3[1];
    end

    // Compare with m_old to get m_new
    // m_new = max(max_score, m_old) but m_old is 40-bit, max_score is 16-bit
    // Sign-extend max_score to 40-bit for comparison
    wire signed [39:0] max_score_ext = {{24{max_score[15]}}, max_score};

    always_comb begin
        m_new_comb = (max_score_ext >= $signed(m_old)) ? max_score_ext : m_old;
    end

    // Pipeline register for m_new (captured after FIND_MAX stage)
    logic signed [39:0] m_new_reg;
    logic signed [39:0] m_old_reg;
    logic signed [39:0] l_old_reg;
    logic signed [15:0] max_score_reg;
    logic [15:0]        causal_mask_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_new_reg     <= 40'sh80_0000_0000;  // -inf in Q8.32
            m_old_reg     <= 40'h0;
            l_old_reg     <= 40'h0;
            max_score_reg <= 16'h0;
            causal_mask_reg <= 16'h0;
        end else if (state == IDLE && sm_start) begin
            m_new_reg     <= m_new_comb;
            m_old_reg     <= m_old;
            l_old_reg     <= l_old;
            max_score_reg <= max_score;
            causal_mask_reg <= causal_mask;
        end
    end

    assign m_new = m_new_reg;

    // =========================================================================
    // Stage 2: EXP_TABLE - ROM lookup with address generation
    // Address: (score - m_new + 8) * 256/8 = (score - m_new) * 32 + 256
    // Saturate to [0, 255]
    // =========================================================================
    logic [7:0]  rom_addr [0:15];
    logic signed [39:0] m_new_for_addr;

    assign m_new_for_addr = m_new_reg;

    logic signed [39:0] diff_val [0:15];
    logic signed [39:0] offset_val [0:15];
    logic [39:0] addr_raw_val [0:15];

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            // score[i] - m_new (Q8.8 - Q8.32 -> extend to common precision)
            diff_val[i] = {{24{masked_score[i][15]}}, masked_score[i]} - m_new_for_addr;
            // diff is negative or zero (since m_new >= max_score >= each score)
            // Map to LUT address: (diff + 8) * 32
            // diff is Q8.32, +8 means +8*256=2048 in integer, *32 = shift left 5
            offset_val[i] = diff_val[i] + 40'sd2048;  // +8.0 in Q8.32
            // Shift right by (32-5)=27 to get address in [0,255]
            addr_raw_val[i] = offset_val[i][39] ? 40'h0 : offset_val[i];  // clamp negative to 0
            // Divide by (2^32 / 256) = 2^24 to get byte address, then scale
            // Simplified: extract bits that map to [0,255]
            rom_addr[i] = addr_raw_val[i][31:24];  // Approximate mapping
        end
    end

    // ROM instantiation (from buffer_mgr, but we use local combinational lookup)
    // In this implementation, we pass the address to the buffer_mgr's LUT port
    // For self-contained module, we include a small local LUT
    logic [15:0] rom_data [0:15];

    // Simple combinational exp approximation for synthesis
    // In real implementation, this would be a ROM lookup
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            // Approximate: exp(x) for x in [-8,0], mapped to [0, 65535]
            // Using the upper bits of the address as an index
            if (rom_addr[i] == 8'd0)
                rom_data[i] = 16'h0001;  // exp(-8) ~ 0
            else if (rom_addr[i] < 8'd64)
                rom_data[i] = {8'h0, rom_addr[i][7:0]};
            else if (rom_addr[i] < 8'd128)
                rom_data[i] = 16'((int'(rom_addr[i]) - 64) * 4 + 64);
            else if (rom_addr[i] < 8'd192)
                rom_data[i] = 16'((int'(rom_addr[i]) - 128) * 16 + 320);
            else
                rom_data[i] = 16'((int'(rom_addr[i]) - 192) * 64 + 1344);
        end
    end

    // Pipeline registers for exp values
    logic [255:0] exp_out_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            exp_out_reg <= 256'h0;
        else if (state == EXP_TABLE)
            for (int i = 0; i < 16; i++)
                exp_out_reg[i*16 +: 16] <= rom_data[i];
    end

    assign exp_out = exp_out_reg;

    // =========================================================================
    // Stage 3: SUM_EXP - Tree sum of 16 exp values -> 40-bit
    // =========================================================================
    logic [39:0] sum_exp;

    // Registered sum for timing
    logic [39:0] sum_exp_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sum_exp_reg <= 40'h0;
        else if (state == SUM_EXP) begin
            // Combinational sum tree
            logic [39:0] sum_temp;
            sum_temp = 40'h0;
            for (int i = 0; i < 16; i++)
                sum_temp = sum_temp + {24'h0, exp_out_reg[i*16 +: 16]};
            sum_exp_reg <= sum_temp;
        end
    end

    assign sum_exp = sum_exp_reg;

    // =========================================================================
    // Stage 4: SCALE_ACC - correction = exp(m_old - m_new), l_new = correction*l_old + sum_exp
    // =========================================================================
    // correction = exp(m_old - m_new) -> use LUT again
    // m_old - m_new is non-positive (since m_new >= m_old in online softmax)
    logic signed [39:0] m_diff;
    logic [7:0]        corr_addr;
    logic [15:0]       corr_raw;
    logic [15:0]       correction_reg;
    logic signed [39:0] l_new_reg;

    assign m_diff = m_old_reg - m_new_reg;  // <= 0
    // Map to LUT address (same scheme as exp table)
    logic signed [39:0] m_diff_offset;
    assign m_diff_offset = m_diff + 40'sd2048;
    assign corr_addr = m_diff[39] ? 8'h0 :
                       (m_diff_offset[39] == 1'b0 ? m_diff_offset[31:24] : 8'h0);

    // Correction LUT (same approximation)
    always_comb begin
        if (corr_addr == 8'd0)
            corr_raw = 16'h0001;
        else if (corr_addr < 8'd64)
            corr_raw = {8'h0, corr_addr};
        else if (corr_addr < 8'd128)
            corr_raw = 16'((int'(corr_addr) - 64) * 4 + 64);
        else if (corr_addr < 8'd192)
            corr_raw = 16'((int'(corr_addr) - 128) * 16 + 320);
        else
            corr_raw = 16'((int'(corr_addr) - 192) * 64 + 1344);
    end

    // l_new = correction * l_old + sum_exp
    // correction is Q8.8 (16-bit), l_old is Q8.32 (40-bit)
    // product is Q8.40 (48-bit), truncate to Q8.32 (40-bit)
    logic [47:0] corr_l_prod_next;

    always_comb begin
        corr_l_prod_next = {32'h0, corr_raw} * {8'h0, l_old_reg};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            correction_reg <= 16'h0;
            l_new_reg      <= 40'h0;
        end else if (state == SCALE_ACC) begin
            correction_reg <= corr_raw;
            // Truncate: take bits [47:8] to get Q8.32 result, then add sum_exp
            l_new_reg <= corr_l_prod_next[47:8] + sum_exp_reg;
        end
    end

    assign correction = correction_reg;
    assign l_new      = l_new_reg;

endmodule
