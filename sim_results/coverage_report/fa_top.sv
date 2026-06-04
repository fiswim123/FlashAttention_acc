//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_top
        // Description: Top-level wrapper for FlashAttention accelerator.
        //              Instantiates all submodules, reset synchronizer, and scan chain.
        // MAS: M01 | Type: io | Deps: fa_ctrl (M02), fa_dma (M03), fa_systolic (M04),
        //       fa_softmax (M05), fa_divider (M06), fa_buffer_mgr (M07), fa_regfile (M08)
        // =============================================================================
        module fa_top (
            // Clock and Reset
 009235     input  logic        clk,
%000007     input  logic        rst_n,
            // DFT signals
%000000     input  logic [1:0]  test_mode,
%000000     input  logic        test_se,
%000002     input  logic [7:0]  test_si,
%000002     output logic [7:0]  test_so,
            // AXI4-Lite Slave (Register File)
~000013     input  logic [5:0]  s_axil_awaddr,
%000001     input  logic        s_axil_awvalid,
 000042     output logic        s_axil_awready,
%000007     input  logic [31:0] s_axil_wdata,
%000001     input  logic [3:0]  s_axil_wstrb,
 000033     input  logic        s_axil_wvalid,
 000042     output logic        s_axil_wready,
%000000     output logic [1:0]  s_axil_bresp,
 000041     output logic        s_axil_bvalid,
 000034     input  logic        s_axil_bready,
~000017     input  logic [5:0]  s_axil_araddr,
%000003     input  logic        s_axil_arvalid,
 000054     output logic        s_axil_arready,
~000062     output logic [31:0] s_axil_rdata,
%000000     output logic [1:0]  s_axil_rresp,
 000053     output logic        s_axil_rvalid,
 000048     input  logic        s_axil_rready,
            // AXI4 Master (DMA)
%000002     output logic [63:0] m_axi_awaddr,
%000006     output logic [7:0]  m_axi_awlen,
%000001     output logic [2:0]  m_axi_awsize,
%000001     output logic [1:0]  m_axi_awburst,
%000000     output logic        m_axi_awvalid,
%000000     input  logic        m_axi_awready,
%000000     output logic [127:0] m_axi_wdata,
%000001     output logic [15:0]  m_axi_wstrb,
%000000     output logic         m_axi_wlast,
%000000     output logic         m_axi_wvalid,
%000000     input  logic         m_axi_wready,
%000000     input  logic [1:0]  m_axi_bresp,
%000000     input  logic        m_axi_bvalid,
%000000     output logic        m_axi_bready,
%000002     output logic [63:0] m_axi_araddr,
%000006     output logic [7:0]  m_axi_arlen,
%000001     output logic [2:0]  m_axi_arsize,
%000001     output logic [1:0]  m_axi_arburst,
 000012     output logic        m_axi_arvalid,
 000012     input  logic        m_axi_arready,
~000072     input  logic [127:0] m_axi_rdata,
%000000     input  logic [1:0]  m_axi_rresp,
 000012     input  logic        m_axi_rlast,
 000012     input  logic        m_axi_rvalid,
 000012     output logic        m_axi_rready
        );
        
            // =========================================================================
            // Reset Synchronizer (async assert, sync deassert)
            // =========================================================================
%000007     logic rst_n_meta, rst_n_sync;
        
 004618     always_ff @(posedge clk or negedge rst_n) begin
 004607         if (!rst_n) begin
 000011             rst_n_meta <= 1'b0;
 000011             rst_n_sync <= 1'b0;
 004607         end else begin
 004607             rst_n_meta <= 1'b1;
 004607             rst_n_sync <= rst_n_meta;
                end
            end
        
            // Use synchronized reset for all internal logic
%000007     wire rst_n_int = rst_n_sync;
        
            // =========================================================================
            // Internal wires
            // =========================================================================
        
            // Regfile <-> Ctrl
%000006     logic        reg_start;
%000000     logic        reg_soft_reset;
%000002     logic        reg_causal_en;
%000003     logic [63:0] reg_q_base, reg_k_base, reg_v_base, reg_o_base;
%000002     logic [31:0] reg_stride;
        
            // Ctrl -> DMA
 000012     logic        ctrl_dma_start;
~000012     logic [1:0]  ctrl_dma_cmd;
        
            // DMA -> Ctrl
 000012     logic        dma_done;
        
            // Ctrl -> MAC
 000012     logic        ctrl_mac_start;
%000006     logic        ctrl_mac_mode;
        
            // MAC -> Ctrl
 000012     logic        mac_done;
        
            // Ctrl -> Softmax
%000006     logic        ctrl_sm_start;
        
            // Softmax -> Ctrl
%000006     logic        sm_done;
        
            // Ctrl -> Divider
%000000     logic        ctrl_div_start;
        
            // Divider -> Ctrl
%000000     logic        div_done;
        
            // Ctrl -> Buffer
