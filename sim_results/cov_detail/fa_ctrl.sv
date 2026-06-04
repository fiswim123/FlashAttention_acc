//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_ctrl
        // Description: Main controller FSM for FlashAttention accelerator.
        //              18-state Moore machine managing the full attention computation flow.
        // MAS: M02 | Type: compute | Deps: fa_dma (M03), fa_systolic (M04), fa_softmax (M05), fa_divider (M06)
        // =============================================================================
        module fa_ctrl (
 034849     input  logic        clk,
~000013     input  logic        rst_n,
            // External control
%000008     input  logic        start,
%000008     output logic        busy,
%000000     output logic        done,
%000000     output logic        error,
%000008     input  logic        causal_en,
%000002     input  logic        soft_reset,
            // DMA control
 000022     output logic        dma_start,
 000078     input  logic        dma_done,
~000074     output logic [1:0]  dma_cmd,
            // MAC control
 000128     output logic        mac_start,
 000128     input  logic        mac_done,
~000064     output logic        mac_mode,    // 0=QK, 1=SV
            // Softmax control
~000064     output logic        sm_start,
~000064     input  logic        sm_done,
            // Divider control
~000064     output logic        div_start,
~000064     input  logic        div_done,
            // Buffer control
~000032     output logic        buf_sel,
~000010     output logic        acc_clear,
            // Status outputs
%000004     output logic [7:0]  row_cnt,
~000032     output logic [3:0]  tile_cnt,
~017392     output logic [31:0] cycle_cnt,
~000032     output logic [3:0]  div_elem_idx
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
                DIV_NEXT        = 5'h12,
                O_WRITE         = 5'h13,
                STORE_O         = 5'h0D,
                NEXT_ROW        = 5'h0E,
                WRITEBACK       = 5'h0F,
                DONE_S          = 5'h10,
                ERROR_S         = 5'h11
            } ctrl_state_t;
        
~000282     ctrl_state_t state, next;
        
            // =========================================================================
            // Counters
            // =========================================================================
%000004     logic [7:0]  row_cnt_reg;
~000032     logic [3:0]  tile_cnt_reg;
~017392     logic [31:0] cycle_cnt_reg;
~000032     logic        buf_sel_reg;
~000032     logic [3:0]  div_elem_cnt;  // Tracks which of 16 elements is being divided
        
            // =========================================================================
            // FSM: State register (async reset, sync release)
            // =========================================================================
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             state <= IDLE;
~017411         else if (soft_reset)
%000001             state <= IDLE;
                else
 017411             state <= next;
            end
        
            // =========================================================================
            // FSM: Next state logic
            // =========================================================================
 087214     always_comb begin
 087214         next = state;
 087214         case (state)
 003934             IDLE: begin
~003931                 if (start && !busy)
%000004                     next = LOAD_Q;
                    end
 000109             LOAD_Q: begin
~000106                 if (dma_done)
%000003                     next = ROW_INIT;
                    end
~000025             ROW_INIT: begin
~000025                 next = TILE_LOAD;
                    end
 004340             TILE_LOAD: begin
~004308                 if (dma_done)
~000032                     next = MAC_QK;
                    end
 000480             MAC_QK: begin
~000448                 if (mac_done)
~000032                     next = MASK_APPLY;
                    end
~000160             MASK_APPLY: begin
~000160                 next = SOFTMAX_UPDATE;
                    end
 000327             SOFTMAX_UPDATE: begin
~000295                 if (sm_done)
~000032                     next = MAC_SV;
                    end
 000487             MAC_SV: begin
~000455                 if (mac_done)
~000032                     next = ACC_UPDATE;
                    end
~000160             ACC_UPDATE: begin
~000160                 next = NEXT_TILE;
                    end
~000160             NEXT_TILE: begin
~000150                 if (tile_cnt_reg == 4'd15)
~000010                     next = DIV_START_S;
                        else
~000150                     next = TILE_LOAD;
                    end
~000160             DIV_START_S: begin
~000160                 next = DIV_WAIT;
                    end
~076246             DIV_WAIT: begin
~076214                 if (div_done)
~000032                     next = DIV_DONE_S;
                    end
~000160             DIV_DONE_S: begin
~000160                 next = DIV_NEXT;
                    end
~000160             DIV_NEXT: begin
~000150                 if (div_elem_cnt == 4'd15)
~000010                     next = O_WRITE;
                        else
~000150                     next = DIV_START_S;
                    end
~004024             O_WRITE: begin
~004022                 if (dma_done)
%000002                     next = STORE_O;
                    end
~000037             STORE_O: begin
~000027                 if (dma_done)
~000010                     next = NEXT_ROW;
                    end
~000010             NEXT_ROW: begin
~000010                 if (row_cnt_reg == 8'd255)
%000000                     next = WRITEBACK;
                        else
~000010                     next = ROW_INIT;
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
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             row_cnt_reg <= 8'd0;
 003899         else if (soft_reset || state == IDLE)
 003899             row_cnt_reg <= 8'd0;
~017387         else if (state == NEXT_ROW && row_cnt_reg < 8'd255)
%000002             row_cnt_reg <= row_cnt_reg + 1'b1;
            end
        
            // Tile counter
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             tile_cnt_reg <= 4'd0;
 003902         else if (soft_reset || state == IDLE || state == ROW_INIT)
 003902             tile_cnt_reg <= 4'd0;
~017354         else if (state == NEXT_TILE && tile_cnt_reg < 4'd15)
~000030             tile_cnt_reg <= tile_cnt_reg + 1'b1;
            end
        
            // Cycle counter (runs whenever not IDLE)
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             cycle_cnt_reg <= 32'd0;
 017389         else if (soft_reset || state == IDLE)
 003899             cycle_cnt_reg <= 32'd0;
                else
 017389             cycle_cnt_reg <= cycle_cnt_reg + 1'b1;
            end
        
            // Divider element counter (0..15, increments after each divider invocation)
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             div_elem_cnt <= 4'd0;
 003899         else if (soft_reset || state == IDLE)
 003899             div_elem_cnt <= 4'd0;
~017357         else if (state == DIV_NEXT)
~000032             div_elem_cnt <= div_elem_cnt + 1'b1;
            end
        
            // Buffer select (flip on each tile switch)
 017427     always_ff @(posedge clk or negedge rst_n) begin
 000037         if (!rst_n)
 000037             buf_sel_reg <= 1'b0;
 003899         else if (soft_reset || state == IDLE)
 003899             buf_sel_reg <= 1'b0;
~017357         else if (state == NEXT_TILE)
~000032             buf_sel_reg <= ~buf_sel_reg;
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
            assign div_elem_idx = div_elem_cnt;
        
            // DMA control
            assign dma_start = (state == IDLE && start && !busy) ||
                               (state == ROW_INIT) ||
                               (state == O_WRITE);
            assign dma_cmd   = (state == LOAD_Q)    ? 2'b00 :   // Q load
                               (state == ROW_INIT)  ? 2'b01 :   // K (first tile load)
                               (state == TILE_LOAD) ? 2'b01 :   // K
                               (state == O_WRITE)   ? 2'b11 :   // O (write output via DMA)
                               2'b00;                            // default: Q
        
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
        
