//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_dma
        // Description: AXI4 Master DMA engine for Q/K/V/O data transfer.
        //              FSM: IDLE -> ADDR_CALC -> AR_SEND/R_RECV (read) or AW_SEND/W_SEND/B_RECV (write)
        // MAS: M03 | Type: io | Deps: fa_buffer_mgr (M07)
        // =============================================================================
        module fa_dma (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
            // Control interface from fa_ctrl
 000012     input  logic        dma_start,
 000012     output logic        dma_done,
~000012     input  logic [1:0]  dma_cmd,      // 00=Q, 01=K, 10=V, 11=O
            // Base addresses from regfile
%000003     input  logic [63:0] q_base,
%000002     input  logic [63:0] k_base,
%000002     input  logic [63:0] v_base,
%000002     input  logic [63:0] o_base,
%000002     input  logic [31:0] stride,
%000000     input  logic [7:0]  row_cnt,
%000006     input  logic [3:0]  tile_cnt,
            // AXI4 Master Write Address Channel
%000002     output logic [63:0] m_axi_awaddr,
%000006     output logic [7:0]  m_axi_awlen,
%000001     output logic [2:0]  m_axi_awsize,
%000001     output logic [1:0]  m_axi_awburst,
%000000     output logic        m_axi_awvalid,
%000000     input  logic        m_axi_awready,
            // AXI4 Master Write Data Channel
%000000     output logic [127:0] m_axi_wdata,
%000001     output logic [15:0]  m_axi_wstrb,
%000000     output logic         m_axi_wlast,
%000000     output logic         m_axi_wvalid,
%000000     input  logic         m_axi_wready,
            // AXI4 Master Write Response Channel
%000000     input  logic [1:0]  m_axi_bresp,
%000000     input  logic        m_axi_bvalid,
%000000     output logic        m_axi_bready,
            // AXI4 Master Read Address Channel
%000002     output logic [63:0] m_axi_araddr,
%000006     output logic [7:0]  m_axi_arlen,
%000001     output logic [2:0]  m_axi_arsize,
%000001     output logic [1:0]  m_axi_arburst,
 000012     output logic        m_axi_arvalid,
 000012     input  logic        m_axi_arready,
            // AXI4 Master Read Data Channel
~000072     input  logic [127:0] m_axi_rdata,
%000000     input  logic [1:0]  m_axi_rresp,
 000012     input  logic        m_axi_rlast,
 000012     input  logic        m_axi_rvalid,
 000012     output logic        m_axi_rready,
            // Buffer interface
 000012     output logic        buf_wr_en,
~000072     output logic [11:0] buf_wr_addr,
~000072     output logic [127:0] buf_wr_data,
%000000     output logic        buf_rd_en,
%000000     output logic [11:0] buf_rd_addr,
%000000     input  logic [127:0] buf_rd_data
        );
        
            // =========================================================================
            // DMA Commands
            // =========================================================================
            localparam CMD_Q = 2'b00;
            localparam CMD_K = 2'b01;
            localparam CMD_V = 2'b10;
            localparam CMD_O = 2'b11;
        
            // =========================================================================
            // FSM States
            // =========================================================================
            typedef enum logic [2:0] {
                IDLE      = 3'b000,
                ADDR_CALC = 3'b001,
                AR_SEND   = 3'b010,
                R_RECV    = 3'b011,
                AW_SEND   = 3'b100,
                W_SEND    = 3'b101,
                B_RECV    = 3'b110
            } dma_state_t;
        
~000024     dma_state_t state, next;
        
            // =========================================================================
            // Internal Registers
            // =========================================================================
%000006     logic [1:0]  cmd_reg;
%000002     logic [63:0] target_addr;
%000006     logic [7:0]  burst_len;      // awlen/arlen (beats - 1)
~000072     logic [7:0]  beat_cnt;
~000072     logic [11:0] buf_wr_addr_reg;
%000000     logic [11:0] buf_rd_addr_reg;
%000005     logic [63:0] base_addr;
        
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
 004532             IDLE: begin
~004526                 if (dma_start)
%000006                     next = ADDR_CALC;
                    end
%000006             ADDR_CALC: begin
%000006                 if (cmd_reg == CMD_O)
%000000                     next = AW_SEND;
                        else
%000006                     next = AR_SEND;
                    end
 000012             AR_SEND: begin
%000006                 if (m_axi_arready)
%000006                     next = R_RECV;
                    end
 000072             R_RECV: begin
~000066                 if (m_axi_rlast && m_axi_rvalid)
%000006                     next = IDLE;
                    end
%000000             AW_SEND: begin
%000000                 if (m_axi_awready)
%000000                     next = W_SEND;
                    end
%000000             W_SEND: begin
%000000                 if (m_axi_wlast && m_axi_wready)
%000000                     next = B_RECV;
                    end
%000000             B_RECV: begin
%000000                 if (m_axi_bvalid)
%000000                     next = IDLE;
                    end
