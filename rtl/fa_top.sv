// =============================================================================
// Module: fa_top
// Description: Top-level wrapper for FlashAttention accelerator.
//              Instantiates all submodules, reset synchronizer, and scan chain.
// MAS: M01 | Type: io | Deps: fa_ctrl (M02), fa_dma (M03), fa_systolic (M04),
//       fa_softmax (M05), fa_divider (M06), fa_buffer_mgr (M07), fa_regfile (M08)
// =============================================================================
module fa_top (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    // DFT signals
    input  logic [1:0]  test_mode,
    input  logic        test_se,
    input  logic [7:0]  test_si,
    output logic [7:0]  test_so,
    // AXI4-Lite Slave (Register File)
    input  logic [5:0]  s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,
    input  logic [5:0]  s_axil_araddr,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready,
    // AXI4 Master (DMA)
    output logic [63:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,
    output logic [2:0]  m_axi_awsize,
    output logic [1:0]  m_axi_awburst,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    output logic [127:0] m_axi_wdata,
    output logic [15:0]  m_axi_wstrb,
    output logic         m_axi_wlast,
    output logic         m_axi_wvalid,
    input  logic         m_axi_wready,
    input  logic [1:0]  m_axi_bresp,
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,
    output logic [63:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    input  logic [127:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rlast,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

    // =========================================================================
    // Reset Synchronizer (async assert, sync deassert)
    // =========================================================================
    logic rst_n_meta, rst_n_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_meta <= 1'b0;
            rst_n_sync <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n_sync <= rst_n_meta;
        end
    end

    // Use synchronized reset for all internal logic
    wire rst_n_int = rst_n_sync;

    // =========================================================================
    // Internal wires
    // =========================================================================

    // Regfile <-> Ctrl
    logic        reg_start;
    logic        reg_soft_reset;
    logic        reg_causal_en;
    logic [63:0] reg_q_base, reg_k_base, reg_v_base, reg_o_base;
    logic [31:0] reg_stride;

    // Ctrl -> DMA
    logic        ctrl_dma_start;
    logic [1:0]  ctrl_dma_cmd;

    // DMA -> Ctrl
    logic        dma_done;

    // Ctrl -> MAC
    logic        ctrl_mac_start;
    logic        ctrl_mac_mode;

    // MAC -> Ctrl
    logic        mac_done;

    // Ctrl -> Softmax
    logic        ctrl_sm_start;

    // Softmax -> Ctrl
    logic        sm_done;

    // Ctrl -> Divider
    logic        ctrl_div_start;

    // Divider -> Ctrl
    logic        div_done;

    // Ctrl -> Buffer
    logic        ctrl_buf_sel;
    logic        ctrl_acc_clear;

    // Ctrl status
    logic        ctrl_busy, ctrl_done, ctrl_error;
    logic [7:0]  ctrl_row_cnt;
    logic [3:0]  ctrl_tile_cnt;
    logic [31:0] ctrl_cycle_cnt;

    // DMA <-> Buffer
    logic        dma_buf_wr_en;
    logic [11:0] dma_buf_wr_addr;
    logic [127:0] dma_buf_wr_data;
    logic        dma_buf_rd_en;
    logic [11:0] dma_buf_rd_addr;
    logic [127:0] dma_buf_rd_data;

    // MAC <-> Buffer
    logic [255:0] buf_q_data, buf_k_data, buf_v_data;

    // MAC output
    logic [639:0] mac_acc_out;

    // Softmax <-> MAC
    logic [255:0] sm_exp_out;

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
