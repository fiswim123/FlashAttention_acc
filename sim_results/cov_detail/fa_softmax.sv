//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_softmax
        // Description: Online softmax unit with 4-stage pipeline:
        //              S1: tree max -> S2: ROM read -> S3: interpolation -> S4: sum/scale
        // MAS: M05 | Type: compute | Deps: none (leaf)
        // =============================================================================
        module fa_softmax (
 012799     input  logic        clk,
~000013     input  logic        rst_n,
~000020     input  logic        sm_start,
~000020     output logic        sm_done,
%000006     input  logic [255:0] score,       // 16 x Q8.8
%000007     input  logic [39:0] m_old,        // Q8.32
%000006     input  logic [39:0] l_old,        // Q8.32
%000007     output logic [39:0] m_new,        // Q8.32
%000006     output logic [39:0] l_new,        // Q8.32
%000006     output logic [15:0] correction,   // Q8.8
%000006     output logic [255:0] exp_out,     // 16 x Q8.8
%000009     input  logic [15:0] causal_mask   // 16-bit mask (1=valid, 0=masked)
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
        
~000060     sm_state_t state, next;
        
            // FSM state register
 006406     always_ff @(posedge clk or negedge rst_n) begin
~006369         if (!rst_n)
~000037             state <= IDLE;
                else
 006369             state <= next;
            end
        
            // Next state logic
 006407     always_comb begin
 006407         next = state;
 006407         case (state)
 006392             IDLE:      next = sm_start ? FIND_MAX : IDLE;
~000050             FIND_MAX:  next = EXP_TABLE;
~000052             EXP_TABLE: next = SUM_EXP;
~000050             SUM_EXP:   next = SCALE_ACC;
~000050             SCALE_ACC: next = DONE;
~000050             DONE:      next = IDLE;
%000000             default:   next = IDLE;
                endcase
            end
        
            // Output assignments (Moore)
            assign sm_done = (state == DONE);
        
            // =========================================================================
            // Score elements unpacking
            // =========================================================================
%000006     logic signed [15:0] score_elem [0:15];
        
%000001     always_comb begin
~000016         for (int i = 0; i < 16; i++)
 000016             score_elem[i] = score[i*16 +: 16];
            end
        
            // =========================================================================
            // Stage 1: FIND_MAX - 4-level tree comparison (16 -> 8 -> 4 -> 2 -> 1)
            // =========================================================================
%000006     logic signed [15:0] max_score;
%000006     logic signed [39:0] m_new_comb;
        
            // Apply causal mask: masked elements get -inf (0x8000 in Q8.8)
%000008     logic signed [15:0] masked_score [0:15];
        
%000001     always_comb begin
~000016         for (int i = 0; i < 16; i++)
 000016             masked_score[i] = causal_mask[i] ? score_elem[i] : 16'sh8000;
            end
        
            // 4-level max tree
%000008     logic signed [15:0] max_lvl1 [0:7];
%000008     logic signed [15:0] max_lvl2 [0:3];
%000008     logic signed [15:0] max_lvl3 [0:1];
        
%000001     always_comb begin
                // Level 1: 16 -> 8
%000008         for (int i = 0; i < 8; i++) begin
%000008             max_lvl1[i] = (masked_score[2*i] >= masked_score[2*i+1]) ?
%000008                           masked_score[2*i] : masked_score[2*i+1];
                end
                // Level 2: 8 -> 4
%000004         for (int i = 0; i < 4; i++) begin
%000004             max_lvl2[i] = (max_lvl1[2*i] >= max_lvl1[2*i+1]) ?
%000004                           max_lvl1[2*i] : max_lvl1[2*i+1];
                end
                // Level 3: 4 -> 2
%000001         max_lvl3[0] = (max_lvl2[0] >= max_lvl2[1]) ? max_lvl2[0] : max_lvl2[1];
%000001         max_lvl3[1] = (max_lvl2[2] >= max_lvl2[3]) ? max_lvl2[2] : max_lvl2[3];
                // Level 4: 2 -> 1
%000001         max_score = (max_lvl3[0] >= max_lvl3[1]) ? max_lvl3[0] : max_lvl3[1];
            end
        
            // Compare with m_old to get m_new
            // m_new = max(max_score, m_old) but m_old is 40-bit, max_score is 16-bit
            // Sign-extend max_score to 40-bit for comparison
%000006     wire signed [39:0] max_score_ext = {{24{max_score[15]}}, max_score};
        
%000001     always_comb begin
%000001         m_new_comb = (max_score_ext >= $signed(m_old)) ? max_score_ext : m_old;
            end
        
            // Pipeline register for m_new (captured after FIND_MAX stage)
%000007     logic signed [39:0] m_new_reg;
%000006     logic signed [39:0] m_old_reg;
%000002     logic signed [39:0] l_old_reg;
%000006     logic signed [15:0] max_score_reg;
%000006     logic [15:0]        causal_mask_reg;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n) begin
~000037             m_new_reg     <= 40'sh80_0000_0000;  // -inf in Q8.32
~000037             m_old_reg     <= 40'h0;
~000037             l_old_reg     <= 40'h0;
~000037             max_score_reg <= 16'h0;
~000037             causal_mask_reg <= 16'h0;
~006366         end else if (state == IDLE && sm_start) begin
~000010             m_new_reg     <= m_new_comb;
~000010             m_old_reg     <= m_old;
~000010             l_old_reg     <= l_old;
~000010             max_score_reg <= max_score;
~000010             causal_mask_reg <= causal_mask;
                end
            end
        
            assign m_new = m_new_reg;
        
            // =========================================================================
            // Stage 2: EXP_TABLE - ROM lookup with address generation
            // Address: (score - m_new + 8) * 256/8 = (score - m_new) * 32 + 256
            // Saturate to [0, 255]
            // =========================================================================
