//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_regfile
        // Description: AXI4-Lite slave register file for FlashAttention accelerator
        // MAS: M08 | Type: io | Deps: none (leaf)
        // =============================================================================
        module fa_regfile (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
            // AXI4-Lite Write Address Channel
~000013     input  logic [5:0]  s_axil_awaddr,
%000001     input  logic        s_axil_awvalid,
 000042     output logic        s_axil_awready,
            // AXI4-Lite Write Data Channel
%000007     input  logic [31:0] s_axil_wdata,
%000001     input  logic [3:0]  s_axil_wstrb,
 000033     input  logic        s_axil_wvalid,
 000042     output logic        s_axil_wready,
            // AXI4-Lite Write Response Channel
%000000     output logic [1:0]  s_axil_bresp,
 000041     output logic        s_axil_bvalid,
 000034     input  logic        s_axil_bready,
            // AXI4-Lite Read Address Channel
~000017     input  logic [5:0]  s_axil_araddr,
%000003     input  logic        s_axil_arvalid,
 000054     output logic        s_axil_arready,
            // AXI4-Lite Read Data Channel
~000062     output logic [31:0] s_axil_rdata,
%000000     output logic [1:0]  s_axil_rresp,
 000053     output logic        s_axil_rvalid,
 000048     input  logic        s_axil_rready,
            // Hardware status inputs (directly driven into STATUS register)
%000006     input  logic        hw_busy,
%000000     input  logic        hw_done,
%000000     input  logic        hw_error,
~002312     input  logic [31:0] hw_cycle_cnt,
            // Register outputs to controller
%000006     output logic        reg_start,
%000000     output logic        reg_soft_reset,
%000002     output logic        reg_causal_en,
%000003     output logic [63:0] reg_q_base,
%000002     output logic [63:0] reg_k_base,
%000002     output logic [63:0] reg_v_base,
%000002     output logic [63:0] reg_o_base,
%000002     output logic [31:0] reg_stride
        );
        
            // =========================================================================
            // Register Map (16 x 32-bit, addressed at 6'h00..6'h3C, 4-byte aligned)
            // =========================================================================
            localparam ADDR_CTRL       = 6'h00;  // W: START[0], SOFT_RESET[1], CAUSAL_EN[2]
            localparam ADDR_STATUS     = 6'h04;  // R: BUSY[0], DONE[1](W1C), ERROR[2](W1C)
            localparam ADDR_CFG        = 6'h08;  // R/W: reserved config
            localparam ADDR_Q_BASE_L   = 6'h0C;  // R/W: Q base address [31:0]
            localparam ADDR_Q_BASE_H   = 6'h10;  // R/W: Q base address [63:32]
            localparam ADDR_K_BASE_L   = 6'h14;  // R/W: K base address [31:0]
            localparam ADDR_K_BASE_H   = 6'h18;  // R/W: K base address [63:32]
            localparam ADDR_V_BASE_L   = 6'h1C;  // R/W: V base address [31:0]
            localparam ADDR_V_BASE_H   = 6'h20;  // R/W: V base address [63:32]
            localparam ADDR_O_BASE_L   = 6'h24;  // R/W: O base address [31:0]
            localparam ADDR_O_BASE_H   = 6'h28;  // R/W: O base address [63:32]
            localparam ADDR_STRIDE     = 6'h2C;  // R/W: row stride
            localparam ADDR_CYCLES     = 6'h30;  // R: cycle counter (hw)
            localparam ADDR_REV        = 6'h34;  // R: design revision / ID
        
            logic [31:0] reg_file [0:15];
~000015     logic [5:0]  wr_addr_latched;
~000021     logic [5:0]  rd_addr_latched;
        
            // =========================================================================
            // Write FSM (axil_wr_fsm): WR_IDLE -> WR_DATA -> WR_RESP
            // =========================================================================
            typedef enum logic [1:0] {
                WR_IDLE  = 2'b00,
                WR_DATA  = 2'b01,
                WR_RESP  = 2'b10
            } wr_state_t;
        
 000075     wr_state_t wr_state, wr_next;
        
            // Write state register
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n)
 000019             wr_state <= WR_IDLE;
                else
 004602             wr_state <= wr_next;
            end
        
            // Write next-state logic
 023100     always_comb begin
 023100         wr_next = wr_state;
 023100         case (wr_state)
 000477             WR_IDLE: if (s_axil_awvalid) wr_next = WR_DATA;
 000350             WR_DATA: if (s_axil_wvalid)  wr_next = WR_RESP;
 022273             WR_RESP: if (s_axil_bready)  wr_next = WR_IDLE;
%000000             default: wr_next = WR_IDLE;
                endcase
            end
        
            // Write address latch
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             wr_addr_latched <= 6'h0;
 004581         else if (wr_state == WR_IDLE && s_axil_awvalid)
 000021             wr_addr_latched <= s_axil_awaddr;
            end
        
            // AXI write handshake outputs
            assign s_axil_awready = (wr_state == WR_IDLE);
            assign s_axil_wready  = (wr_state == WR_DATA);
            assign s_axil_bvalid  = (wr_state == WR_RESP);
            assign s_axil_bresp   = 2'b00;  // OKAY
        
            // Write enable and write protect (BUSY blocks writes except STATUS)
 000042     logic wr_en_raw;
            assign wr_en_raw = (wr_state == WR_DATA && s_axil_wvalid);
        
