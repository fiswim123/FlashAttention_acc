//      // verilator_coverage annotation
        // =============================================================================
        // Testbench: fa_regfile (Verilator-compatible)
        // Tests: AXI4-Lite read/write, register map, W1C, self-clearing, write protect,
        //        wstrb byte-lane writes
        // RTL: wstrb byte-lane writes implemented with per-byte if(s_axil_wstrb[n])
        // =============================================================================
        `timescale 1ns/1ps
        
        module tb_fa_regfile;
~012405     logic        clk, rst_n;
~000021     logic [5:0]  s_axil_awaddr;
~000082     logic        s_axil_awvalid, s_axil_awready;
 000020     logic [31:0] s_axil_wdata;
~000010     logic [3:0]  s_axil_wstrb;
 000082     logic        s_axil_wvalid, s_axil_wready;
%000000     logic [1:0]  s_axil_bresp;
 000081     logic        s_axil_bvalid, s_axil_bready;
~000021     logic [5:0]  s_axil_araddr;
~000076     logic        s_axil_arvalid, s_axil_arready;
 000022     logic [31:0] s_axil_rdata;
%000000     logic [1:0]  s_axil_rresp;
 000075     logic        s_axil_rvalid, s_axil_rready;
%000004     logic        hw_busy, hw_done, hw_error;
%000001     logic [31:0] hw_cycle_cnt;
%000002     logic        reg_start, reg_soft_reset, reg_causal_en;
%000009     logic [63:0] reg_q_base, reg_k_base, reg_v_base, reg_o_base;
%000002     logic [31:0] reg_stride;
        
%000001     integer tests_passed = 0, tests_failed = 0, test_id = 0, tc;
        
            fa_regfile dut (.*);
%000001     initial clk = 0;
 012405     always #5 clk = ~clk;
        
 000040     task axil_write(input [5:0] addr, input [31:0] data, input [3:0] strb);
 000040         s_axil_awaddr = addr; s_axil_awvalid = 1; s_axil_wvalid = 0; s_axil_bready = 0;
~002000         for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_awready) begin s_axil_awvalid = 0; tc = 50; end end
 000040         s_axil_wdata = data; s_axil_wstrb = strb; s_axil_wvalid = 1;
~002000         for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_wready) begin s_axil_wvalid = 0; tc = 50; end end
 000040         s_axil_bready = 1;
 000120         for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_bvalid) begin s_axil_bready = 0; tc = 50; end end
 000040         @(posedge clk);
            endtask
        
            // Convenience wrapper with full wstrb
 000034     task axil_write_full(input [5:0] addr, input [31:0] data);
 000034         axil_write(addr, data, 4'hF);
            endtask
        
 000022     logic [31:0] rd_result;
 000037     task axil_read(input [5:0] addr, output [31:0] data);
 000037         s_axil_araddr = addr; s_axil_arvalid = 1; s_axil_rready = 0;
~001850         for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_arready) begin s_axil_arvalid = 0; tc = 50; end end
 000037         s_axil_rready = 1;
 000111         for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_rvalid) begin data = s_axil_rdata; s_axil_rready = 0; tc = 50; end end
 000037         @(posedge clk);
            endtask
        
 000037     task check(input string name, input [31:0] actual, input [31:0] expected);
 000037         test_id++;
~000037         if (actual === expected) begin tests_passed++; $display("[PASS] Test %0d: %s = 0x%08x", test_id, name, actual);
%000000         end else begin tests_failed++; $display("[FAIL] Test %0d: %s = 0x%08x, expected 0x%08x", test_id, name, actual, expected); end
            endtask
        
%000001     initial begin
%000001         $dumpfile("sim_results/tb_fa_regfile.vcd");
%000001         $dumpvars(0, tb_fa_regfile);
%000001         s_axil_awaddr=0; s_axil_awvalid=0; s_axil_wdata=0; s_axil_wstrb=0; s_axil_wvalid=0; s_axil_bready=0;
%000001         s_axil_araddr=0; s_axil_arvalid=0; s_axil_rready=0;
%000001         hw_busy=0; hw_done=0; hw_error=0; hw_cycle_cnt=0;
%000004         rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);
        
                // T1: REV
%000001         axil_read(6'h34, rd_result);
%000001         check("REV register", rd_result, 32'hFA_00_01_00);
        
                // T2-T3: Q_BASE write/read
%000001         axil_write_full(6'h0C, 32'hDEAD_BEEF);
%000001         axil_read(6'h0C, rd_result);
%000001         check("Q_BASE_L write/read", rd_result, 32'hDEAD_BEEF);
%000001         axil_write_full(6'h10, 32'hCAFE_BABE);
%000001         axil_read(6'h10, rd_result);
%000001         check("Q_BASE_H write/read", rd_result, 32'hCAFE_BABE);
        
                // T4: reg_q_base output
%000001         #1;
%000001         check("reg_q_base[31:0]", reg_q_base[31:0], 32'hDEAD_BEEF);
%000001         check("reg_q_base[63:32]", reg_q_base[63:32], 32'hCAFE_BABE);
        
                // T5: All base addresses
%000001         axil_write_full(6'h14, 32'h11111111); axil_write_full(6'h18, 32'h22222222);
%000001         axil_write_full(6'h1C, 32'h33333333); axil_write_full(6'h20, 32'h44444444);
%000001         axil_write_full(6'h24, 32'h55555555); axil_write_full(6'h28, 32'h66666666);
%000001         axil_write_full(6'h2C, 32'h00000100);
%000001         #1;
%000001         check("K_BASE_L", reg_k_base[31:0], 32'h11111111);
%000001         check("K_BASE_H", reg_k_base[63:32], 32'h22222222);
%000001         check("V_BASE_L", reg_v_base[31:0], 32'h33333333);
%000001         check("V_BASE_H", reg_v_base[63:32], 32'h44444444);
%000001         check("O_BASE_L", reg_o_base[31:0], 32'h55555555);
%000001         check("O_BASE_H", reg_o_base[63:32], 32'h66666666);
%000001         check("STRIDE", reg_stride, 32'h00000100);
        
                // T6: START self-clears (pulse behavior)
%000001         axil_write_full(6'h00, 32'h1);
%000003         repeat(3) @(posedge clk);
%000001         #1;
%000001         check("START self-cleared", {31'h0, reg_start}, 32'h0);
        
                // T7: SOFT_RESET self-clears (pulse behavior)
%000001         axil_write_full(6'h00, 32'h2);
%000003         repeat(3) @(posedge clk);
%000001         #1;
%000001         check("SOFT_RESET self-cleared", {31'h0, reg_soft_reset}, 32'h0);
        
                // T8: CAUSAL_EN sticky
%000001         axil_write_full(6'h00, 32'h4);
%000002         repeat(2) @(posedge clk);
%000001         #1;
%000001         check("CAUSAL_EN set", {31'h0, reg_causal_en}, 32'h1);
%000005         repeat(5) @(posedge clk);
%000001         #1;
%000001         check("CAUSAL_EN sticky", {31'h0, reg_causal_en}, 32'h1);
%000001         axil_write_full(6'h00, 32'h0);
%000002         repeat(2) @(posedge clk);
%000001         #1;
%000001         check("CAUSAL_EN cleared", {31'h0, reg_causal_en}, 32'h0);
        
                // T9: hw_busy in STATUS
%000002         hw_busy = 1; repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("STATUS BUSY=1", rd_result[0], 1'b1);
%000002         hw_busy = 0; repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("STATUS BUSY=0", rd_result[0], 1'b0);
        
                // T10: DONE W1C
%000003         hw_done = 1; repeat(3) @(posedge clk); hw_done = 0; repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("DONE set", rd_result[1], 1'b1);
%000001         axil_write_full(6'h04, 32'h2);
%000002         repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("DONE W1C", rd_result[1], 1'b0);
        
                // T11: ERROR W1C
%000003         hw_error = 1; repeat(3) @(posedge clk); hw_error = 0; repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("ERROR set", rd_result[2], 1'b1);
%000001         axil_write_full(6'h04, 32'h4);
%000002         repeat(2) @(posedge clk);
%000001         axil_read(6'h04, rd_result);
%000001         check("ERROR W1C", rd_result[2], 1'b0);
        
                // T12: CYCLES register
%000002         hw_cycle_cnt = 32'h12345678; repeat(2) @(posedge clk);
%000001         axil_read(6'h30, rd_result);
%000001         check("CYCLES", rd_result, 32'h12345678);
        
                // T13: Write protect when BUSY
%000002         hw_busy = 1; repeat(2) @(posedge clk);
%000001         axil_write_full(6'h0C, 32'hFFFFFFFF);
%000001         axil_read(6'h0C, rd_result);
%000001         check("Write protect Q_BASE_L", rd_result, 32'hDEADBEEF);
%000002         hw_busy = 0; repeat(2) @(posedge clk);
        
                // T14: CFG register (reserved - read returns reg_file[2] which is 0)
%000001         axil_read(6'h08, rd_result);
%000001         check("CFG register (reserved, no write path)", rd_result, 32'h0);
        
                // T15: Read all addresses for toggle coverage
~000014         for (int a = 0; a < 14; a++)
 000014             axil_read(6'(a*4), rd_result);
        
                // T16: Verify write-through after BUSY clears
%000001         axil_write_full(6'h0C, 32'hCAFEBABE);
%000001         axil_read(6'h0C, rd_result);
%000001         check("Write after BUSY clear", rd_result, 32'hCAFEBABE);
        
                // T17: Toggle coverage - write all 1s to base addresses
%000001         axil_write_full(6'h0C, 32'hFFFFFFFF);
%000001         axil_write_full(6'h10, 32'hFFFFFFFF);
%000001         axil_write_full(6'h14, 32'hFFFFFFFF);
%000001         axil_write_full(6'h18, 32'hFFFFFFFF);
%000001         axil_write_full(6'h1C, 32'hFFFFFFFF);
%000001         axil_write_full(6'h20, 32'hFFFFFFFF);
%000001         axil_write_full(6'h24, 32'hFFFFFFFF);
%000001         axil_write_full(6'h28, 32'hFFFFFFFF);
%000001         axil_write_full(6'h2C, 32'hFFFFFFFF);
%000001         axil_read(6'h0C, rd_result);
%000001         check("All 1s Q_BASE_L", rd_result, 32'hFFFFFFFF);
%000001         axil_read(6'h2C, rd_result);
%000001         check("All 1s STRIDE", rd_result, 32'hFFFFFFFF);
        
                // T18: Write alternating pattern
%000001         axil_write_full(6'h0C, 32'hAAAAAAAA);
%000001         axil_write_full(6'h10, 32'h55555555);
%000001         axil_read(6'h0C, rd_result);
%000001         check("Alt pattern L", rd_result, 32'hAAAAAAAA);
%000001         axil_read(6'h10, rd_result);
%000001         check("Alt pattern H", rd_result, 32'h55555555);
        
                // T19: wstrb byte-lane write - only low byte
%000001         axil_write_full(6'h0C, 32'hFFFFFFFF);  // Set all bits first
%000001         axil_write(6'h0C, 32'h12345600, 4'h1);  // Only byte 0 (wdata[7:0]=0x00)
%000001         axil_read(6'h0C, rd_result);
                // byte 0 = 0x00 (from wdata), bytes 1-3 = 0xFF (unchanged)
%000001         check("wstrb byte0 only", rd_result, 32'hFFFFFF00);
        
                // T20: wstrb byte-lane write - only high byte (byte 3 = bits [31:24])
%000001         axil_write_full(6'h0C, 32'hAAAAAAAA);  // Reset to known value
%000001         axil_write(6'h0C, 32'hBB000000, 4'h8);  // Only byte 3 (wdata[31:24]=0xBB)
%000001         axil_read(6'h0C, rd_result);
%000001         check("wstrb byte3 only", rd_result, 32'hBBAAAAAA);
        
                // T21: wstrb byte-lane write - bytes 0 and 2
%000001         axil_write_full(6'h0C, 32'h11111111);
%000001         axil_write(6'h0C, 32'h00CC00DD, 4'h5);  // bytes 0 and 2
%000001         axil_read(6'h0C, rd_result);
%000001         check("wstrb byte0+2", rd_result, 32'h11CC11DD);
        
                // T22: wstrb byte-lane write - bytes 1 and 3
%000001         axil_write_full(6'h0C, 32'h22222222);
%000001         axil_write(6'h0C, 32'hEE00FF00, 4'hA);  // bytes 1 and 3
%000001         axil_read(6'h0C, rd_result);
%000001         check("wstrb byte1+3", rd_result, 32'hEE22FF22);
        
                // T23: wstrb=0 (no write)
%000001         axil_write_full(6'h0C, 32'hDEADBEEF);
%000001         axil_write(6'h0C, 32'h00000000, 4'h0);  // No bytes written
%000001         axil_read(6'h0C, rd_result);
%000001         check("wstrb=0 no write", rd_result, 32'hDEADBEEF);
        
                // T24: wstrb on STRIDE register
%000001         axil_write_full(6'h2C, 32'h11223344);
%000001         axil_write(6'h2C, 32'h00000000, 4'h3);  // Only bytes 0-1
%000001         axil_read(6'h2C, rd_result);
%000001         check("wstrb STRIDE low16", rd_result, 32'h11220000);
        
%000001         $display("========================================");
%000001         $display("  fa_regfile: %0d passed, %0d failed", tests_passed, tests_failed);
%000001         $display("========================================");
%000001         $display(tests_failed > 0 ? "RESULT: FAIL" : "RESULT: PASS");
%000001         $finish;
            end
        
%000000     initial begin #200000; $display("[TIMEOUT]"); $finish; end
        endmodule
        