%000008     logic [7:0]  rom_addr [0:15];
%000007     logic signed [39:0] m_new_for_addr;
        
            assign m_new_for_addr = m_new_reg;
        
            logic signed [39:0] diff_val [0:15];
            logic signed [39:0] offset_val [0:15];
            logic [39:0] addr_raw_val [0:15];
        
%000001     always_comb begin
~000016         for (int i = 0; i < 16; i++) begin
                    // score[i] - m_new (Q8.8 - Q8.32 -> extend to common precision)
 000016             diff_val[i] = {{24{masked_score[i][15]}}, masked_score[i]} - m_new_for_addr;
                    // diff is negative or zero (since m_new >= max_score >= each score)
                    // Map to LUT address: (diff + 8) * 32
                    // diff is Q8.32, +8 means +8*256=2048 in integer, *32 = shift left 5
 000016             offset_val[i] = diff_val[i] + 40'sd2048;  // +8.0 in Q8.32
                    // Shift right by (32-5)=27 to get address in [0,255]
 000016             addr_raw_val[i] = offset_val[i][39] ? 40'h0 : offset_val[i];  // clamp negative to 0
                    // Divide by (2^32 / 256) = 2^24 to get byte address, then scale
                    // Simplified: extract bits that map to [0,255]
 000016             rom_addr[i] = addr_raw_val[i][31:24];  // Approximate mapping
                end
            end
        
            // ROM instantiation (from buffer_mgr, but we use local combinational lookup)
            // In this implementation, we pass the address to the buffer_mgr's LUT port
            // For self-contained module, we include a small local LUT
%000009     logic [15:0] rom_data [0:15];
        
            // Simple combinational exp approximation for synthesis
            // In real implementation, this would be a ROM lookup
 006407     always_comb begin
 102512         for (int i = 0; i < 16; i++) begin
                    // Approximate: exp(x) for x in [-8,0], mapped to [0, 65535]
                    // Using the upper bits of the address as an index
 085052             if (rom_addr[i] == 8'd0)
 085052                 rom_data[i] = 16'h0001;  // exp(-8) ~ 0
%000000             else if (rom_addr[i] < 8'd64)
%000000                 rom_data[i] = {8'h0, rom_addr[i][7:0]};
%000000             else if (rom_addr[i] < 8'd128)
%000000                 rom_data[i] = 16'((int'(rom_addr[i]) - 64) * 4 + 64);
~017460             else if (rom_addr[i] < 8'd192)
%000000                 rom_data[i] = 16'((int'(rom_addr[i]) - 128) * 16 + 320);
                    else
~017460                 rom_data[i] = 16'((int'(rom_addr[i]) - 192) * 64 + 1344);
                end
            end
        
            // Pipeline registers for exp values
