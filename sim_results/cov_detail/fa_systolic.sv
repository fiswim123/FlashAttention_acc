//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_systolic
        // Description: 16-wide MAC array with 3-stage pipeline (INPUT_REG -> MULTIPLY -> ACCUMULATE).
        //              Supports Q*K^T (mac_mode=0) and score*V (mac_mode=1) operations.
        // MAS: M04 | Type: compute | Deps: none (leaf)
        // =============================================================================
        module fa_systolic (
 012799     input  logic        clk,
~000013     input  logic        rst_n,
 000026     input  logic        mac_start,
 000026     output logic        mac_done,
%000006     input  logic        mac_mode,    // 0=QK_MAC, 1=SV_MAC
%000007     input  logic [255:0] q_data,     // 16 x Q8.8 (Q or score depending on mode)
%000007     input  logic [255:0] kv_data,    // 16 x Q8.8 (K or V depending on mode)
%000006     input  logic [255:0] score_in,   // 16 x Q8.8 (for SV mode passthrough)
            output logic [639:0] acc_out,    // 16 x 40-bit accumulation results
~000022     input  logic        acc_clear    // Clear accumulators (pulse)
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
        
 000026     mac_state_t state, next;
        
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
 006005             IDLE:      next = mac_start ? MAC_RUN : IDLE;
 004162             MAC_RUN:   next = (elem_cnt == 6'd63) ? MAC_FLUSH : MAC_RUN;
 000130             MAC_FLUSH: next = (flush_cnt == 2'd1) ? MAC_DONE : MAC_FLUSH;
~000065             MAC_DONE:  next = IDLE;
%000000             default:   next = IDLE;
                endcase
            end
        
            // Output assignments (Moore)
            assign mac_done = (state == MAC_DONE);
 000026     wire   busy     = (state == MAC_RUN);
        
            // =========================================================================
            // Element counter (0..63 for 64-element accumulation)
            // =========================================================================
 000832     logic [5:0] elem_cnt;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n)
~000037             elem_cnt <= 6'd0;
 000832         else if (state == MAC_RUN)
 000832             elem_cnt <= elem_cnt + 1'b1;
 005967         else if (state == IDLE)
 005967             elem_cnt <= 6'd0;
            end
        
            // =========================================================================
            // Flush counter (2 cycles to drain pipeline after last element)
            // =========================================================================
 000026     logic [1:0] flush_cnt;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n)
~000037             flush_cnt <= 2'd0;
 006357         else if (state == MAC_FLUSH)
 000026             flush_cnt <= flush_cnt + 1'b1;
                else
 006357             flush_cnt <= 2'd0;
            end
        
            // =========================================================================
            // Pipeline Stage 1: INPUT_REG
            // =========================================================================
            // Select input source based on mac_mode
%000007     logic [255:0] a_input;  // Left operand (Q or score)
%000007     logic [255:0] b_input;  // Right operand (K or V)
        
 006407     always_comb begin
 006206         if (mac_mode == 1'b0) begin
                    // QK mode: Q * K^T
 006206             a_input = q_data;
 006206             b_input = kv_data;
 000355         end else begin
                    // SV mode: score * V
 000355             a_input = score_in;
 000355             b_input = kv_data;
                end
            end
        
            // Stage 1 registers
%000007     logic [255:0] a_reg, b_reg;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n) begin
~000037             a_reg <= 256'h0;
~000037             b_reg <= 256'h0;
 005985         end else if (state == MAC_RUN) begin
 000832             a_reg <= a_input;
 000832             b_reg <= b_input;
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
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n) begin
~000592             for (int i = 0; i < 16; i++)
 000592                 mul_reg[i] <= 32'h0;
 005985         end else if (state == MAC_RUN) begin
 013312             for (int i = 0; i < 16; i++)
 013312                 mul_reg[i] <= mul_result[i];
                end
            end
        
            // =========================================================================
            // Pipeline Stage 3: ACCUMULATE (16 parallel 40-bit accumulators)
            // =========================================================================
            logic signed [39:0] acc_reg [0:15];
        
            // Pipeline fill gate: skip first 2 cycles of MAC_RUN (pipeline latency)
            // Accumulate only during valid pipeline output (cycles 2..63 of MAC_RUN)
 000026     wire acc_en = (state == MAC_RUN) && (elem_cnt >= 6'd2);
        
            // Accumulate: acc_new = acc_old + mul_result (sign-extend 32->40)
 006406     always_ff @(posedge clk or negedge rst_n) begin
~000037         if (!rst_n) begin
~000592             for (int i = 0; i < 16; i++)
 000592                 acc_reg[i] <= 40'h0;
~000011         end else if (acc_clear) begin
~000176             for (int i = 0; i < 16; i++)
 000176                 acc_reg[i] <= 40'h0;
 005991         end else if (acc_en) begin
 012896             for (int i = 0; i < 16; i++) begin
                        logic signed [39:0] mul_ext;
 012896                 mul_ext = {{8{mul_reg[i][31]}}, mul_reg[i]};
 012896                 acc_reg[i] <= acc_reg[i] + mul_ext;
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
        
