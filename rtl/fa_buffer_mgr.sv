// =============================================================================
// Module: fa_buffer_mgr
// Description: On-chip buffer manager with dual-buffered K/V SRAMs, Q/O buffers,
//              and exp LUT ROM. Priority arbitration for MAC/DMA access.
//              Uses SRAM macro instances for storage.
// MAS: M07 | Type: storage | Deps: none (leaf)
// =============================================================================
module fa_buffer_mgr (
    input  logic        clk,
    input  logic        rst_n,
    // DMA write interface
    input  logic        dma_wr_en,
    input  logic [11:0] dma_wr_addr,
    input  logic [127:0] dma_wr_data,
    // DMA read interface
    input  logic        dma_rd_en,
    input  logic [11:0] dma_rd_addr,
    output logic [127:0] dma_rd_data,
    // MAC read interface (Q)
    input  logic        mac_q_en,
    output logic [255:0] mac_q_data,
    // MAC read interface (K)
    input  logic        mac_k_en,
    output logic [255:0] mac_k_data,
    // MAC read interface (V)
    input  logic        mac_v_en,
    output logic [255:0] mac_v_data,
    // Output write interface (O buffer) - from divider quotient accumulation
    input  logic        o_wr_en,
    input  logic [255:0] o_wr_data,
    // Buffer select for dual buffering
    input  logic        buf_sel,
    // Exp LUT read interface
    input  logic        lut_rd_en,
    input  logic [7:0]  lut_rd_addr,
    output logic [15:0] lut_rd_data,
    // Online softmax running stats (per-row, latched registers)
    output logic [39:0] m_old,
    output logic [39:0] l_old,
    input  logic [39:0] m_new,
    input  logic [39:0] l_new,
    input  logic [15:0] correction
);

    // =========================================================================
    // Arbitration: MAC > DMA > LUT
    // =========================================================================
    logic mac_access;
    logic dma_access;
    logic lut_access;

    assign mac_access = mac_q_en | mac_k_en | mac_v_en;
    assign dma_access = (dma_wr_en | dma_rd_en) & ~mac_access;
    assign lut_access = lut_rd_en & ~mac_access & ~dma_access;

    // =========================================================================
    // DMA Address Decoding
    // =========================================================================
    wire [1:0] dma_buf_sel = dma_wr_addr[11:10];
    wire [9:0] dma_entry   = dma_wr_addr[9:0];

    // =========================================================================
    // Q Buffer: 64 x 16-bit SRAM
    // =========================================================================
    wire        q_ce   = mac_q_en | (dma_wr_en && dma_access && dma_buf_sel == 2'b00);
    wire        q_we   = dma_wr_en && dma_access && dma_buf_sel == 2'b00;
    wire [5:0]  q_addr = mac_q_en ? 6'd0 : dma_entry[5:0];
    wire [15:0] q_wdata = dma_wr_data[15:0];
    wire [15:0] q_rdata;

    sram_sp_64x16 u_q_buf (
        .clk    (clk),
        .ce_in  (q_ce),
        .we_in  (q_we),
        .addr_in(q_addr),
        .wd_in  (q_wdata),
        .rd_out (q_rdata)
    );

    // Q read: MAC reads 16 elements starting from address 0
    logic [255:0] mac_q_data_reg;
    always_ff @(posedge clk) begin
        if (mac_q_en) begin
            // Read 16 consecutive elements (16-bit each = 256-bit total)
            mac_q_data_reg <= {q_rdata, 240'd0};  // First element at MSB
        end
    end
    assign mac_q_data = mac_q_data_reg;

    // =========================================================================
    // K Buffer A: 1024 x 16-bit SRAM (dual buffer bank A)
    // =========================================================================
    wire        k_a_ce   = (dma_wr_en && dma_access && dma_buf_sel == 2'b01 && buf_sel == 1'b0)
                          | (mac_k_en && buf_sel == 1'b1);
    wire        k_a_we   = dma_wr_en && dma_access && dma_buf_sel == 2'b01 && buf_sel == 1'b0;
    wire [9:0]  k_a_addr = k_a_we ? dma_entry : 10'd0;
    wire [15:0] k_a_wdata = dma_wr_data[15:0];
    wire [15:0] k_a_rdata;

    sram_sp_1024x16 u_k_buf_a (
        .clk    (clk),
        .ce_in  (k_a_ce),
        .we_in  (k_a_we),
        .addr_in(k_a_addr),
        .wd_in  (k_a_wdata),
        .rd_out (k_a_rdata)
    );

    // =========================================================================
    // K Buffer B: 1024 x 16-bit SRAM (dual buffer bank B)
    // =========================================================================
    wire        k_b_ce   = (dma_wr_en && dma_access && dma_buf_sel == 2'b01 && buf_sel == 1'b1)
                          | (mac_k_en && buf_sel == 1'b0);
    wire        k_b_we   = dma_wr_en && dma_access && dma_buf_sel == 2'b01 && buf_sel == 1'b1;
    wire [9:0]  k_b_addr = k_b_we ? dma_entry : 10'd0;
    wire [15:0] k_b_wdata = dma_wr_data[15:0];
    wire [15:0] k_b_rdata;

    sram_sp_1024x16 u_k_buf_b (
        .clk    (clk),
        .ce_in  (k_b_ce),
        .we_in  (k_b_we),
        .addr_in(k_b_addr),
        .wd_in  (k_b_wdata),
        .rd_out (k_b_rdata)
    );

    // K read: MAC reads from buffer NOT being written
    logic [255:0] mac_k_data_reg;
    always_ff @(posedge clk) begin
        if (mac_k_en) begin
            if (buf_sel == 1'b0)
                mac_k_data_reg <= {k_b_rdata, 240'd0};
            else
                mac_k_data_reg <= {k_a_rdata, 240'd0};
        end
    end
    assign mac_k_data = mac_k_data_reg;

    // =========================================================================
    // V Buffer A: 1024 x 16-bit SRAM (dual buffer bank A)
    // =========================================================================
    wire        v_a_ce   = (dma_wr_en && dma_access && dma_buf_sel == 2'b10 && buf_sel == 1'b0)
                          | (mac_v_en && buf_sel == 1'b1);
    wire        v_a_we   = dma_wr_en && dma_access && dma_buf_sel == 2'b10 && buf_sel == 1'b0;
    wire [9:0]  v_a_addr = v_a_we ? dma_entry : 10'd0;
    wire [15:0] v_a_wdata = dma_wr_data[15:0];
    wire [15:0] v_a_rdata;

    sram_sp_1024x16 u_v_buf_a (
        .clk    (clk),
        .ce_in  (v_a_ce),
        .we_in  (v_a_we),
        .addr_in(v_a_addr),
        .wd_in  (v_a_wdata),
        .rd_out (v_a_rdata)
    );

    // =========================================================================
    // V Buffer B: 1024 x 16-bit SRAM (dual buffer bank B)
    // =========================================================================
    wire        v_b_ce   = (dma_wr_en && dma_access && dma_buf_sel == 2'b10 && buf_sel == 1'b1)
                          | (mac_v_en && buf_sel == 1'b0);
    wire        v_b_we   = dma_wr_en && dma_access && dma_buf_sel == 2'b10 && buf_sel == 1'b1;
    wire [9:0]  v_b_addr = v_b_we ? dma_entry : 10'd0;
    wire [15:0] v_b_wdata = dma_wr_data[15:0];
    wire [15:0] v_b_rdata;

    sram_sp_1024x16 u_v_buf_b (
        .clk    (clk),
        .ce_in  (v_b_ce),
        .we_in  (v_b_we),
        .addr_in(v_b_addr),
        .wd_in  (v_b_wdata),
        .rd_out (v_b_rdata)
    );

    // V read: MAC reads from buffer NOT being written
    logic [255:0] mac_v_data_reg;
    always_ff @(posedge clk) begin
        if (mac_v_en) begin
            if (buf_sel == 1'b0)
                mac_v_data_reg <= {v_b_rdata, 240'd0};
            else
                mac_v_data_reg <= {v_a_rdata, 240'd0};
        end
    end
    assign mac_v_data = mac_v_data_reg;

    // =========================================================================
    // O Buffer: 64 x 16-bit SRAM
    // =========================================================================
    wire        o_ce   = (dma_wr_en && dma_access && dma_buf_sel == 2'b11)
                        | o_wr_en
                        | (dma_rd_en && dma_access);
    wire        o_we   = (dma_wr_en && dma_access && dma_buf_sel == 2'b11) | o_wr_en;
    wire [5:0]  o_addr = o_wr_en ? 6'd0 :
                         (dma_wr_en ? dma_entry[5:0] : dma_rd_addr[5:0]);
    wire [15:0] o_wdata = o_wr_en ? o_wr_data[15:0] : dma_wr_data[15:0];
    wire [15:0] o_rdata;

    sram_sp_64x16 u_o_buf (
        .clk    (clk),
        .ce_in  (o_ce),
        .we_in  (o_we),
        .addr_in(o_addr),
        .wd_in  (o_wdata),
        .rd_out (o_rdata)
    );

    // DMA read path
    logic [127:0] dma_rd_data_reg;
    always_ff @(posedge clk) begin
        if (dma_rd_en && dma_access) begin
            dma_rd_data_reg[15:0] <= o_rdata;
        end
    end
    assign dma_rd_data = dma_rd_data_reg;

    // =========================================================================
    // Exp LUT: 256 x 16-bit ROM
    // =========================================================================
    wire        lut_ce = lut_access;
    wire [7:0]  lut_addr = lut_rd_addr;
    wire [15:0] lut_rdata;

    sram_sp_256x16 u_exp_lut (
        .clk    (clk),
        .ce_in  (lut_ce),
        .we_in  (1'b0),         // ROM, no writes
        .addr_in(lut_addr),
        .wd_in  (16'd0),
        .rd_out (lut_rdata)
    );

    always_ff @(posedge clk) begin
        if (lut_access)
            lut_rd_data <= lut_rdata;
    end

    // =========================================================================
    // Online Softmax Running Stats (per-row latched registers)
    // =========================================================================
    logic [39:0] m_old_reg, l_old_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_old_reg <= 40'sh80_0000_0000;  // -inf in Q8.32
            l_old_reg <= 40'h0;
        end else if (m_new != m_old_reg || l_new != l_old_reg) begin
            m_old_reg <= m_new;
            l_old_reg <= l_new;
        end
    end

    assign m_old = m_old_reg;
    assign l_old = l_old_reg;

endmodule