%000006     wire wr_protect = reg_file[1][0] && (wr_addr_latched != ADDR_STATUS);
 000032     wire actual_wr_en = wr_en_raw && !wr_protect;
        
            // =========================================================================
            // Read FSM (axil_rd_fsm): RD_IDLE -> RD_DATA -> RD_RESP
            // =========================================================================
            typedef enum logic [1:0] {
                RD_IDLE  = 2'b00,
                RD_DATA  = 2'b01,
                RD_RESP  = 2'b10
            } rd_state_t;
        
 000099     rd_state_t rd_state, rd_next;
        
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n)
 000019             rd_state <= RD_IDLE;
                else
 004602             rd_state <= rd_next;
            end
        
 023100     always_comb begin
 023100         rd_next = rd_state;
 023100         case (rd_state)
 005187             RD_IDLE: if (s_axil_arvalid) rd_next = RD_DATA;
 000135             RD_DATA:                     rd_next = RD_RESP;
 017778             RD_RESP: if (s_axil_rready)  rd_next = RD_IDLE;
%000000             default: rd_next = RD_IDLE;
                endcase
            end
        
            // Read address latch
 004621     always_ff @(posedge clk or negedge rst_n) begin
 000019         if (!rst_n)
 000019             rd_addr_latched <= 6'h0;
 004575         else if (rd_state == RD_IDLE && s_axil_arvalid)
 000027             rd_addr_latched <= s_axil_araddr;
            end
        
            // AXI read handshake outputs
            assign s_axil_arready = (rd_state == RD_IDLE);
            assign s_axil_rvalid  = (rd_state == RD_RESP);
            assign s_axil_rresp   = 2'b00;  // OKAY
        
            // Read mux: STATUS and CYCLES are special (hardware-driven)
 004622     always_comb begin
 004622         s_axil_rdata = 32'h0;
 004622         case (rd_addr_latched)
 002686             ADDR_STATUS:   s_axil_rdata = {29'h0, reg_file[1][2], reg_file[1][1], hw_busy};
 000111             ADDR_CYCLES:   s_axil_rdata = hw_cycle_cnt;
%000004             ADDR_REV:      s_axil_rdata = 32'hFA_00_01_00;  // FlashAttention v1.0
 001821             default:       s_axil_rdata = reg_file[rd_addr_latched[5:2]];
                endcase
            end
        
            // =========================================================================
            // Register Write Logic
            // =========================================================================
 004621     always_ff @(posedge clk or negedge rst_n) begin
 004602         if (!rst_n) begin
 000304             for (int i = 0; i < 16; i++)
 000304                 reg_file[i] <= 32'h0;
 004602         end else begin
                    // Hardware updates for STATUS
 004602             reg_file[1][0] <= hw_busy;
                    // W1C for DONE and ERROR
~004602             if (actual_wr_en && wr_addr_latched == ADDR_STATUS) begin
%000000                 reg_file[1][1] <= reg_file[1][1] & ~s_axil_wdata[1];  // W1C DONE
%000000                 reg_file[1][2] <= reg_file[1][2] & ~s_axil_wdata[2];  // W1C ERROR
 004602             end else begin
~004602                 if (hw_done)  reg_file[1][1] <= 1'b1;
~004602                 if (hw_error) reg_file[1][2] <= 1'b1;
                    end
        
                    // Self-clearing bits: START and SOFT_RESET
~004597             if (actual_wr_en && wr_addr_latched == ADDR_CTRL) begin
%000003                 if (s_axil_wdata[0]) reg_file[0][0] <= 1'b1;  // START set
%000005                 if (s_axil_wdata[1]) reg_file[0][1] <= 1'b1;  // SOFT_RESET set
%000005                 reg_file[0][2] <= s_axil_wdata[2];             // CAUSAL_EN (sticky)
 004597             end else begin
 004597                 reg_file[0][0] <= 1'b0;  // START self-clears
 004597                 reg_file[0][1] <= 1'b0;  // SOFT_RESET self-clears
                    end
        
                    // Normal register writes (address/data phase)
 004586             if (actual_wr_en) begin
 000016                 case (wr_addr_latched)
%000003                     ADDR_Q_BASE_L: reg_file[3] <= s_axil_wdata;
%000001                     ADDR_Q_BASE_H: reg_file[4] <= s_axil_wdata;
%000001                     ADDR_K_BASE_L: reg_file[5] <= s_axil_wdata;
%000001                     ADDR_K_BASE_H: reg_file[6] <= s_axil_wdata;
%000001                     ADDR_V_BASE_L: reg_file[7] <= s_axil_wdata;
%000001                     ADDR_V_BASE_H: reg_file[8] <= s_axil_wdata;
%000001                     ADDR_O_BASE_L: reg_file[9] <= s_axil_wdata;
%000001                     ADDR_O_BASE_H: reg_file[10] <= s_axil_wdata;
%000001                     ADDR_STRIDE:   reg_file[11] <= s_axil_wdata;
%000005                     default: ;  // do nothing for STATUS, CYCLES, REV
                        endcase
                    end
                end
            end
        
            // =========================================================================
            // Output assignments
            // =========================================================================
            assign reg_start       = reg_file[0][0];
            assign reg_soft_reset  = reg_file[0][1];
            assign reg_causal_en   = reg_file[0][2];
            assign reg_q_base      = {reg_file[4], reg_file[3]};
            assign reg_k_base      = {reg_file[6], reg_file[5]};
            assign reg_v_base      = {reg_file[8], reg_file[7]};
            assign reg_o_base      = {reg_file[10], reg_file[9]};
            assign reg_stride      = reg_file[11];
        
        endmodule
        
