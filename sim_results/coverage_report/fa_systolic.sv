//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_systolic
        // Description: 16-wide MAC array with 3-stage pipeline (INPUT_REG -> MULTIPLY -> ACCUMULATE).
        //              Supports Q*K^T (mac_mode=0) and score*V (mac_mode=1) operations.
        // MAS: M04 | Type: compute | Deps: none (leaf)
        // =============================================================================
        module fa_systolic (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
 000012     input  logic        mac_start,
 000012     output logic        mac_done,
%000006     input  logic        mac_mode,    // 0=QK_MAC, 1=SV_MAC
%000002     input  logic [255:0] q_data,     // 16 x Q8.8 (Q or score depending on mode)
%000000     input  logic [255:0] kv_data,    // 16 x Q8.8 (K or V depending on mode)
%000006     input  logic [255:0] score_in,   // 16 x Q8.8 (for SV mode passthrough)
            output logic [639:0] acc_out,    // 16 x 40-bit accumulation results
%000006     input  logic        acc_clear    // Clear accumulators (pulse)
        );
        
            // =========================================================================
            // FSM States
            // =========================================================================
            typedef enum logic [1:0] {
                IDLE     = 2'b00,
                MAC_RUN  = 2'b01,
                MAC_DONE = 2'b10
            } mac_state_t;
        
 000012     mac_state_t state, next;
        
            // FSM state register
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n)
 000019             state <= IDLE;
                else
 004602             state <= next;
            end
        
            // Next state logic
 004622     always_comb begin
 004622         next = state;
 004622         case (state)
 004232             IDLE:     next = mac_start ? MAC_RUN : IDLE;
 000384             MAC_RUN:  next = (elem_cnt == 6'd63) ? MAC_DONE : MAC_RUN;
%000006             MAC_DONE: next = IDLE;
%000000             default:  next = IDLE;
                endcase
            end
        
            // Output assignments (Moore)
            assign mac_done = (state == MAC_DONE);
 000012     wire   busy     = (state == MAC_RUN);
        
            // =========================================================================
            // Element counter (0..63 for 64-element accumulation)
            // =========================================================================
 000384     logic [5:0] elem_cnt;
        
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             elem_cnt <= 6'd0;
 000384         else if (state == MAC_RUN)
 000384             elem_cnt <= elem_cnt + 1'b1;
~004212         else if (state == IDLE)
 004212             elem_cnt <= 6'd0;
            end
        
            // =========================================================================
            // Pipeline Stage 1: INPUT_REG
            // =========================================================================
            // Select input source based on mac_mode
%000007     logic [255:0] a_input;  // Left operand (Q or score)
%000000     logic [255:0] b_input;  // Right operand (K or V)
        
 004622     always_comb begin
 004427         if (mac_mode == 1'b0) begin
                    // QK mode: Q * K^T
 004427             a_input = q_data;
 004427             b_input = kv_data;
 000195         end else begin
                    // SV mode: score * V
 000195             a_input = score_in;
 000195             b_input = kv_data;
                end
            end
        
            // Stage 1 registers
%000006     logic [255:0] a_reg, b_reg;
        
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n) begin
 000019             a_reg <= 256'h0;
 000019             b_reg <= 256'h0;
 004218         end else if (state == MAC_RUN) begin
 000384             a_reg <= a_input;
 000384             b_reg <= b_input;
                end
            end
        
            // =========================================================================
            // Pipeline Stage 2: MULTIPLY (16 parallel 16x16 multipliers)
            // =========================================================================
            logic signed [31:0] mul_result [0:15];
        
%000001     always_comb begin
~000016         for (int i = 0; i < 16; i++) begin
                    logic signed [15:0] a_elem, b_elem;
 000016             a_elem = a_reg[i*16 +: 16];
 000016             b_elem = b_reg[i*16 +: 16];
 000016             mul_result[i] = a_elem * b_elem;  // Q8.8 * Q8.8 = Q16.16
                end
            end
        
            // Stage 2 registers
            logic signed [31:0] mul_reg [0:15];
        
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n) begin
 000304             for (int i = 0; i < 16; i++)
 000304                 mul_reg[i] <= 32'h0;
 004218         end else if (state == MAC_RUN) begin
 006144             for (int i = 0; i < 16; i++)
 006144                 mul_reg[i] <= mul_result[i];
                end
            end
        
            // =========================================================================
            // Pipeline Stage 3: ACCUMULATE (16 parallel 40-bit accumulators)
            // =========================================================================
            logic signed [39:0] acc_reg [0:15];
        
            // Accumulate: acc_new = acc_old + mul_result (sign-extend 32->40)
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n) begin
 000304             for (int i = 0; i < 16; i++)
 000304                 acc_reg[i] <= 40'h0;
%000006         end else if (acc_clear) begin
~000096             for (int i = 0; i < 16; i++)
 000096                 acc_reg[i] <= 40'h0;
 004212         end else if (state == MAC_RUN) begin
 006144             for (int i = 0; i < 16; i++) begin
                        logic signed [39:0] mul_ext;
 006144                 mul_ext = {{8{mul_reg[i][31]}}, mul_reg[i]};
 006144                 acc_reg[i] <= acc_reg[i] + mul_ext;
                    end
                end
            end
        
            // =========================================================================
            // Output: pack 16 x 40-bit accumulators into 640-bit output
            // =========================================================================
%000001     always_comb begin
~000016         for (int i = 0; i < 16; i++)
 000016             acc_out[i*40 +: 40] = acc_reg[i];
            end
        
        endmodule
        
