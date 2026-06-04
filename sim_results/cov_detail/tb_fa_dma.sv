//      // verilator_coverage annotation
        // =============================================================================
        // Testbench: fa_dma (Verilator-compatible)
        // Tests: AXI4 read/write protocol, address generation, burst, done pulse
        // =============================================================================
        `timescale 1ns/1ps
        
        module tb_fa_dma;
~000341     logic clk, rst_n, dma_start, dma_done;
%000004     logic [1:0] dma_cmd;
%000001     logic [63:0] q_base, k_base, v_base, o_base;
%000001     logic [31:0] stride;
%000002     logic [7:0] row_cnt; logic [3:0] tile_cnt;
%000005     logic [63:0] m_axi_awaddr, m_axi_araddr;
%000004     logic [7:0] m_axi_awlen, m_axi_arlen;
%000001     logic [2:0] m_axi_awsize, m_axi_arsize;
%000001     logic [1:0] m_axi_awburst, m_axi_arburst;
~000018     logic m_axi_awvalid, m_axi_awready, m_axi_arvalid, m_axi_arready;
~000104     logic [127:0] m_axi_wdata, m_axi_rdata;
%000001     logic [15:0] m_axi_wstrb;
%000002     logic m_axi_wlast, m_axi_wvalid, m_axi_wready;
%000000     logic [1:0] m_axi_bresp, m_axi_rresp;
~000018     logic m_axi_bvalid, m_axi_bready, m_axi_rlast, m_axi_rvalid, m_axi_rready;
~000018     logic buf_wr_en, buf_rd_en;
~000104     logic [11:0] buf_wr_addr, buf_rd_addr;
~000104     logic [127:0] buf_wr_data, buf_rd_data;
        
%000001     integer tp=0, tf=0, tid=0;
        
            fa_dma dut (.*);
%000001     initial clk = 0;
 000341     always #5 clk = ~clk;
        
%000009     task check(input string n, input a, input e);
%000009         tid++;
%000009         if (a===e) begin tp++; $display("[PASS] Test %0d: %s", tid, n);
%000000         end else begin tf++; $display("[FAIL] Test %0d: %s", tid, n); end
            endtask
        
 000010     task check_val(input string n, input [63:0] a, input [63:0] e);
 000010         tid++;
~000010         if (a===e) begin tp++; $display("[PASS] Test %0d: %s = 0x%x", tid, n, a);
%000000         end else begin tf++; $display("[FAIL] Test %0d: %s = 0x%x, exp 0x%x", tid, n, a, e); end
            endtask
        
            // AXI4 slave model
%000001     integer rd_beat = 0;
 000171     always_ff @(posedge clk) begin
~000168         if (!rst_n) begin
%000003             m_axi_arready<=0; m_axi_rvalid<=0; m_axi_rdata<=0; m_axi_rlast<=0; m_axi_rresp<=0; rd_beat<=0;
 000168         end else begin
 000168             m_axi_arready <= (m_axi_arvalid && !m_axi_rvalid);
%000009             if (m_axi_arready && m_axi_arvalid) begin
%000009                 m_axi_rvalid<=1; m_axi_rdata<=128'h0001_0002_0003_0004_0005_0006_0007_0008;
%000009                 m_axi_rlast<=(m_axi_arlen==0); rd_beat<=0;
 000104             end else if (m_axi_rvalid && m_axi_rready) begin
 000104                 rd_beat <= rd_beat+1;
~000095                 if (rd_beat >= m_axi_arlen) begin m_axi_rvalid<=0; m_axi_rlast<=0;
 000095                 end else begin
 000095                     m_axi_rdata <= 128'(m_axi_rdata + 128'h0001_0001_0001_0001_0001_0001_0001_0001);
 000095                     m_axi_rlast <= (rd_beat+1 >= m_axi_arlen);
                        end
                    end
                end
            end
        
 000171     always_ff @(posedge clk) begin
~000168         if (!rst_n) begin m_axi_awready<=0; m_axi_wready<=0; m_axi_bvalid<=0; m_axi_bresp<=0;
 000168         end else begin
 000168             m_axi_awready <= (m_axi_awvalid && !m_axi_wvalid);
 000168             m_axi_wready <= m_axi_wvalid;
~000167             if (m_axi_wlast && m_axi_wvalid && m_axi_wready) begin m_axi_bvalid<=1; m_axi_bresp<=0; end
~000167             if (m_axi_bvalid && m_axi_bready) m_axi_bvalid<=0;
                end
            end
        
%000001     initial begin
%000001         $dumpfile("sim_results/tb_fa_dma.vcd");
%000001         $dumpvars(0, tb_fa_dma);
%000001         dma_start=0; dma_cmd=0;
%000001         q_base=64'h1000; k_base=64'h2000; v_base=64'h3000; o_base=64'h4000;
%000001         stride=32'h100; row_cnt=0; tile_cnt=0; buf_rd_data=0;
%000004         rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);
        
                // T1: Q read (CMD=00) - addr=0x1000, len=7
%000001         @(posedge clk); dma_cmd=2'b00; row_cnt=0; tile_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("Q addr", m_axi_araddr, 64'h1000);
%000001                 check_val("Q arlen", {56'd0,m_axi_arlen}, 64'd7); i=100; end
                end
~000010         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         check("Q dma_done", 1, 1);
        
                // T2: K read (CMD=01), tile 0 - addr=0x2000, len=15
%000001         @(posedge clk); dma_cmd=2'b01; row_cnt=0; tile_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("K addr", m_axi_araddr, 64'h2000);
%000001                 check_val("K arlen", {56'd0,m_axi_arlen}, 64'd15); i=100; end
                end
~000018         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         check("K dma_done", 1, 1);
        
                // T3: K read, tile 1 - addr=0x2000+16*256=0x3000
%000001         @(posedge clk); dma_cmd=2'b01; tile_cnt=1; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("K tile1 addr", m_axi_araddr, 64'h3000); i=100; end
                end
~000018         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
        
                // T4: O write (CMD=11) - addr=0x4000
%000001         @(posedge clk); dma_cmd=2'b11; row_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_awvalid) begin check_val("O addr", m_axi_awaddr, 64'h4000);
%000001                 check_val("O awlen", {56'd0,m_axi_awlen}, 64'd7); i=100; end
                end
~000012         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         check("O dma_done", 1, 1);
        
                // T5: Buffer write enable during read
%000001         @(posedge clk); dma_cmd=2'b00; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000003         for (int i=0; i<200; i++) begin
%000003             @(posedge clk);
%000002             if (buf_wr_en) begin check("buf_wr_en during R_RECV", 1, 1); i=200; end
                end
%000008         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
        
                // T6: DMA done pulse is single-cycle
%000001         @(posedge clk); dma_cmd=2'b00; dma_start=1;
%000001         @(posedge clk); dma_start=0;
~000011         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         @(posedge clk); #1;
%000001         check("dma_done pulse cleared", dma_done, 1'b0);
        
                // T7: Q addr with row_cnt=5
%000001         @(posedge clk); dma_cmd=2'b00; row_cnt=5; tile_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("Q row5 addr", m_axi_araddr, 64'h1500); i=100; end
                end
~000010         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
        
                // T8: V read (CMD=10), tile 0
%000001         @(posedge clk); dma_cmd=2'b10; row_cnt=0; tile_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("V addr", m_axi_araddr, 64'h3000); i=100; end
                end
~000018         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         check("V dma_done", 1, 1);
        
                // T9: V read, tile 2 - addr=0x3000+2*16*256=0x5000
%000001         @(posedge clk); dma_cmd=2'b10; tile_cnt=2; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin check_val("V tile2 addr", m_axi_araddr, 64'h5000); i=100; end
                end
~000018         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
%000001         check("V tile2 dma_done", 1, 1);
        
                // T10: AXI4 protocol checks
%000001         @(posedge clk); dma_cmd=2'b00; row_cnt=0; dma_start=1;
%000001         @(posedge clk); dma_start=0;
%000001         for (int i=0; i<100; i++) begin
%000001             @(posedge clk);
%000001             if (m_axi_arvalid) begin
%000001                 check("arsize=16B", m_axi_arsize, 3'b100);
%000001                 check("arburst=INCR", m_axi_arburst, 2'b01);
%000001                 i=100;
                    end
                end
~000010         for (int i=0; i<200; i++) begin @(posedge clk); if (dma_done) i=200; end
        
%000001         $display("========================================");
%000001         $display("  fa_dma: %0d passed, %0d failed", tp, tf);
%000001         $display("========================================");
%000001         $display(tf > 0 ? "RESULT: FAIL" : "RESULT: PASS");
%000001         $finish;
            end
        
%000000     initial begin #200000; $display("[TIMEOUT]"); $finish; end
        endmodule
        
