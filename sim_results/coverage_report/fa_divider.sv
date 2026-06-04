//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_divider
        // Description: Iterative SRT divider, 16 fixed iterations. 40-bit / 40-bit -> 16-bit Q8.8
        // MAS: M06 | Type: compute | Deps: none (leaf)
        // =============================================================================
        module fa_divider (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
%000000     input  logic        div_start,
%000000     output logic        div_done,
%000000     input  logic [39:0] dividend,
%000001     input  logic [39:0] divisor,
%000000     output logic [15:0] quotient,
%000000     output logic        busy
        );
        
            // =========================================================================
            // FSM States
            // =========================================================================
            typedef enum logic [1:0] {
                IDLE     = 2'b00,
                DIV_RUN  = 2'b01,
                DIV_DONE = 2'b10
            } div_state_t;
        
%000000     div_state_t state, next;
        
            // =========================================================================
            // Registers
            // =========================================================================
%000000     logic [3:0]  iter_cnt;
%000000     logic [39:0] remainder_reg;
%000000     logic [39:0] divisor_reg;
%000000     logic [15:0] quotient_reg;
%000000     logic        div_by_zero;
        
            // =========================================================================
            // FSM: State register
            // =========================================================================
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n)
 000019             state <= IDLE;
                else
 004602             state <= next;
            end
        
            // =========================================================================
            // FSM: Next state logic
            // =========================================================================
 004622     always_comb begin
 004622         next = state;
 004622         case (state)
 004622             IDLE: begin
~004622                 if (div_start)
%000000                     next = DIV_RUN;
                    end
%000000             DIV_RUN: begin
%000000                 if (div_by_zero || iter_cnt == 4'd15)
%000000                     next = DIV_DONE;
                    end
%000000             DIV_DONE: next = IDLE;
%000000             default:   next = IDLE;
                endcase
            end
        
            // =========================================================================
            // SRT Iteration Logic
            // =========================================================================
            // Iteration i: trial subtract (remainder - divisor << i)
            // If trial >= 0: remainder = trial, quotient[i] = 1
            // Else: quotient[i] = 0
            // Iteration order: i = 15, 14, ..., 0 (MSB first for Q8.8 output)
            //
            // For Q8.8 output from 40-bit inputs:
            // dividend is Q8.32, divisor is Q8.32, quotient is Q8.8
            // We shift the divisor relative to the remainder to extract quotient bits
        
%000000     logic [40:0] trial;
%000000     logic [39:0] shifted_divisor;
        
            // The shift amount for iteration i (iter_cnt maps to bit position)
            // iter_cnt 0 -> bit 15 (MSB of quotient)
            // iter_cnt 15 -> bit 0 (LSB of quotient)
%000001     wire [3:0] bit_pos = 4'd15 - iter_cnt;
        
            // Shift divisor left by bit_pos positions
            // We use a simple mux-based shifter for synthesis
 004622     always_comb begin
 004622         shifted_divisor = divisor_reg;
 004622         case (bit_pos)
%000000             4'd0:  shifted_divisor = divisor_reg;
%000000             4'd1:  shifted_divisor = {divisor_reg[38:0], 1'b0};
%000000             4'd2:  shifted_divisor = {divisor_reg[37:0], 2'b0};
%000000             4'd3:  shifted_divisor = {divisor_reg[36:0], 3'b0};
%000000             4'd4:  shifted_divisor = {divisor_reg[35:0], 4'b0};
%000000             4'd5:  shifted_divisor = {divisor_reg[34:0], 5'b0};
%000000             4'd6:  shifted_divisor = {divisor_reg[33:0], 6'b0};
%000000             4'd7:  shifted_divisor = {divisor_reg[32:0], 7'b0};
%000000             4'd8:  shifted_divisor = {divisor_reg[31:0], 8'b0};
%000000             4'd9:  shifted_divisor = {divisor_reg[30:0], 9'b0};
%000000             4'd10: shifted_divisor = {divisor_reg[29:0], 10'b0};
%000000             4'd11: shifted_divisor = {divisor_reg[28:0], 11'b0};
%000000             4'd12: shifted_divisor = {divisor_reg[27:0], 12'b0};
%000000             4'd13: shifted_divisor = {divisor_reg[26:0], 13'b0};
%000000             4'd14: shifted_divisor = {divisor_reg[25:0], 14'b0};
 004622             4'd15: shifted_divisor = {divisor_reg[24:0], 15'b0};
                endcase
            end
        
            // Trial subtraction
            assign trial = {1'b0, remainder_reg} - {1'b0, shifted_divisor};
        
            // Divide-by-zero detection
            assign div_by_zero = (divisor == 40'h0) && (state == DIV_RUN);
        
            // =========================================================================
            // Iteration counter and data path register update
            // =========================================================================
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n) begin
 000019             iter_cnt     <= 4'd0;
 000019             remainder_reg <= 40'h0;
 000019             divisor_reg   <= 40'h0;
 000019             quotient_reg  <= 16'h0;
 004602         end else begin
 004602             case (state)
 004602                 IDLE: begin
~004602                     if (div_start) begin
%000000                         iter_cnt     <= 4'd0;
%000000                         remainder_reg <= dividend;
%000000                         divisor_reg   <= divisor;
%000000                         quotient_reg  <= 16'h0;
                            end
                        end
%000000                 DIV_RUN: begin
%000000                     if (!div_by_zero) begin
%000000                         iter_cnt <= iter_cnt + 1'b1;
%000000                         if (!trial[40]) begin
                                    // Trial succeeded: remainder = trial, set quotient bit
%000000                             remainder_reg <= trial[39:0];
%000000                             quotient_reg[bit_pos] <= 1'b1;
                                end
                                // else: quotient bit stays 0, remainder unchanged
                            end
                        end
%000000                 DIV_DONE: begin
                            // Clear on exit
%000000                     iter_cnt <= 4'd0;
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
        
