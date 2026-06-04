// =============================================================================
// Module: fa_divider
// Description: Iterative restoring divider, 16 iterations. 40-bit Q8.32 / 40-bit Q8.32 -> 16-bit Q8.8
//              Dividend is left-shifted 8 bits to produce Q8.8 output from Q8.32 inputs.
// MAS: M06 | Type: compute | Deps: none (leaf)
// =============================================================================
module fa_divider (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        div_start,
    output logic        div_done,
    input  logic [39:0] dividend,
    input  logic [39:0] divisor,
    output logic [15:0] quotient,
    output logic        busy
);

    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        DIV_RUN  = 2'b01,
        DIV_DONE = 2'b10
    } div_state_t;

    div_state_t state, next;

    // =========================================================================
    // Registers
    // =========================================================================
    logic [4:0]  iter_cnt;
    logic [47:0] remainder_reg;   // Q8.40 (dividend shifted left 8 bits)
    logic [47:0] divisor_reg;     // Q8.40 (divisor zero-padded to 48 bits)
    logic [15:0] quotient_reg;
    logic        div_by_zero;

    // =========================================================================
    // FSM: State register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next;
    end

    // =========================================================================
    // FSM: Next state logic
    // =========================================================================
    always_comb begin
        next = state;
        case (state)
            IDLE: begin
                if (div_start)
                    next = DIV_RUN;
            end
            DIV_RUN: begin
                if (div_by_zero || iter_cnt == 5'd15)
                    next = DIV_DONE;
            end
            DIV_DONE: next = IDLE;
            default:   next = IDLE;
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

    logic [47:0] divisor_shifted;
    logic [48:0] trial;
    logic [4:0]  bit_pos;

    assign bit_pos = 5'd15 - iter_cnt;

    // Trial subtraction: (remainder << 1) - divisor
    // Shift divisor left by (bit_pos + 1) for trial comparison
    always_comb begin
        divisor_shifted = 48'h0;
        case (bit_pos + 5'd1)
            5'd1:  divisor_shifted = {divisor_reg[46:0], 1'b0};
            5'd2:  divisor_shifted = {divisor_reg[45:0], 2'b0};
            5'd3:  divisor_shifted = {divisor_reg[44:0], 3'b0};
            5'd4:  divisor_shifted = {divisor_reg[43:0], 4'b0};
            5'd5:  divisor_shifted = {divisor_reg[42:0], 5'b0};
            5'd6:  divisor_shifted = {divisor_reg[41:0], 6'b0};
            5'd7:  divisor_shifted = {divisor_reg[40:0], 7'b0};
            5'd8:  divisor_shifted = {divisor_reg[39:0], 8'b0};
            5'd9:  divisor_shifted = {divisor_reg[38:0], 9'b0};
            5'd10: divisor_shifted = {divisor_reg[37:0], 10'b0};
            5'd11: divisor_shifted = {divisor_reg[36:0], 11'b0};
            5'd12: divisor_shifted = {divisor_reg[35:0], 12'b0};
            5'd13: divisor_shifted = {divisor_reg[34:0], 13'b0};
            5'd14: divisor_shifted = {divisor_reg[33:0], 14'b0};
            5'd15: divisor_shifted = {divisor_reg[32:0], 15'b0};
            5'd16: divisor_shifted = {divisor_reg[31:0], 16'b0};
            5'd17: divisor_shifted = {divisor_reg[30:0], 17'b0};
            5'd18: divisor_shifted = {divisor_reg[29:0], 18'b0};
            5'd19: divisor_shifted = {divisor_reg[28:0], 19'b0};
            5'd20: divisor_shifted = {divisor_reg[27:0], 20'b0};
            5'd21: divisor_shifted = {divisor_reg[26:0], 21'b0};
            5'd22: divisor_shifted = {divisor_reg[25:0], 22'b0};
            5'd23: divisor_shifted = {divisor_reg[24:0], 23'b0};
            default: divisor_shifted = 48'h0;
        endcase
    end

    // Trial: remainder - shifted_divisor (49-bit for sign detection)
    assign trial = {1'b0, remainder_reg} - {1'b0, divisor_shifted};

    // Divide-by-zero detection (check registered divisor during DIV_RUN)
    assign div_by_zero = (divisor_reg == 48'h0) && (state == DIV_RUN);

    // =========================================================================
    // Iteration counter and data path register update
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_cnt      <= 5'd0;
            remainder_reg <= 48'h0;
            divisor_reg   <= 48'h0;
            quotient_reg  <= 16'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (div_start) begin
                        iter_cnt      <= 5'd0;
                        remainder_reg <= {dividend, 8'b0};   // Q8.32 -> Q8.40
                        divisor_reg   <= {8'b0, divisor};     // Q8.32 -> Q8.40
                        quotient_reg  <= 16'h0;
                    end
                end
                DIV_RUN: begin
                    if (!div_by_zero) begin
                        iter_cnt <= iter_cnt + 1'b1;
                        if (!trial[48]) begin
                            // Trial succeeded: remainder = trial, set quotient bit
                            remainder_reg <= trial[47:0];
                            quotient_reg[bit_pos[3:0]] <= 1'b1;
                        end
                        // else: quotient bit stays 0, remainder unchanged
                    end
                end
                DIV_DONE: begin
                    // Clear on exit
                    iter_cnt <= 5'd0;
                end
                default: ;
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
