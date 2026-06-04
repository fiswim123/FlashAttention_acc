//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_ctrl
        // Description: Main controller FSM for FlashAttention accelerator.
        //              18-state Moore machine managing the full attention computation flow.
        // MAS: M02 | Type: compute | Deps: fa_dma (M03), fa_systolic (M04), fa_softmax (M05), fa_divider (M06)
        // =============================================================================
        module fa_ctrl (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
            // External control
%000006     input  logic        start,
%000006     output logic        busy,
%000000     output logic        done,
%000000     output logic        error,
%000002     input  logic        causal_en,
%000000     input  logic        soft_reset,
            // DMA control
 000012     output logic        dma_start,
 000012     input  logic        dma_done,
~000012     output logic [1:0]  dma_cmd,
            // MAC control
 000012     output logic        mac_start,
 000012     input  logic        mac_done,
%000006     output logic        mac_mode,    // 0=QK, 1=SV
            // Softmax control
%000006     output logic        sm_start,
%000006     input  logic        sm_done,
            // Divider control
%000000     output logic        div_start,
%000000     input  logic        div_done,
            // Buffer control
%000006     output logic        buf_sel,
%000006     output logic        acc_clear,
            // Status outputs
%000000     output logic [7:0]  row_cnt,
%000006     output logic [3:0]  tile_cnt,
~002312     output logic [31:0] cycle_cnt
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
        
~000030     ctrl_state_t state, next;
        
            // =========================================================================
            // Counters
            // =========================================================================
%000000     logic [7:0]  row_cnt_reg;
%000006     logic [3:0]  tile_cnt_reg;
~002312     logic [31:0] cycle_cnt_reg;
%000006     logic        buf_sel_reg;
        
            // =========================================================================
            // FSM: State register (async reset, sync release)
            // =========================================================================
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             state <= IDLE;
~004602         else if (soft_reset)
%000000             state <= IDLE;
                else
 004602             state <= next;
            end
        
            // =========================================================================
            // FSM: Next state logic
            // =========================================================================
 004622     always_comb begin
 004622         next = state;
 004622         case (state)
 002309             IDLE: begin
~002306                 if (start && !busy)
%000003                     next = LOAD_Q;
                    end
 000036             LOAD_Q: begin
~000033                 if (dma_done)
%000003                     next = ROW_INIT;
                    end
%000003             ROW_INIT: begin
%000003                 next = TILE_LOAD;
                    end
 001860             TILE_LOAD: begin
~001857                 if (dma_done)
%000003                     next = MAC_QK;
                    end
 000195             MAC_QK: begin
~000192                 if (mac_done)
%000003                     next = MASK_APPLY;
                    end
%000003             MASK_APPLY: begin
%000003                 next = SOFTMAX_UPDATE;
                    end
 000015             SOFTMAX_UPDATE: begin
~000012                 if (sm_done)
%000003                     next = MAC_SV;
                    end
 000195             MAC_SV: begin
~000192                 if (mac_done)
%000003                     next = ACC_UPDATE;
                    end
%000003             ACC_UPDATE: begin
%000003                 next = NEXT_TILE;
                    end
%000003             NEXT_TILE: begin
%000003                 if (tile_cnt_reg == 4'd15)
%000000                     next = DIV_START_S;
                        else
%000003                     next = TILE_LOAD;
                    end
%000000             DIV_START_S: begin
%000000                 next = DIV_WAIT;
                    end
%000000             DIV_WAIT: begin
%000000                 if (div_done)
%000000                     next = DIV_DONE_S;
                    end
%000000             DIV_DONE_S: begin
%000000                 next = STORE_O;
                    end
%000000             STORE_O: begin
%000000                 if (dma_done)
%000000                     next = NEXT_ROW;
                    end
%000000             NEXT_ROW: begin
%000000                 if (row_cnt_reg == 8'd255)
%000000                     next = WRITEBACK;
                        else
%000000                     next = ROW_INIT;
                    end
%000000             WRITEBACK: begin
%000000                 next = DONE_S;
                    end
%000000             DONE_S: begin
%000000                 next = IDLE;
                    end
%000000             ERROR_S: begin
%000000                 next = IDLE;
                    end
%000000             default: next = IDLE;
                endcase
            end
        
            // =========================================================================
            // Counter logic
            // =========================================================================
        
            // Row counter
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             row_cnt_reg <= 8'd0;
 002292         else if (soft_reset || state == IDLE)
 002292             row_cnt_reg <= 8'd0;
~002310         else if (state == NEXT_ROW && row_cnt_reg < 8'd255)
%000000             row_cnt_reg <= row_cnt_reg + 1'b1;
            end
        
            // Tile counter
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             tile_cnt_reg <= 4'd0;
 002295         else if (soft_reset || state == IDLE || state == ROW_INIT)
 002295             tile_cnt_reg <= 4'd0;
~002304         else if (state == NEXT_TILE && tile_cnt_reg < 4'd15)
%000003             tile_cnt_reg <= tile_cnt_reg + 1'b1;
            end
        
            // Cycle counter (runs whenever not IDLE)
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             cycle_cnt_reg <= 32'd0;
 002310         else if (soft_reset || state == IDLE)
 002292             cycle_cnt_reg <= 32'd0;
                else
 002310             cycle_cnt_reg <= cycle_cnt_reg + 1'b1;
            end
        
            // Buffer select (flip on each tile switch)
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             buf_sel_reg <= 1'b0;
 002292         else if (soft_reset || state == IDLE)
 002292             buf_sel_reg <= 1'b0;
~002307         else if (state == NEXT_TILE)
%000003             buf_sel_reg <= ~buf_sel_reg;
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
            assign dma_cmd   = (state == IDLE) ? 2'b00 :       // Q
                               (state == ROW_INIT) ? 2'b01 :   // K (first tile load)
                               (state == TILE_LOAD) ? 2'b01 :  // K
                               2'b11;                           // O (STORE_O)
        
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
        
