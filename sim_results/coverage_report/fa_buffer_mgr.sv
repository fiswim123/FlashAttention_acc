//      // verilator_coverage annotation
        // =============================================================================
        // Module: fa_buffer_mgr
        // Description: On-chip buffer manager with dual-buffered K/V SRAMs, Q/O buffers,
        //              and exp LUT ROM. Priority arbitration for MAC/DMA access.
        // MAS: M07 | Type: storage | Deps: none (leaf)
        // =============================================================================
        module fa_buffer_mgr (
 009235     input  logic        clk,
%000007     input  logic        rst_n,
            // DMA write interface
 000012     input  logic        dma_wr_en,
~000072     input  logic [11:0] dma_wr_addr,
~000072     input  logic [127:0] dma_wr_data,
            // DMA read interface
%000000     input  logic        dma_rd_en,
%000000     input  logic [11:0] dma_rd_addr,
%000000     output logic [127:0] dma_rd_data,
            // MAC read interface (Q)
 000012     input  logic        mac_q_en,
%000002     output logic [255:0] mac_q_data,
            // MAC read interface (K)
 000012     input  logic        mac_k_en,
%000000     output logic [255:0] mac_k_data,
            // MAC read interface (V)
%000000     input  logic        mac_v_en,
%000000     output logic [255:0] mac_v_data,
            // Output write interface (O buffer)
%000000     input  logic        o_wr_en,
%000000     input  logic [255:0] o_wr_data,
            // Buffer select for dual buffering
%000006     input  logic        buf_sel,
            // Exp LUT read interface
%000000     input  logic        lut_rd_en,
%000000     input  logic [7:0]  lut_rd_addr,
%000000     output logic [15:0] lut_rd_data
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
%000001     initial begin
                // Approximate exp values: exp(-8) to exp(0), 256 entries
                // Using simple linear approximation for synthesis
~000256         for (int i = 0; i < 256; i++) begin
                    // exp(i * 8/256 - 8) mapped to Q0.16
                    // Simplified: most entries near 0 for large negative, near 65535 for i=255
 000064             if (i < 64)
 000064                 exp_lut[i] = 16'(i);           // very small values
 000064             else if (i < 128)
 000064                 exp_lut[i] = 16'((i - 64) * 4 + 64);
 000064             else if (i < 192)
 000064                 exp_lut[i] = 16'((i - 128) * 16 + 320);
                    else
 000064                 exp_lut[i] = 16'((i - 192) * 64 + 1344);
                end
            end
        
            // =========================================================================
            // Arbitration: MAC > DMA > LUT
            // =========================================================================
 000012     logic mac_access;
 000012     logic dma_access;
%000000     logic lut_access;
        
            assign mac_access = mac_q_en | mac_k_en | mac_v_en;
            assign dma_access = (dma_wr_en | dma_rd_en) & ~mac_access;
            assign lut_access = lut_rd_en & ~mac_access & ~dma_access;
        
            // =========================================================================
            // DMA Write Path
            // =========================================================================
            // DMA writes 128-bit (8 x 16-bit elements) per beat
            // Address decoding: bits [11:10] select buffer, bits [9:3] select entry group
%000000     wire [1:0] dma_buf_sel = dma_wr_addr[11:10];
~000036     wire [8:0] dma_entry   = dma_wr_addr[9:1];  // 16-bit word address
        
 004618     always_ff @(posedge clk) begin
 004546         if (dma_wr_en && dma_access) begin
 000072             case (dma_buf_sel)
 000072                 2'b00: begin  // Q buffer (64 entries)
 000576                     for (int i = 0; i < 8; i++) begin
~000576                         if (dma_entry + i < 64)
 000576                             q_buf[dma_entry[5:0] + i[2:0]] <= dma_wr_data[i*16 +: 16];
                            end
                        end
%000000                 2'b01: begin  // K buffer (dual)
%000000                     for (int i = 0; i < 8; i++) begin
%000000                         if (buf_sel == 1'b0)
%000000                             k_buf_a[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                                else
%000000                             k_buf_b[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                            end
                        end
%000000                 2'b10: begin  // V buffer (dual)
%000000                     for (int i = 0; i < 8; i++) begin
%000000                         if (buf_sel == 1'b0)
%000000                             v_buf_a[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                                else
%000000                             v_buf_b[dma_entry + i[2:0]] <= dma_wr_data[i*16 +: 16];
                            end
                        end
%000000                 2'b11: begin  // O buffer
%000000                     for (int i = 0; i < 8; i++) begin
%000000                         if (dma_entry + i[2:0] < 64)
%000000                             o_buf[dma_entry[5:0] + i[2:0]] <= dma_wr_data[i*16 +: 16];
                            end
                        end
                    endcase
                end
                // O buffer write from MAC (256-bit = 16 x 16-bit)
~004618         if (o_wr_en) begin
%000000             for (int i = 0; i < 16; i++)
%000000                 o_buf[i[5:0]] <= o_wr_data[i*16 +: 16];
                end
            end
        
            // =========================================================================
            // DMA Read Path (from O buffer)
            // =========================================================================
 004618     always_ff @(posedge clk) begin
~004618         if (dma_rd_en && dma_access) begin
%000000             for (int i = 0; i < 8; i++)
%000000                 dma_rd_data[i*16 +: 16] <= o_buf[dma_rd_addr[5:0] + i[2:0]];
                end
            end
        
            // =========================================================================
            // MAC Read Path (Q, K, V) - 256-bit output (16 x 16-bit elements)
            // =========================================================================
            // Q read: single buffer, 16 elements starting from mac_q_addr
            // K/V read: dual-buffered, selected by buf_sel (inverted for read vs write)
%000002     logic [255:0] mac_q_data_reg;
%000000     logic [255:0] mac_k_data_reg;
%000000     logic [255:0] mac_v_data_reg;
        
 004618     always_ff @(posedge clk) begin
~004612         if (mac_q_en) begin
~000096             for (int i = 0; i < 16; i++)
 000096                 mac_q_data_reg[i*16 +: 16] <= q_buf[i[5:0]];
                end
            end
        
 004618     always_ff @(posedge clk) begin
~004612         if (mac_k_en) begin
~000096             for (int i = 0; i < 16; i++) begin
                        // Read from the buffer NOT being written to (opposite of buf_sel)
~000096                 if (buf_sel == 1'b0)
 000096                     mac_k_data_reg[i*16 +: 16] <= k_buf_b[i[9:0]];
                        else
%000000                     mac_k_data_reg[i*16 +: 16] <= k_buf_a[i[9:0]];
                    end
                end
            end
        
 004618     always_ff @(posedge clk) begin
~004618         if (mac_v_en) begin
%000000             for (int i = 0; i < 16; i++) begin
%000000                 if (buf_sel == 1'b0)
%000000                     mac_v_data_reg[i*16 +: 16] <= v_buf_b[i[9:0]];
                        else
%000000                     mac_v_data_reg[i*16 +: 16] <= v_buf_a[i[9:0]];
                    end
                end
            end
        
            assign mac_q_data = mac_q_data_reg;
            assign mac_k_data = mac_k_data_reg;
            assign mac_v_data = mac_v_data_reg;
        
            // =========================================================================
            // Exp LUT Read Path
            // =========================================================================
 004618     always_ff @(posedge clk) begin
~004618         if (lut_access)
%000000             lut_rd_data <= exp_lut[lut_rd_addr];
            end
        
        endmodule
        