%000006     logic        ctrl_buf_sel;
%000006     logic        ctrl_acc_clear;
        
            // Ctrl status
%000006     logic        ctrl_busy, ctrl_done, ctrl_error;
%000000     logic [7:0]  ctrl_row_cnt;
%000006     logic [3:0]  ctrl_tile_cnt;
~002312     logic [31:0] ctrl_cycle_cnt;
        
            // DMA <-> Buffer
 000012     logic        dma_buf_wr_en;
~000072     logic [11:0] dma_buf_wr_addr;
~000072     logic [127:0] dma_buf_wr_data;
%000000     logic        dma_buf_rd_en;
%000000     logic [11:0] dma_buf_rd_addr;
%000000     logic [127:0] dma_buf_rd_data;
        
            // MAC <-> Buffer
%000002     logic [255:0] buf_q_data, buf_k_data, buf_v_data;
        
            // MAC output
            logic [639:0] mac_acc_out;
        
            // Softmax <-> MAC
%000006     logic [255:0] sm_exp_out;
        
            // =========================================================================
            // Module Instantiations
            // =========================================================================
        
            // ---- M08: fa_regfile ----
            fa_regfile u_regfile (
                .clk             (clk),
                .rst_n           (rst_n_int),
                .s_axil_awaddr   (s_axil_awaddr),
                .s_axil_awvalid  (s_axil_awvalid),
                .s_axil_awready  (s_axil_awready),
                .s_axil_wdata    (s_axil_wdata),
                .s_axil_wstrb    (s_axil_wstrb),
                .s_axil_wvalid   (s_axil_wvalid),
                .s_axil_wready   (s_axil_wready),
                .s_axil_bresp    (s_axil_bresp),
                .s_axil_bvalid   (s_axil_bvalid),
                .s_axil_bready   (s_axil_bready),
                .s_axil_araddr   (s_axil_araddr),
                .s_axil_arvalid  (s_axil_arvalid),
                .s_axil_arready  (s_axil_arready),
                .s_axil_rdata    (s_axil_rdata),
                .s_axil_rresp    (s_axil_rresp),
                .s_axil_rvalid   (s_axil_rvalid),
                .s_axil_rready   (s_axil_rready),
                .hw_busy         (ctrl_busy),
                .hw_done         (ctrl_done),
                .hw_error        (ctrl_error),
                .hw_cycle_cnt    (ctrl_cycle_cnt),
                .reg_start       (reg_start),
                .reg_soft_reset  (reg_soft_reset),
                .reg_causal_en   (reg_causal_en),
                .reg_q_base      (reg_q_base),
                .reg_k_base      (reg_k_base),
                .reg_v_base      (reg_v_base),
                .reg_o_base      (reg_o_base),
                .reg_stride      (reg_stride)
            );
        
            // ---- M02: fa_ctrl ----
            fa_ctrl u_ctrl (
                .clk          (clk),
                .rst_n        (rst_n_int),
                .start        (reg_start),
                .busy         (ctrl_busy),
                .done         (ctrl_done),
                .error        (ctrl_error),
                .causal_en    (reg_causal_en),
                .soft_reset   (reg_soft_reset),
                .dma_start    (ctrl_dma_start),
                .dma_done     (dma_done),
                .dma_cmd      (ctrl_dma_cmd),
                .mac_start    (ctrl_mac_start),
                .mac_done     (mac_done),
                .mac_mode     (ctrl_mac_mode),
                .sm_start     (ctrl_sm_start),
                .sm_done      (sm_done),
                .div_start    (ctrl_div_start),
                .div_done     (div_done),
                .buf_sel      (ctrl_buf_sel),
                .acc_clear    (ctrl_acc_clear),
                .row_cnt      (ctrl_row_cnt),
                .tile_cnt     (ctrl_tile_cnt),
                .cycle_cnt    (ctrl_cycle_cnt)
            );
        
            // ---- M03: fa_dma ----
            fa_dma u_dma (
                .clk            (clk),
                .rst_n          (rst_n_int),
                .dma_start      (ctrl_dma_start),
                .dma_done       (dma_done),
                .dma_cmd        (ctrl_dma_cmd),
                .q_base         (reg_q_base),
                .k_base         (reg_k_base),
                .v_base         (reg_v_base),
                .o_base         (reg_o_base),
                .stride         (reg_stride),
                .row_cnt        (ctrl_row_cnt),
                .tile_cnt       (ctrl_tile_cnt),
                .m_axi_awaddr   (m_axi_awaddr),
                .m_axi_awlen    (m_axi_awlen),
                .m_axi_awsize   (m_axi_awsize),
                .m_axi_awburst  (m_axi_awburst),
                .m_axi_awvalid  (m_axi_awvalid),
                .m_axi_awready  (m_axi_awready),
                .m_axi_wdata    (m_axi_wdata),
                .m_axi_wstrb    (m_axi_wstrb),
                .m_axi_wlast    (m_axi_wlast),
                .m_axi_wvalid   (m_axi_wvalid),
                .m_axi_wready   (m_axi_wready),
                .m_axi_bresp    (m_axi_bresp),
                .m_axi_bvalid   (m_axi_bvalid),
                .m_axi_bready   (m_axi_bready),
                .m_axi_araddr   (m_axi_araddr),
                .m_axi_arlen    (m_axi_arlen),
                .m_axi_arsize   (m_axi_arsize),
                .m_axi_arburst  (m_axi_arburst),
                .m_axi_arvalid  (m_axi_arvalid),
                .m_axi_arready  (m_axi_arready),
                .m_axi_rdata    (m_axi_rdata),
                .m_axi_rresp    (m_axi_rresp),
                .m_axi_rlast    (m_axi_rlast),
                .m_axi_rvalid   (m_axi_rvalid),
                .m_axi_rready   (m_axi_rready),
                .buf_wr_en      (dma_buf_wr_en),
                .buf_wr_addr    (dma_buf_wr_addr),
                .buf_wr_data    (dma_buf_wr_data),
                .buf_rd_en      (dma_buf_rd_en),
                .buf_rd_addr    (dma_buf_rd_addr),
                .buf_rd_data    (dma_buf_rd_data)
            );
        
            // ---- M04: fa_systolic ----
            fa_systolic u_systolic (
                .clk        (clk),
                .rst_n      (rst_n_int),
                .mac_start  (ctrl_mac_start),
                .mac_done   (mac_done),
                .mac_mode   (ctrl_mac_mode),
                .q_data     (buf_q_data),
                .kv_data    (ctrl_mac_mode ? buf_v_data : buf_k_data),
                .score_in   (sm_exp_out),
                .acc_out    (mac_acc_out),
                .acc_clear  (ctrl_acc_clear)
            );
        
            // ---- M05: fa_softmax ----
            fa_softmax u_softmax (
                .clk          (clk),
                .rst_n        (rst_n_int),
                .sm_start     (ctrl_sm_start),
                .sm_done      (sm_done),
                .score        (mac_acc_out[255:0]),  // Lower 16 elements from MAC
                .m_old        (40'h0),               // TODO: connect from buffer_mgr
                .l_old        (40'h0),               // TODO: connect from buffer_mgr
                .m_new        (),                    // TODO: connect to buffer_mgr
                .l_new        (),                    // TODO: connect to divider
                .correction   (),                    // TODO: connect to buffer_mgr
                .exp_out      (sm_exp_out),
                .causal_mask  (reg_causal_en ? 16'hFFFF : 16'hFFFF)  // TODO: proper causal mask
            );
        
            // ---- M06: fa_divider ----
            fa_divider u_divider (
                .clk        (clk),
                .rst_n      (rst_n_int),
                .div_start  (ctrl_div_start),
                .div_done   (div_done),
                .dividend   (mac_acc_out[39:0]),     // TODO: proper accumulator selection
                .divisor    (40'h1),                 // TODO: connect to l_new from softmax
                .quotient   (),                      // TODO: connect to O buffer write path
                .busy       ()                       // unused
            );
        
            // ---- M07: fa_buffer_mgr ----
            fa_buffer_mgr u_buffer_mgr (
                .clk          (clk),
                .rst_n        (rst_n_int),
                .dma_wr_en    (dma_buf_wr_en),
                .dma_wr_addr  (dma_buf_wr_addr),
                .dma_wr_data  (dma_buf_wr_data),
                .dma_rd_en    (dma_buf_rd_en),
                .dma_rd_addr  (dma_buf_rd_addr),
                .dma_rd_data  (dma_buf_rd_data),
                .mac_q_en     (ctrl_mac_start && !ctrl_mac_mode),
                .mac_q_data   (buf_q_data),
                .mac_k_en     (ctrl_mac_start && !ctrl_mac_mode),
                .mac_k_data   (buf_k_data),
                .mac_v_en     (ctrl_mac_start && ctrl_mac_mode),
                .mac_v_data   (buf_v_data),
                .o_wr_en      (1'b0),               // TODO: connect from divider output path
                .o_wr_data    (256'h0),
                .buf_sel      (ctrl_buf_sel),
                .lut_rd_en    (1'b0),               // TODO: connect from softmax
                .lut_rd_addr  (8'h0),
                .lut_rd_data  ()
            );
        
            // =========================================================================
            // Scan chain connections (DFT)
            // Chain 0-1: fa_ctrl, Chain 2-3: fa_dma, Chain 4-5: fa_systolic,
            // Chain 6: fa_softmax + fa_divider, Chain 7: fa_buffer_mgr + fa_regfile
            // =========================================================================
            // For now, loopback scan chains (to be replaced by synthesis tool stitching)
            assign test_so = test_si;
        
        endmodule
        
