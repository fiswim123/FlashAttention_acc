//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_dma
        // Description: AXI4 Master DMA engine for Q/K/V/O data transfer.
        //              FSM: IDLE -> ADDR_CALC -> AR_SEND/R_RECV (read) or AW_SEND/W_SEND/B_RECV (write)
        // MAS: M03 | Type: io | Deps: fa_buffer_mgr (M07)
        // =============================================================================
        module fa_dma (
 012799     input  logic        clk,
~000013     input  logic        rst_n,
            // Control interface from fa_ctrl
 000020     input  logic        dma_start,
 000020     output logic        dma_done,
~000012     input  logic [1:0]  dma_cmd,      // 00=Q, 01=K, 10=V, 11=O
            // Base addresses from regfile
%000009     input  logic [63:0] q_base,
%000004     input  logic [63:0] k_base,
%000004     input  logic [63:0] v_base,
%000004     input  logic [63:0] o_base,
%000005     input  logic [31:0] stride,
%000002     input  logic [7:0]  row_cnt,
%000006     input  logic [3:0]  tile_cnt,
            // AXI4 Master Write Address Channel
%000005     output logic [63:0] m_axi_awaddr,
%000006     output logic [7:0]  m_axi_awlen,
%000001     output logic [2:0]  m_axi_awsize,
%000001     output logic [1:0]  m_axi_awburst,
%000002     output logic        m_axi_awvalid,
%000002     input  logic        m_axi_awready,
            // AXI4 Master Write Data Channel
%000000     output logic [127:0] m_axi_wdata,
%000001     output logic [15:0]  m_axi_wstrb,
%000002     output logic         m_axi_wlast,
%000002     output logic         m_axi_wvalid,
%000002     input  logic         m_axi_wready,
            // AXI4 Master Write Response Channel
%000000     input  logic [1:0]  m_axi_bresp,
%000002     input  logic        m_axi_bvalid,
%000002     output logic        m_axi_bready,
            // AXI4 Master Read Address Channel
%000005     output logic [63:0] m_axi_araddr,
%000006     output logic [7:0]  m_axi_arlen,
%000001     output logic [2:0]  m_axi_arsize,
%000001     output logic [1:0]  m_axi_arburst,
 000018     output logic        m_axi_arvalid,
 000018     input  logic        m_axi_arready,
            // AXI4 Master Read Data Channel
~000104     input  logic [127:0] m_axi_rdata,
%000000     input  logic [1:0]  m_axi_rresp,
 000018     input  logic        m_axi_rlast,
 000018     input  logic        m_axi_rvalid,
 000018     output logic        m_axi_rready,
            // Buffer interface
 000018     output logic        buf_wr_en,
~000104     output logic [11:0] buf_wr_addr,
~000104     output logic [127:0] buf_wr_data,
%000002     output logic        buf_rd_en,
%000008     output logic [11:0] buf_rd_addr,
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
        
~000040     dma_state_t state, next;
        
            // =========================================================================
            // Internal Registers
            // =========================================================================
%000006     logic [1:0]  cmd_reg;
%000005     logic [63:0] target_addr;
%000006     logic [7:0]  burst_len;      // awlen/arlen (beats - 1)
~000112     logic [7:0]  beat_cnt;
~000104     logic [11:0] buf_wr_addr_reg;
%000008     logic [11:0] buf_rd_addr_reg;
~000011     logic [63:0] base_addr;
        
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
 006317             IDLE: begin
~006311                 if (dma_start)
~000010                     next = ADDR_CALC;
                    end
~000050             ADDR_CALC: begin
~000045                 if (cmd_reg == CMD_O)
%000005                     next = AW_SEND;
                        else
~000045                     next = AR_SEND;
                    end
 000090             AR_SEND: begin
~000045                 if (m_axi_arready)
~000045                     next = R_RECV;
                    end
 000520             R_RECV: begin
~000475                 if (m_axi_rlast && m_axi_rvalid)
~000045                     next = IDLE;
                    end
~000010             AW_SEND: begin
%000005                 if (m_axi_awready)
%000005                     next = W_SEND;
                    end
~000045             W_SEND: begin
~000040                 if (m_axi_wlast && m_axi_wready)
%000005                     next = B_RECV;
                    end
%000005             B_RECV: begin
%000005                 if (m_axi_bvalid)
%000005                     next = IDLE;
                    end
%000000             default: next = IDLE;
                endcase
            end
        
            // =========================================================================
            // Address generation
            // =========================================================================
            // Select base address based on command
 006407     always_comb begin
 006407         case (cmd_reg)
 003973             CMD_Q: base_addr = q_base + 64'(row_cnt) * stride;
 002434             CMD_K: base_addr = k_base + 64'(tile_cnt) * 16 * stride;
~000210             CMD_V: base_addr = v_base + 64'(tile_cnt) * 16 * stride;
~000075             CMD_O: base_addr = o_base + 64'(row_cnt) * stride;
                endcase
            end
        
            // Burst length calculation
            // Q: 128 bytes = 8 beats (arlen=7), K/V: 256 bytes = 16 beats (arlen=15), O: 128 bytes = 8 beats
 006407     always_comb begin
 006407         case (cmd_reg)
 003973             CMD_Q: burst_len = 8'd7;
 002434             CMD_K: burst_len = 8'd15;
~000042             CMD_V: burst_len = 8'd15;
~000015             CMD_O: burst_len = 8'd7;
                endcase
            end
        
            // =========================================================================
            // Command latch and address register
            // =========================================================================
 006406     always_ff @(posedge clk or negedge rst_n) begin
~006369         if (!rst_n) begin
~000037             cmd_reg        <= 2'b00;
~000037             target_addr    <= 64'h0;
~000037             beat_cnt       <= 8'h0;
~000037             buf_wr_addr_reg <= 12'h0;
~000037             buf_rd_addr_reg <= 12'h0;
 006369         end else begin
 006369             case (state)
 006279                 IDLE: begin
~006273                     if (dma_start) begin
~000010                         cmd_reg <= dma_cmd;
                            end
                        end
~000010                 ADDR_CALC: begin
~000010                     target_addr <= base_addr;
~000010                     beat_cnt    <= 8'h0;
~000010                     buf_wr_addr_reg <= 12'h0;
~000010                     buf_rd_addr_reg <= 12'h0;
                        end
 000104                 R_RECV: begin
~000104                     if (m_axi_rvalid) begin
 000104                         beat_cnt <= beat_cnt + 1'b1;
 000104                         buf_wr_addr_reg <= buf_wr_addr_reg + 1'b1;
                            end
                        end
%000009                 W_SEND: begin
%000008                     if (m_axi_wready) begin
%000008                         beat_cnt <= beat_cnt + 1'b1;
%000008                         buf_rd_addr_reg <= buf_rd_addr_reg + 1'b1;
                            end
                        end
 000021                 default: ;
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
 000020     logic dma_done_pulse;
        
 006406     always_ff @(posedge clk or negedge rst_n) begin
~006369         if (!rst_n)
~000037             dma_done_pulse <= 1'b0;
                else
 006369             dma_done_pulse <= (state == R_RECV && m_axi_rlast && m_axi_rvalid) ||
 006369                               (state == B_RECV && m_axi_bvalid);
            end
        
            assign dma_done = dma_done_pulse;
        
        endmodule
        
