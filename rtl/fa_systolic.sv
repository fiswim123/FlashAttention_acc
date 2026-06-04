// =============================================================================
// Module: fa_systolic
// Description: 16-wide MAC array with 3-stage pipeline (INPUT_REG -> MULTIPLY -> ACCUMULATE).
//              Supports Q*K^T (mac_mode=0) and score*V (mac_mode=1) operations.
// MAS: M04 | Type: compute | Deps: none (leaf)
// =============================================================================
module fa_systolic (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        mac_start,
    output logic        mac_done,
    input  logic        mac_mode,    // 0=QK_MAC, 1=SV_MAC
    input  logic [255:0] q_data,     // 16 x Q8.8 (Q or score depending on mode)
    input  logic [255:0] kv_data,    // 16 x Q8.8 (K or V depending on mode)
    input  logic [255:0] score_in,   // 16 x Q8.8 (for SV mode passthrough)
    output logic [639:0] acc_out,    // 16 x 40-bit accumulation results
    input  logic        acc_clear    // Clear accumulators (pulse)
);

    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        MAC_RUN   = 2'b01,
        MAC_FLUSH = 2'b11,
        MAC_DONE  = 2'b10
    } mac_state_t;

    mac_state_t state, next;

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
            IDLE:      next = mac_start ? MAC_RUN : IDLE;
            MAC_RUN:   next = (elem_cnt == 6'd63) ? MAC_FLUSH : MAC_RUN;
            MAC_FLUSH: next = (flush_cnt == 2'd1) ? MAC_DONE : MAC_FLUSH;
            MAC_DONE:  next = IDLE;
            default:   next = IDLE;
        endcase
    end

    // Output assignments (Moore)
    assign mac_done = (state == MAC_DONE);
    wire   busy     = (state == MAC_RUN);

    // =========================================================================
    // Element counter (0..63 for 64-element accumulation)
    // =========================================================================
    logic [5:0] elem_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            elem_cnt <= 6'd0;
        else if (state == MAC_RUN)
            elem_cnt <= elem_cnt + 1'b1;
        else if (state == IDLE)
            elem_cnt <= 6'd0;
    end

    // =========================================================================
    // Flush counter (2 cycles to drain pipeline after last element)
    // =========================================================================
    logic [1:0] flush_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            flush_cnt <= 2'd0;
        else if (state == MAC_FLUSH)
            flush_cnt <= flush_cnt + 1'b1;
        else
            flush_cnt <= 2'd0;
    end

    // =========================================================================
    // Pipeline Stage 1: INPUT_REG
    // =========================================================================
    // Select input source based on mac_mode
    logic [255:0] a_input;  // Left operand (Q or score)
    logic [255:0] b_input;  // Right operand (K or V)

    always_comb begin
        if (mac_mode == 1'b0) begin
            // QK mode: Q * K^T
            a_input = q_data;
            b_input = kv_data;
        end else begin
            // SV mode: score * V
            a_input = score_in;
            b_input = kv_data;
        end
    end

    // Stage 1 registers
    logic [255:0] a_reg, b_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 256'h0;
            b_reg <= 256'h0;
        end else if (state == MAC_RUN) begin
            a_reg <= a_input;
            b_reg <= b_input;
        end
    end

    // =========================================================================
    // Pipeline Stage 2: MULTIPLY (16 parallel 16x16 multipliers)
    // =========================================================================
    logic signed [31:0] mul_result [0:15];

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            logic signed [15:0] a_elem, b_elem;
            a_elem = a_reg[i*16 +: 16];
            b_elem = b_reg[i*16 +: 16];
            mul_result[i] = a_elem * b_elem;  // Q8.8 * Q8.8 = Q16.16
        end
    end

    // Stage 2 registers
    logic signed [31:0] mul_reg [0:15];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++)
                mul_reg[i] <= 32'h0;
        end else if (state == MAC_RUN) begin
            for (int i = 0; i < 16; i++)
                mul_reg[i] <= mul_result[i];
        end
    end

    // =========================================================================
    // Pipeline Stage 3: ACCUMULATE (16 parallel 40-bit accumulators)
    // =========================================================================
    logic signed [39:0] acc_reg [0:15];

    // Pipeline fill gate: skip first 2 cycles of MAC_RUN (pipeline latency)
    // Accumulate only during valid pipeline output (cycles 2..63 of MAC_RUN)
    wire acc_en = (state == MAC_RUN) && (elem_cnt >= 6'd2);

    // Accumulate: acc_new = acc_old + mul_result (sign-extend 32->40)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++)
                acc_reg[i] <= 40'h0;
        end else if (acc_clear) begin
            for (int i = 0; i < 16; i++)
                acc_reg[i] <= 40'h0;
        end else if (acc_en) begin
            for (int i = 0; i < 16; i++) begin
                logic signed [39:0] mul_ext;
                mul_ext = {{8{mul_reg[i][31]}}, mul_reg[i]};
                acc_reg[i] <= acc_reg[i] + mul_ext;
            end
        end
    end

    // =========================================================================
    // Output: pack 16 x 40-bit accumulators into 640-bit output
    // =========================================================================
    always_comb begin
        for (int i = 0; i < 16; i++)
            acc_out[i*40 +: 40] = acc_reg[i];
    end

endmodule
