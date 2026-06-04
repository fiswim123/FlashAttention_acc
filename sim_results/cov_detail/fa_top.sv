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
 012799     input  logic        clk,
 000013     input  logic        rst_n,
            // DFT signals
%000000     input  logic [1:0]  test_mode,
%000000     input  logic        test_se,
%000002     input  logic [7:0]  test_si,
%000002     output logic [7:0]  test_so,
            // AXI4-Lite Slave (Register File)
~000025     input  logic [5:0]  s_axil_awaddr,
%000007     input  logic        s_axil_awvalid,
 000078     output logic        s_axil_awready,
~000012     input  logic [31:0] s_axil_wdata,
%000003     input  logic [3:0]  s_axil_wstrb,
 000063     input  logic        s_axil_wvalid,
 000078     output logic        s_axil_wready,
%000000     output logic [1:0]  s_axil_bresp,
 000077     output logic        s_axil_bvalid,
 000064     input  logic        s_axil_bready,
~000017     input  logic [5:0]  s_axil_araddr,
%000005     input  logic        s_axil_arvalid,
 000064     output logic        s_axil_arready,
~000062     output logic [31:0] s_axil_rdata,
%000000     output logic [1:0]  s_axil_rresp,
 000063     output logic        s_axil_rvalid,
 000054     input  logic        s_axil_rready,
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
 000013     logic rst_n_meta, rst_n_sync;
        
 006401     always_ff @(posedge clk or negedge rst_n) begin
 006378         if (!rst_n) begin
 000023             rst_n_meta <= 1'b0;
 000023             rst_n_sync <= 1'b0;
 006378         end else begin
 006378             rst_n_meta <= 1'b1;
 006378             rst_n_sync <= rst_n_meta;
                end
            end
        
            // Use synchronized reset for all internal logic
 000013     wire rst_n_int = rst_n_sync;
        
            // =========================================================================
            // Internal wires
            // =========================================================================
        
            // Regfile <-> Ctrl
%000006     logic        reg_start;
%000000     logic        reg_soft_reset;
%000008     logic        reg_causal_en;
%000009     logic [63:0] reg_q_base, reg_k_base, reg_v_base, reg_o_base;
%000005     logic [31:0] reg_stride;
        
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
%000006     logic        acc_clear;
        
            // Ctrl status
%000006     logic        ctrl_busy, ctrl_done, ctrl_error;
%000000     logic [7:0]  ctrl_row_cnt;
%000006     logic [3:0]  ctrl_tile_cnt;
~002472     logic [31:0] ctrl_cycle_cnt;
%000000     logic [3:0]  ctrl_div_elem_idx;
        
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
        
            // Softmax outputs
%000006     logic [255:0] sm_exp_out;
%000007     logic [39:0]  sm_m_new, sm_l_new;
%000006     logic [15:0]  sm_correction;
        
            // Buffer mgr running stats
%000007     logic [39:0]  buf_m_old, buf_l_old;
        
            // Divider
%000000     logic [15:0]  div_quotient;
%000000     logic         div_busy;
        
            // Divider quotient accumulator for O buffer write
%000000     logic [255:0] o_buf_write_data;
%000000     logic         o_buf_write_en;
        
            // Causal mask
%000009     logic [15:0]  causal_mask;
        
            // =========================================================================
            // Causal Mask Generation
            // =========================================================================
            // Causal attention: element (row, col) is valid only if col <= row.
            // Tile column range: [tile_cnt*16, tile_cnt*16+15].
            // - If tile_col_start > row: all columns masked (upper triangle tile)
            // - If tile_col_start + 15 <= row: all columns valid (lower triangle tile)
            // - Otherwise: columns 0..(row - tile_col_start) are valid (diagonal tile)
%000006     wire [7:0] tile_col_start = {ctrl_tile_cnt, 4'b0};
%000006     wire       tile_above     = (tile_col_start > ctrl_row_cnt);
%000000     wire       tile_below     = (tile_col_start + 8'd15 <= ctrl_row_cnt);
%000000     wire [3:0] diag_limit     = ctrl_row_cnt[3:0] - tile_col_start[3:0];
        
 006407     always_comb begin
 102512         for (int j = 0; j < 16; j++) begin
 083888             if (!reg_causal_en)
 083888                 causal_mask[j] = 1'b1;
%000000             else if (tile_above)
%000000                 causal_mask[j] = 1'b0;
~018624             else if (tile_below)
%000000                 causal_mask[j] = 1'b1;
                    else
 018624                 causal_mask[j] = (j[3:0] <= diag_limit) ? 1'b1 : 1'b0;
                end
            end
        
            // =========================================================================
            // Divider Quotient Accumulator (16 x 16-bit -> 256-bit for O buffer)
            // =========================================================================
 006401     always_ff @(posedge clk or negedge rst_n) begin
 006378         if (!rst_n) begin
 000023             o_buf_write_data <= 256'h0;
 000023             o_buf_write_en   <= 1'b0;
 006378         end else begin
 006378             o_buf_write_en <= 1'b0;
                    // Capture each divider quotient element
~006378             if (div_done) begin
%000000                 o_buf_write_data[ctrl_div_elem_idx*16 +: 16] <= div_quotient;
                        // After capturing the 16th element, signal write
%000000                 if (ctrl_div_elem_idx == 4'd15)
%000000                     o_buf_write_en <= 1'b1;
                    end
                end
            end
        
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
                .acc_clear    (acc_clear),
                .row_cnt      (ctrl_row_cnt),
                .tile_cnt     (ctrl_tile_cnt),
                .cycle_cnt    (ctrl_cycle_cnt),
                .div_elem_idx (ctrl_div_elem_idx)
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
                .acc_clear  (acc_clear)
            );
        
            // ---- M05: fa_softmax ----
            fa_softmax u_softmax (
                .clk          (clk),
                .rst_n        (rst_n_int),
                .sm_start     (ctrl_sm_start),
                .sm_done      (sm_done),
                .score        (mac_acc_out[255:0]),
                .m_old        (buf_m_old),
                .l_old        (buf_l_old),
                .m_new        (sm_m_new),
                .l_new        (sm_l_new),
                .correction   (sm_correction),
                .exp_out      (sm_exp_out),
                .causal_mask  (causal_mask)
            );
        
            // ---- M06: fa_divider ----
            fa_divider u_divider (
                .clk        (clk),
                .rst_n      (rst_n_int),
                .div_start  (ctrl_div_start),
                .div_done   (div_done),
                .dividend   (mac_acc_out[ctrl_div_elem_idx*40 +: 40]),
                .divisor    (sm_l_new),
                .quotient   (div_quotient),
                .busy       (div_busy)
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
                .o_wr_en      (o_buf_write_en),
                .o_wr_data    (o_buf_write_data),
                .buf_sel      (ctrl_buf_sel),
                .lut_rd_en    (1'b0),
                .lut_rd_addr  (8'h0),
                .lut_rd_data  (),
                .m_old        (buf_m_old),
                .l_old        (buf_l_old),
                .m_new        (sm_m_new),
                .l_new        (sm_l_new),
                .correction   (sm_correction)
            );
        
            // =========================================================================
            // Scan chain connections (DFT)
            // Chain 0-1: fa_ctrl, Chain 2-3: fa_dma, Chain 4-5: fa_systolic,
            // Chain 6: fa_softmax + fa_divider, Chain 7: fa_buffer_mgr + fa_regfile
            // =========================================================================
            // For now, loopback scan chains (to be replaced by synthesis tool stitching)
            assign test_so = test_si;
        
        endmodule
        
