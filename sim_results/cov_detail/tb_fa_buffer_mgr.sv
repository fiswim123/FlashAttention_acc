//      // verilator_coverage annotation
        // =============================================================================
        // Testbench: fa_buffer_mgr (Verilator-compatible)
        // Tests: DMA write/read, MAC Q/K/V read, dual buffering, arbitration, LUT
        // =============================================================================
        `timescale 1ns/1ps
        
        module tb_fa_buffer_mgr;
~000145     logic clk, rst_n;
~000014     logic dma_wr_en; logic [11:0] dma_wr_addr; logic [127:0] dma_wr_data;
%000002     logic dma_rd_en; logic [11:0] dma_rd_addr; logic [127:0] dma_rd_data;
%000004     logic mac_q_en; logic [255:0] mac_q_data;
%000006     logic mac_k_en; logic [255:0] mac_k_data;
%000004     logic mac_v_en; logic [255:0] mac_v_data;
%000002     logic o_wr_en; logic [255:0] o_wr_data;
%000006     logic buf_sel;
~000010     logic lut_rd_en; logic [7:0] lut_rd_addr; logic [15:0] lut_rd_data;
%000002     logic [39:0] m_old, l_old;
%000000     logic [39:0] m_new, l_new;
%000000     logic [15:0] correction;
        
%000001     integer tp=0, tf=0, tid=0;
        
            fa_buffer_mgr dut (.*);
%000001     initial clk = 0;
 000145     always #5 clk = ~clk;
        
 000016     task check16(input string n, input [15:0] a, input [15:0] e);
 000016         tid++;
~000016         if (a===e) begin tp++; $display("[PASS] Test %0d: %s = 0x%04x", tid, n, a);
%000000         end else begin tf++; $display("[FAIL] Test %0d: %s = 0x%04x, exp 0x%04x", tid, n, a, e); end
            endtask
        
%000006     task dma_write(input [11:0] addr, input [127:0] data);
%000006         @(posedge clk); dma_wr_en=1; dma_wr_addr=addr; dma_wr_data=data;
%000006         @(posedge clk); dma_wr_en=0;
            endtask
        
%000001     task mac_read_q;
%000001         @(posedge clk); mac_q_en=1; @(posedge clk); mac_q_en=0; @(posedge clk);
            endtask
%000003     task mac_read_k;
%000003         @(posedge clk); mac_k_en=1; @(posedge clk); mac_k_en=0; @(posedge clk);
            endtask
%000002     task mac_read_v;
%000002         @(posedge clk); mac_v_en=1; @(posedge clk); mac_v_en=0; @(posedge clk);
            endtask
        
%000001     initial begin
%000001         $dumpfile("sim_results/tb_fa_buffer_mgr.vcd");
%000001         $dumpvars(0, tb_fa_buffer_mgr);
%000001         dma_wr_en=0; dma_wr_addr=0; dma_wr_data=0; dma_rd_en=0; dma_rd_addr=0;
%000001         mac_q_en=0; mac_k_en=0; mac_v_en=0; o_wr_en=0; o_wr_data=0;
%000001         buf_sel=0; lut_rd_en=0; lut_rd_addr=0;
%000001         m_new=0; l_new=0; correction=0;
%000004         rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);
        
                // T1: DMA write to Q buffer (addr[11:10]=00)
%000001         dma_write(12'h000, 128'h0001_0002_0003_0004_0005_0006_0007_0008);
%000002         repeat(2) @(posedge clk);
        
                // T2: MAC Q read
%000001         mac_read_q();
%000001         check16("Q elem 0", mac_q_data[15:0], 16'h0008);
%000001         check16("Q elem 1", mac_q_data[31:16], 16'h0007);
%000001         check16("Q elem 7", mac_q_data[127:112], 16'h0001);
        
                // T3: DMA write to K buffer (addr[11:10]=01), buf_sel=0 -> k_buf_a
%000001         buf_sel = 0;
%000001         dma_write(12'h400, 128'h0010_0020_0030_0040_0050_0060_0070_0080);
%000002         repeat(2) @(posedge clk);
        
                // T4: MAC K read with buf_sel=0 -> reads from k_buf_b (opposite, empty)
%000001         buf_sel = 0;
%000001         mac_read_k();
%000001         check16("K buf_b elem 0 (empty)", mac_k_data[15:0], 16'h0000);
        
                // T5: MAC K read with buf_sel=1 -> reads from k_buf_a
%000001         buf_sel = 1;
%000001         mac_read_k();
%000001         check16("K buf_a elem 0", mac_k_data[15:0], 16'h0080);
%000001         check16("K buf_a elem 7", mac_k_data[127:112], 16'h0010);
        
                // T6: DMA write to V buffer (addr[11:10]=10), buf_sel=0 -> v_buf_a
%000001         buf_sel = 0;
%000001         dma_write(12'h800, 128'h0100_0200_0300_0400_0500_0600_0700_0800);
%000002         repeat(2) @(posedge clk);
        
                // T7: MAC V read with buf_sel=1 -> reads from v_buf_a
%000001         buf_sel = 1;
%000001         mac_read_v();
%000001         check16("V buf_a elem 0", mac_v_data[15:0], 16'h0800);
        
                // T8: O buffer write
%000001         @(posedge clk);
%000001         o_wr_en=1;
%000001         o_wr_data=256'h0001_0002_0003_0004_0005_0006_0007_0008_0009_000A_000B_000C_000D_000E_000F_0010;
%000001         @(posedge clk); o_wr_en=0;
%000002         repeat(2) @(posedge clk);
        
                // T9: DMA read from O buffer
%000001         @(posedge clk); dma_rd_en=1; dma_rd_addr=12'hC00;
%000001         @(posedge clk); dma_rd_en=0; @(posedge clk);
%000001         check16("O DMA read elem 0", dma_rd_data[15:0], 16'h0010);
        
                // T10: MAC priority over DMA
%000001         @(posedge clk); dma_wr_en=1; dma_wr_addr=12'h000;
%000001         dma_wr_data=128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
%000001         mac_q_en=1;
%000001         @(posedge clk); mac_q_en=0; dma_wr_en=0;
%000001         @(posedge clk);
                // Q data should be from the first write (MAC priority blocked DMA)
%000001         check16("MAC priority Q elem 0", mac_q_data[15:0], 16'h0008);
        
                // T11: LUT read (no MAC/DMA active)
%000001         mac_q_en=0; mac_k_en=0; mac_v_en=0; dma_wr_en=0; dma_rd_en=0;
%000001         @(posedge clk); lut_rd_en=1; lut_rd_addr=8'd255;
%000001         @(posedge clk); lut_rd_en=0; @(posedge clk);
%000001         check16("LUT addr 255", lut_rd_data, 16'h1500);
        
                // T12: LUT addr 0
%000001         @(posedge clk); lut_rd_en=1; lut_rd_addr=8'd0;
%000001         @(posedge clk); lut_rd_en=0; @(posedge clk);
%000001         check16("LUT addr 0", lut_rd_data, 16'h0000);
        
                // T13: LUT addr 64
%000001         @(posedge clk); lut_rd_en=1; lut_rd_addr=8'd64;
%000001         @(posedge clk); lut_rd_en=0; @(posedge clk);
%000001         check16("LUT addr 64", lut_rd_data, 16'h0040);
        
                // T14: LUT addr 128
%000001         @(posedge clk); lut_rd_en=1; lut_rd_addr=8'd128;
%000001         @(posedge clk); lut_rd_en=0; @(posedge clk);
%000001         check16("LUT addr 128", lut_rd_data, 16'h0140);
        
                // T15: LUT addr 192
%000001         @(posedge clk); lut_rd_en=1; lut_rd_addr=8'd192;
%000001         @(posedge clk); lut_rd_en=0; @(posedge clk);
%000001         check16("LUT addr 192", lut_rd_data, 16'h0540);
        
                // T16: V buffer write with buf_sel=1 (v_buf_b)
%000001         buf_sel = 1;
%000001         dma_write(12'h800, 128'h1000_2000_3000_4000_5000_6000_7000_8000);
%000002         repeat(2) @(posedge clk);
                // MAC V read with buf_sel=0 -> reads from v_buf_b
%000001         buf_sel = 0;
%000001         mac_read_v();
%000001         check16("V buf_b elem 0", mac_v_data[15:0], 16'h8000);
        
                // T17: K buffer write with buf_sel=1 (k_buf_b)
%000001         buf_sel = 1;
%000001         dma_write(12'h400, 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_1111_2222);
%000002         repeat(2) @(posedge clk);
                // MAC K read with buf_sel=0 -> reads from k_buf_b
%000001         buf_sel = 0;
%000001         mac_read_k();
%000001         check16("K buf_b elem 0", mac_k_data[15:0], 16'h2222);
        
                // T18: DMA write to O buffer
%000001         dma_write(12'hC00, 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_1111_2222);
%000002         repeat(2) @(posedge clk);
        
%000001         $display("========================================");
%000001         $display("  fa_buffer_mgr: %0d passed, %0d failed", tp, tf);
%000001         $display("========================================");
%000001         $display(tf > 0 ? "RESULT: FAIL" : "RESULT: PASS");
%000001         $finish;
            end
        
%000000     initial begin #50000; $display("[TIMEOUT]"); $finish; end
        endmodule
        
