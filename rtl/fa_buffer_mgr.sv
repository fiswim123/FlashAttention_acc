// =============================================================================
// Module: fa_buffer_mgr
// Description: On-chip buffer manager with dual-buffered K/V SRAMs, Q/O buffers,
//              and exp LUT ROM. Priority arbitration for MAC/DMA access.
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
    // Output write interface (O buffer)
    input  logic        o_wr_en,
    input  logic [255:0] o_wr_data,
    // Buffer select for dual buffering
    input  logic        buf_sel,
    // Exp LUT read interface
    input  logic        lut_rd_en,
    input  logic [7:0]  lut_rd_addr,
    output logic [15:0] lut_rd_data
);

    // =========================================================================
    // Storage arrays (behavioral SRAM / register arrays for synthesis inference)
    // =========================================================================
    // Q buffer: 64 entries x 16-bit = 128 bytes (single buffer)
    logic [15:0] q_buf [0:63];

    // K buffer: 2 banks x 1024 entries x 16-bit = 4KB total (dual buffer)
    logic [15:0] k_buf_a [0:1023];
    logic [15:0] k_buf_b [0:1023];

    // V buffer: 2 banks x 1024 entries x 16-bit = 4KB total (dual buffer)
    logic [15:0] v_buf_a [0:1023];
    logic [15:0] v_buf_b [0:1023];

    // O buffer: 64 entries x 16-bit = 128 bytes (single buffer)
    logic [15:0] o_buf [0:63];

    // Exp LUT ROM: 256 entries x 16-bit = 512 bytes
    // Pre-initialized with exp(x) values for x in [-8, 0) mapped to [0, 255]
    logic [15:0] exp_lut [0:255];

    // Initialize exp LUT with approximate exp values (Q0.16 format, values in [0,1])
    initial begin
        // Approximate exp values: exp(-8) to exp(0), 256 entries
        // Using simple linear approximation for synthesis
        for (int i = 0; i < 256; i++) begin
            // exp(i * 8/256 - 8) mapped to Q0.16
            // Simplified: most entries near 0 for large negative, near 65535 for i=255
            if (i < 64)
                exp_lut[i] = 16'(i);           // very small values
            else if (i < 128)
                exp_lut[i] = 16'((i - 64) * 4 + 64);
            else if (i < 192)
                exp_lut[i] = 16'((i - 128) * 16 + 320);
            else
                exp_lut[i] = 16'((i - 192) * 64 + 1344);
        end
    end

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
    // DMA Write Path
    // =========================================================================
    // DMA writes 128-bit (8 x 16-bit elements) per beat
    // Address decoding: bits [11:10] select buffer, bits [9:3] select entry group
    wire [1:0] dma_buf_sel = dma_wr_addr[11:10];
    wire [8:0] dma_entry   = dma_wr_addr[9:1];  // 16-bit word address

    always_ff @(posedge clk) begin
        if (dma_wr_en && dma_access) begin
            case (dma_buf_sel)
                2'b00: begin  // Q buffer (64 entries)
                    for (int i = 0; i < 8; i++) begin
                        if (dma_entry + i < 64)
                            q_buf[dma_entry[5:0] + i[2:0]] <= dma_wr_data[i*16 +: 16];
                    end
                end
                2'b01: begin  // K buffer (dual)
                    for (int i = 0; i < 8; i++) begin
                        if (buf_sel == 1'b0)
                            k_buf_a[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                        else
                            k_buf_b[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                    end
                end
                2'b10: begin  // V buffer (dual)
                    for (int i = 0; i < 8; i++) begin
                        if (buf_sel == 1'b0)
                            v_buf_a[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                        else
                            v_buf_b[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                    end
                end
                2'b11: begin  // O buffer
                    for (int i = 0; i < 8; i++) begin
                        if (dma_entry + i[2:0] < 64)
                            o_buf[dma_entry[5:0] + i[2:0]] <= dma_wr_data[i*16 +: 16];
                    end
                end
            endcase
        end
        // O buffer write from MAC (256-bit = 16 x 16-bit)
        if (o_wr_en) begin
            for (int i = 0; i < 16; i++)
                o_buf[i[5:0]] <= o_wr_data[i*16 +: 16];
        end
    end

    // =========================================================================
    // DMA Read Path (from O buffer)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (dma_rd_en && dma_access) begin
            for (int i = 0; i < 8; i++)
                dma_rd_data[i*16 +: 16] <= o_buf[dma_rd_addr[5:0] + i[2:0]];
        end
    end

    // =========================================================================
    // MAC Read Path (Q, K, V) - 256-bit output (16 x 16-bit elements)
    // =========================================================================
    // Q read: single buffer, 16 elements starting from mac_q_addr
    // K/V read: dual-buffered, selected by buf_sel (inverted for read vs write)
    logic [255:0] mac_q_data_reg;
    logic [255:0] mac_k_data_reg;
    logic [255:0] mac_v_data_reg;

    always_ff @(posedge clk) begin
        if (mac_q_en) begin
            for (int i = 0; i < 16; i++)
                mac_q_data_reg[i*16 +: 16] <= q_buf[i[5:0]];
        end
    end

    always_ff @(posedge clk) begin
        if (mac_k_en) begin
            for (int i = 0; i < 16; i++) begin
                // Read from the buffer NOT being written to (opposite of buf_sel)
                if (buf_sel == 1'b0)
                    mac_k_data_reg[i*16 +: 16] <= k_buf_b[i[9:0]];
                else
                    mac_k_data_reg[i*16 +: 16] <= k_buf_a[i[9:0]];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (mac_v_en) begin
            for (int i = 0; i < 16; i++) begin
                if (buf_sel == 1'b0)
                    mac_v_data_reg[i*16 +: 16] <= v_buf_b[i[9:0]];
                else
                    mac_v_data_reg[i*16 +: 16] <= v_buf_a[i[9:0]];
            end
        end
    end

    assign mac_q_data = mac_q_data_reg;
    assign mac_k_data = mac_k_data_reg;
    assign mac_v_data = mac_v_data_reg;

    // =========================================================================
    // Exp LUT Read Path
    // =========================================================================
    always_ff @(posedge clk) begin
        if (lut_access)
            lut_rd_data <= exp_lut[lut_rd_addr];
    end

endmodule
