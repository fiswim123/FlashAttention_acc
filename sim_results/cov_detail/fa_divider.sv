//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_divider
        // Description: Iterative restoring divider, 16 iterations. 40-bit Q8.32 / 40-bit Q8.32 -> 16-bit Q8.8
        //              Dividend is left-shifted 8 bits to produce Q8.8 output from Q8.32 inputs.
        // MAS: M06 | Type: compute | Deps: none (leaf)
        // =============================================================================
        module fa_divider (
 012799     input  logic        clk,
~000013     input  logic        rst_n,
~000032     input  logic        div_start,
~000032     output logic        div_done,
~000011     input  logic [39:0] dividend,
%000009     input  logic [39:0] divisor,
~000017     output logic [15:0] quotient,
~000032     output logic        busy
        );
        
            // =========================================================================
            // FSM States
            // =========================================================================
            typedef enum logic [1:0] {
                IDLE     = 2'b00,
                DIV_RUN  = 2'b01,
                DIV_DONE = 2'b10
            } div_state_t;
        
~000032     div_state_t state, next;
        
            // =========================================================================
            // Registers
            // =========================================================================
~000240     logic [4:0]  iter_cnt;
~000016     logic [47:0] remainder_reg;   // Q8.40 (dividend shifted left 8 bits)
%000009     logic [47:0] divisor_reg;     // Q8.40 (divisor zero-padded to 48 bits)
~000017     logic [15:0] quotient_reg;
%000002     logic        div_by_zero;
        
            // =========================================================================
            // FSM: State register
            // =========================================================================
 006406     always_ff @(posedge clk or negedge rst_n) begin
~006369         if (!rst_n)
~000037             state <= IDLE;
                else
 006369             state <= next;
            end
        
            // =========================================================================
            // FSM: Next state logic
            // =========================================================================
 006407     always_comb begin
 006407         next = state;
 006407         case (state)
 006407             IDLE: begin
~006407                 if (div_start)
~000016                     next = DIV_RUN;
                    end
~001209             DIV_RUN: begin
~001129                 if (div_by_zero || iter_cnt == 5'd15)
~000080                     next = DIV_DONE;
                    end
~000080             DIV_DONE: next = IDLE;
%000000             default:   next = IDLE;
                endcase
            end
        
            // =========================================================================
            // Restoring Division Algorithm
            // =========================================================================
            // For Q8.8 output from Q8.32 inputs:
            //   quotient = (dividend << 8) / divisor
            //   In Q8.40 arithmetic: remainder(48b) / divisor(48b) -> quotient(16b)
            //
            // Iteration i (i = 0..15, MSB first):
            //   bit_pos = 15 - i
            //   trial   = (remainder << 1) - divisor
            //   if trial >= 0: remainder = trial, quotient[bit_pos] = 1
            //   else: quotient[bit_pos] = 0
        
~000040     logic [47:0] divisor_shifted;
~000066     logic [48:0] trial;
~000241     logic [4:0]  bit_pos;
        
            assign bit_pos = 5'd15 - iter_cnt;
        
            // Trial subtraction: (remainder << 1) - divisor
            // Shift divisor left by (bit_pos + 1) for trial comparison
 006407     always_comb begin
 006407         divisor_shifted = 48'h0;
 006407         case (bit_pos + 5'd1)
~000015             5'd1:  divisor_shifted = {divisor_reg[46:0], 1'b0};
~000015             5'd2:  divisor_shifted = {divisor_reg[45:0], 2'b0};
~000015             5'd3:  divisor_shifted = {divisor_reg[44:0], 3'b0};
~000015             5'd4:  divisor_shifted = {divisor_reg[43:0], 4'b0};
~000015             5'd5:  divisor_shifted = {divisor_reg[42:0], 5'b0};
~000015             5'd6:  divisor_shifted = {divisor_reg[41:0], 6'b0};
~000015             5'd7:  divisor_shifted = {divisor_reg[40:0], 7'b0};
~000015             5'd8:  divisor_shifted = {divisor_reg[39:0], 8'b0};
~000015             5'd9:  divisor_shifted = {divisor_reg[38:0], 9'b0};
~000015             5'd10: divisor_shifted = {divisor_reg[37:0], 10'b0};
~000015             5'd11: divisor_shifted = {divisor_reg[36:0], 11'b0};
~000015             5'd12: divisor_shifted = {divisor_reg[35:0], 12'b0};
~000015             5'd13: divisor_shifted = {divisor_reg[34:0], 13'b0};
~000015             5'd14: divisor_shifted = {divisor_reg[33:0], 14'b0};
~000015             5'd15: divisor_shifted = {divisor_reg[32:0], 15'b0};
 006407             5'd16: divisor_shifted = {divisor_reg[31:0], 16'b0};
%000000             5'd17: divisor_shifted = {divisor_reg[30:0], 17'b0};
%000000             5'd18: divisor_shifted = {divisor_reg[29:0], 18'b0};
%000000             5'd19: divisor_shifted = {divisor_reg[28:0], 19'b0};
%000000             5'd20: divisor_shifted = {divisor_reg[27:0], 20'b0};
%000000             5'd21: divisor_shifted = {divisor_reg[26:0], 21'b0};
%000000             5'd22: divisor_shifted = {divisor_reg[25:0], 22'b0};
%000000             5'd23: divisor_shifted = {divisor_reg[24:0], 23'b0};
~000015             default: divisor_shifted = 48'h0;
                endcase
            end
        
            // Trial: remainder - shifted_divisor (49-bit for sign detection)
            assign trial = {1'b0, remainder_reg} - {1'b0, divisor_shifted};
        
            // Divide-by-zero detection (check registered divisor during DIV_RUN)
            assign div_by_zero = (divisor_reg == 48'h0) && (state == DIV_RUN);
        
            // =========================================================================
            // Iteration counter and data path register update
            // =========================================================================
 006406     always_ff @(posedge clk or negedge rst_n) begin
~006369         if (!rst_n) begin
~000037             iter_cnt      <= 5'd0;
~000037             remainder_reg <= 48'h0;
~000037             divisor_reg   <= 48'h0;
~000037             quotient_reg  <= 16'h0;
 006369         end else begin
 006369             case (state)
 006369                 IDLE: begin
~006369                     if (div_start) begin
~000016                         iter_cnt      <= 5'd0;
~000016                         remainder_reg <= {dividend, 8'b0};   // Q8.32 -> Q8.40
~000016                         divisor_reg   <= {8'b0, divisor};     // Q8.32 -> Q8.40
~000016                         quotient_reg  <= 16'h0;
                            end
                        end
~000241                 DIV_RUN: begin
~000240                     if (!div_by_zero) begin
~000240                         iter_cnt <= iter_cnt + 1'b1;
~000195                         if (!trial[48]) begin
                                    // Trial succeeded: remainder = trial, set quotient bit
~000045                             remainder_reg <= trial[47:0];
~000045                             quotient_reg[bit_pos[3:0]] <= 1'b1;
                                end
                                // else: quotient bit stays 0, remainder unchanged
                            end
                        end
~000016                 DIV_DONE: begin
                            // Clear on exit
~000016                     iter_cnt <= 5'd0;
                        end
%000000                 default: ;
                    endcase
                end
            end
        
            // =========================================================================
            // Output assignments
            // =========================================================================
            assign quotient = quotient_reg;
            assign busy     = (state == DIV_RUN);
            assign div_done = (state == DIV_DONE);
        
        endmodule
        
