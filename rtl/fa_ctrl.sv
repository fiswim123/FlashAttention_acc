// =============================================================================
// Module: fa_ctrl
// Description: Main controller FSM for FlashAttention accelerator.
//              18-state Moore machine managing the full attention computation flow.
// MAS: M02 | Type: compute | Deps: fa_dma (M03), fa_systolic (M04), fa_softmax (M05), fa_divider (M06)
// =============================================================================
module fa_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    // External control
    input  logic        start,
    output logic        busy,
    output logic        done,
    output logic        error,
    input  logic        causal_en,
    input  logic        soft_reset,
    // DMA control
    output logic        dma_start,
    input  logic        dma_done,
    output logic [1:0]  dma_cmd,
    // MAC control
    output logic        mac_start,
    input  logic        mac_done,
    output logic        mac_mode,    // 0=QK, 1=SV
    // Softmax control
    output logic        sm_start,
    input  logic        sm_done,
    // Divider control
    output logic        div_start,
    input  logic        div_done,
    // Buffer control
    output logic        buf_sel,
    output logic        acc_clear,
    // Status outputs
    output logic [7:0]  row_cnt,
    output logic [3:0]  tile_cnt,
    output logic [31:0] cycle_cnt
);

    // =========================================================================
    // FSM States (18 states)
    // =========================================================================
    typedef enum logic [4:0] {
        IDLE            = 5'h00,
        LOAD_Q          = 5'h01,
        ROW_INIT        = 5'h02,
        TILE_LOAD       = 5'h03,
        MAC_QK          = 5'h04,
        MASK_APPLY      = 5'h05,
        SOFTMAX_UPDATE  = 5'h06,
        MAC_SV          = 5'h07,
        ACC_UPDATE      = 5'h08,
        NEXT_TILE       = 5'h09,
        DIV_START_S     = 5'h0A,
        DIV_WAIT        = 5'h0B,
        DIV_DONE_S      = 5'h0C,
        STORE_O         = 5'h0D,
        NEXT_ROW        = 5'h0E,
        WRITEBACK       = 5'h0F,
        DONE_S          = 5'h10,
        ERROR_S         = 5'h11
    } ctrl_state_t;

    ctrl_state_t state, next;

    // =========================================================================
    // Counters
    // =========================================================================
    logic [7:0]  row_cnt_reg;
    logic [3:0]  tile_cnt_reg;
    logic [31:0] cycle_cnt_reg;
    logic        buf_sel_reg;

    // =========================================================================
    // FSM: State register (async reset, sync release)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else if (soft_reset)
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
                if (start && !busy)
                    next = LOAD_Q;
            end
            LOAD_Q: begin
                if (dma_done)
                    next = ROW_INIT;
            end
            ROW_INIT: begin
                next = TILE_LOAD;
            end
            TILE_LOAD: begin
                if (dma_done)
                    next = MAC_QK;
            end
            MAC_QK: begin
                if (mac_done)
                    next = MASK_APPLY;
            end
            MASK_APPLY: begin
                next = SOFTMAX_UPDATE;
            end
            SOFTMAX_UPDATE: begin
                if (sm_done)
                    next = MAC_SV;
            end
            MAC_SV: begin
                if (mac_done)
                    next = ACC_UPDATE;
            end
            ACC_UPDATE: begin
                next = NEXT_TILE;
            end
            NEXT_TILE: begin
                if (tile_cnt_reg == 4'd15)
                    next = DIV_START_S;
                else
                    next = TILE_LOAD;
            end
            DIV_START_S: begin
                next = DIV_WAIT;
            end
            DIV_WAIT: begin
                if (div_done)
                    next = DIV_DONE_S;
            end
            DIV_DONE_S: begin
                next = STORE_O;
            end
            STORE_O: begin
                if (dma_done)
                    next = NEXT_ROW;
            end
            NEXT_ROW: begin
                if (row_cnt_reg == 8'd255)
                    next = WRITEBACK;
                else
                    next = ROW_INIT;
            end
            WRITEBACK: begin
                next = DONE_S;
            end
            DONE_S: begin
                next = IDLE;
            end
            ERROR_S: begin
                next = IDLE;
            end
            default: next = IDLE;
        endcase
    end

    // =========================================================================
    // Counter logic
    // =========================================================================

    // Row counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            row_cnt_reg <= 8'd0;
        else if (soft_reset || state == IDLE)
            row_cnt_reg <= 8'd0;
        else if (state == NEXT_ROW && row_cnt_reg < 8'd255)
            row_cnt_reg <= row_cnt_reg + 1'b1;
    end

    // Tile counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tile_cnt_reg <= 4'd0;
        else if (soft_reset || state == IDLE || state == ROW_INIT)
            tile_cnt_reg <= 4'd0;
        else if (state == NEXT_TILE && tile_cnt_reg < 4'd15)
            tile_cnt_reg <= tile_cnt_reg + 1'b1;
    end

    // Cycle counter (runs whenever not IDLE)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_cnt_reg <= 32'd0;
        else if (soft_reset || state == IDLE)
            cycle_cnt_reg <= 32'd0;
        else
            cycle_cnt_reg <= cycle_cnt_reg + 1'b1;
    end

    // Buffer select (flip on each tile switch)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            buf_sel_reg <= 1'b0;
        else if (soft_reset || state == IDLE)
            buf_sel_reg <= 1'b0;
        else if (state == NEXT_TILE)
            buf_sel_reg <= ~buf_sel_reg;
    end

    // =========================================================================
    // Output assignments
    // =========================================================================

    // Status outputs
    assign busy     = (state != IDLE) && (state != DONE_S) && (state != ERROR_S);
    assign done     = (state == DONE_S);
    assign error    = (state == ERROR_S);
    assign row_cnt  = row_cnt_reg;
    assign tile_cnt = tile_cnt_reg;
    assign cycle_cnt = cycle_cnt_reg;
    assign buf_sel  = buf_sel_reg;

    // DMA control
    assign dma_start = (state == IDLE && start && !busy) ||
                       (state == ROW_INIT) ||
                       (state == DIV_DONE_S);
    assign dma_cmd   = (state == IDLE)     ? 2'b00 :   // Q (triggers LOAD_Q)
                       (state == LOAD_Q)   ? 2'b00 :   // Q (active load)
                       (state == ROW_INIT) ? 2'b01 :   // K (first tile load)
                       (state == TILE_LOAD) ? 2'b01 :  // K
                       (state == STORE_O)  ? 2'b11 :   // O (store output)
                       2'b00;                          // default: Q

    // MAC control
    assign mac_start = (state == TILE_LOAD && dma_done) ||
                       (state == SOFTMAX_UPDATE && sm_done);
    assign mac_mode  = (state == MAC_SV) ? 1'b1 : 1'b0;  // 0=QK, 1=SV

    // Softmax control
    assign sm_start  = (state == MASK_APPLY);

    // Divider control
    assign div_start = (state == DIV_START_S);

    // Accumulator clear
    assign acc_clear = (state == LOAD_Q && dma_done) ||
                       (state == ROW_INIT);

endmodule