%000006     logic [255:0] exp_out_reg;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n)
~000037             exp_out_reg <= 256'h0;
~006366         else if (state == EXP_TABLE)
~000160             for (int i = 0; i < 16; i++)
 000160                 exp_out_reg[i*16 +: 16] <= rom_data[i];
            end
        
            assign exp_out = exp_out_reg;
        
            // =========================================================================
            // Stage 3: SUM_EXP - Tree sum of 16 exp values -> 40-bit
            // =========================================================================
%000006     logic [39:0] sum_exp;
        
            // Registered sum for timing
%000006     logic [39:0] sum_exp_reg;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n)
~000037             sum_exp_reg <= 40'h0;
~006366         else if (state == SUM_EXP) begin
                    // Combinational sum tree
                    logic [39:0] sum_temp;
~000010             sum_temp = 40'h0;
~000160             for (int i = 0; i < 16; i++)
 000160                 sum_temp = sum_temp + {24'h0, exp_out_reg[i*16 +: 16]};
~000010             sum_exp_reg <= sum_temp;
                end
            end
        
            assign sum_exp = sum_exp_reg;
        
            // =========================================================================
            // Stage 4: SCALE_ACC - correction = exp(m_old - m_new), l_new = correction*l_old + sum_exp
            // =========================================================================
            // correction = exp(m_old - m_new) -> use LUT again
            // m_old - m_new is non-positive (since m_new >= m_old in online softmax)
%000008     logic signed [39:0] m_diff;
%000000     logic [7:0]        corr_addr;
%000001     logic [15:0]       corr_raw;
%000006     logic [15:0]       correction_reg;
%000006     logic signed [39:0] l_new_reg;
        
            assign m_diff = m_old_reg - m_new_reg;  // <= 0
            // Map to LUT address (same scheme as exp table)
%000009     logic signed [39:0] m_diff_offset;
            assign m_diff_offset = m_diff + 40'sd2048;
            assign corr_addr = m_diff[39] ? 8'h0 :
                               (m_diff_offset[39] == 1'b0 ? m_diff_offset[31:24] : 8'h0);
        
            // Correction LUT (same approximation)
 006407     always_comb begin
 006407         if (corr_addr == 8'd0)
 006407             corr_raw = 16'h0001;
%000000         else if (corr_addr < 8'd64)
%000000             corr_raw = {8'h0, corr_addr};
%000000         else if (corr_addr < 8'd128)
%000000             corr_raw = 16'((int'(corr_addr) - 64) * 4 + 64);
%000000         else if (corr_addr < 8'd192)
%000000             corr_raw = 16'((int'(corr_addr) - 128) * 16 + 320);
                else
%000000             corr_raw = 16'((int'(corr_addr) - 192) * 64 + 1344);
            end
        
            // l_new = correction * l_old + sum_exp
            // correction is Q8.8 (16-bit), l_old is Q8.32 (40-bit)
            // product is Q8.40 (48-bit), truncate to Q8.32 (40-bit)
%000002     logic [47:0] corr_l_prod_next;
        
%000001     always_comb begin
%000001         corr_l_prod_next = {32'h0, corr_raw} * {8'h0, l_old_reg};
            end
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n) begin
~000037             correction_reg <= 16'h0;
~000037             l_new_reg      <= 40'h0;
~006366         end else if (state == SCALE_ACC) begin
~000010             correction_reg <= corr_raw;
                    // Truncate: take bits [47:8] to get Q8.32 result, then add sum_exp
~000010             l_new_reg <= corr_l_prod_next[47:8] + sum_exp_reg;
                end
            end
        
            assign correction = correction_reg;
            assign l_new      = l_new_reg;
        
        endmodule
        