%000000             default: next = IDLE;
                endcase
            end
        
            // =========================================================================
            // Address generation
            // =========================================================================
            // Select base address based on command
 004622     always_comb begin
 004622         case (cmd_reg)
 002348             CMD_Q: base_addr = q_base + 64'(row_cnt) * stride;
 002274             CMD_K: base_addr = k_base + 64'(tile_cnt) * 16 * stride;
%000000             CMD_V: base_addr = v_base + 64'(tile_cnt) * 16 * stride;
%000000             CMD_O: base_addr = o_base + 64'(row_cnt) * stride;
                endcase
            end
        
            // Burst length calculation
            // Q: 128 bytes = 8 beats (arlen=7), K/V: 256 bytes = 16 beats (arlen=15), O: 128 bytes = 8 beats
 004622     always_comb begin
 004622         case (cmd_reg)
 002348             CMD_Q: burst_len = 8'd7;
 002274             CMD_K: burst_len = 8'd15;
%000000             CMD_V: burst_len = 8'd15;
%000000             CMD_O: burst_len = 8'd7;
                endcase
            end
        
            // =========================================================================
            // Command latch and address register
            // =========================================================================
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n) begin
 000019             cmd_reg        <= 2'b00;
 000019             target_addr    <= 64'h0;
 000019             beat_cnt       <= 8'h0;
 000019             buf_wr_addr_reg <= 12'h0;
 000019             buf_rd_addr_reg <= 12'h0;
 004602         end else begin
 004602             case (state)
 004512                 IDLE: begin
~004506                     if (dma_start) begin
%000006                         cmd_reg <= dma_cmd;
                            end
                        end
%000006                 ADDR_CALC: begin
%000006                     target_addr <= base_addr;
%000006                     beat_cnt    <= 8'h0;
%000006                     buf_wr_addr_reg <= 12'h0;
%000006                     buf_rd_addr_reg <= 12'h0;
                        end
 000072                 R_RECV: begin
~000072                     if (m_axi_rvalid) begin
 000072                         beat_cnt <= beat_cnt + 1'b1;
 000072                         buf_wr_addr_reg <= buf_wr_addr_reg + 1'b1;
                            end
                        end
%000000                 W_SEND: begin
%000000                     if (m_axi_wready) begin
%000000                         beat_cnt <= beat_cnt + 1'b1;
%000000                         buf_rd_addr_reg <= buf_rd_addr_reg + 1'b1;
                            end
                        end
 000012                 default: ;
                    endcase
                end
            end
        
            // =========================================================================
            // AXI4 Read Address Channel
            // =========================================================================
            assign m_axi_araddr  = target_addr;
            assign m_axi_arlen   = burst_len;
            assign m_axi_arsize  = 3'b100;  // 16 bytes (128-bit)
            assign m_axi_arburst = 2'b01;   // INCR burst
            assign m_axi_arvalid = (state == AR_SEND);
        
            // =========================================================================
            // AXI4 Read Data Channel -> Buffer Write
            // =========================================================================
            assign m_axi_rready  = (state == R_RECV);
            assign buf_wr_en     = (state == R_RECV) && m_axi_rvalid;
            assign buf_wr_addr   = buf_wr_addr_reg;
            assign buf_wr_data   = m_axi_rdata;
        
            // =========================================================================
            // AXI4 Write Address Channel
            // =========================================================================
            assign m_axi_awaddr  = target_addr;
            assign m_axi_awlen   = burst_len;
            assign m_axi_awsize  = 3'b100;  // 16 bytes (128-bit)
            assign m_axi_awburst = 2'b01;   // INCR burst
            assign m_axi_awvalid = (state == AW_SEND);
        
            // =========================================================================
            // AXI4 Write Data Channel <- Buffer Read
            // =========================================================================
            assign buf_rd_en     = (state == W_SEND) && m_axi_wready;
            assign buf_rd_addr   = buf_rd_addr_reg;
            assign m_axi_wdata   = buf_rd_data;
            assign m_axi_wstrb   = 16'hFFFF;
            assign m_axi_wlast   = (state == W_SEND) && (beat_cnt == burst_len);
            assign m_axi_wvalid  = (state == W_SEND);
        
            // =========================================================================
            // AXI4 Write Response Channel
            // =========================================================================
            assign m_axi_bready  = (state == B_RECV);
        
            // =========================================================================
            // DMA done signal
            // =========================================================================
            // Assert dma_done for one cycle when returning to IDLE from R_RECV or B_RECV
 000012     logic dma_done_pulse;
        
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n)
 000019             dma_done_pulse <= 1'b0;
                else
 004602             dma_done_pulse <= (state == R_RECV && m_axi_rlast && m_axi_rvalid) ||
 004602                               (state == B_RECV && m_axi_bvalid);
            end
        
            assign dma_done = dma_done_pulse;
        
        endmodule
        
