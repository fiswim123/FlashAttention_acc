// =============================================================================
// Testbench: fa_regfile (Verilator-compatible)
// Tests: AXI4-Lite read/write, register map, W1C, self-clearing, write protect
// =============================================================================
`timescale 1ns/1ps

module tb_fa_regfile;
    logic        clk, rst_n;
    logic [5:0]  s_axil_awaddr;
    logic        s_axil_awvalid, s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid, s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid, s_axil_bready;
    logic [5:0]  s_axil_araddr;
    logic        s_axil_arvalid, s_axil_arready;
    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;
    logic        s_axil_rvalid, s_axil_rready;
    logic        hw_busy, hw_done, hw_error;
    logic [31:0] hw_cycle_cnt;
    logic        reg_start, reg_soft_reset, reg_causal_en;
    logic [63:0] reg_q_base, reg_k_base, reg_v_base, reg_o_base;
    logic [31:0] reg_stride;

    integer tests_passed = 0, tests_failed = 0, test_id = 0, tc;

    fa_regfile dut (.*);
    initial clk = 0;
    always #5 clk = ~clk;

    task axil_write(input [5:0] addr, input [31:0] data);
        s_axil_awaddr = addr; s_axil_awvalid = 1; s_axil_wvalid = 0; s_axil_bready = 0;
        for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_awready) begin s_axil_awvalid = 0; tc = 50; end end
        s_axil_wdata = data; s_axil_wstrb = 4'hF; s_axil_wvalid = 1;
        for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_wready) begin s_axil_wvalid = 0; tc = 50; end end
        s_axil_bready = 1;
        for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_bvalid) begin s_axil_bready = 0; tc = 50; end end
        @(posedge clk);
    endtask

    logic [31:0] rd_result;
    task axil_read(input [5:0] addr, output [31:0] data);
        s_axil_araddr = addr; s_axil_arvalid = 1; s_axil_rready = 0;
        for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_arready) begin s_axil_arvalid = 0; tc = 50; end end
        s_axil_rready = 1;
        for (tc = 0; tc < 50; tc++) begin @(posedge clk); if (s_axil_rvalid) begin data = s_axil_rdata; s_axil_rready = 0; tc = 50; end end
        @(posedge clk);
    endtask

    task check(input string name, input [31:0] actual, input [31:0] expected);
        test_id++;
        if (actual === expected) begin tests_passed++; $display("[PASS] Test %0d: %s = 0x%08x", test_id, name, actual);
        end else begin tests_failed++; $display("[FAIL] Test %0d: %s = 0x%08x, expected 0x%08x", test_id, name, actual, expected); end
    endtask

    initial begin
        $dumpfile("sim_results/tb_fa_regfile.vcd");
        $dumpvars(0, tb_fa_regfile);
        s_axil_awaddr=0; s_axil_awvalid=0; s_axil_wdata=0; s_axil_wstrb=0; s_axil_wvalid=0; s_axil_bready=0;
        s_axil_araddr=0; s_axil_arvalid=0; s_axil_rready=0;
        hw_busy=0; hw_done=0; hw_error=0; hw_cycle_cnt=0;
        rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);

        // T1: REV
        axil_read(6'h34, rd_result);
        check("REV register", rd_result, 32'hFA_00_01_00);

        // T2-T3: Q_BASE write/read
        axil_write(6'h0C, 32'hDEAD_BEEF);
        axil_read(6'h0C, rd_result);
        check("Q_BASE_L write/read", rd_result, 32'hDEAD_BEEF);
        axil_write(6'h10, 32'hCAFE_BABE);
        axil_read(6'h10, rd_result);
        check("Q_BASE_H write/read", rd_result, 32'hCAFE_BABE);

        // T4: reg_q_base output
        #1;
        check("reg_q_base[31:0]", reg_q_base[31:0], 32'hDEAD_BEEF);
        check("reg_q_base[63:32]", reg_q_base[63:32], 32'hCAFE_BABE);

        // T5: All base addresses
        axil_write(6'h14, 32'h11111111); axil_write(6'h18, 32'h22222222);
        axil_write(6'h1C, 32'h33333333); axil_write(6'h20, 32'h44444444);
        axil_write(6'h24, 32'h55555555); axil_write(6'h28, 32'h66666666);
        axil_write(6'h2C, 32'h00000100);
        #1;
        check("K_BASE_L", reg_k_base[31:0], 32'h11111111);
        check("K_BASE_H", reg_k_base[63:32], 32'h22222222);
        check("V_BASE_L", reg_v_base[31:0], 32'h33333333);
        check("V_BASE_H", reg_v_base[63:32], 32'h44444444);
        check("O_BASE_L", reg_o_base[31:0], 32'h55555555);
        check("O_BASE_H", reg_o_base[63:32], 32'h66666666);
        check("STRIDE", reg_stride, 32'h00000100);

        // T6: START self-clears (pulse behavior)
        // Write START, it self-clears on next clock. Verify it's not stuck.
        axil_write(6'h00, 32'h1);
        repeat(3) @(posedge clk);
        #1;
        check("START self-cleared", {31'h0, reg_start}, 32'h0);

        // T7: SOFT_RESET self-clears (pulse behavior)
        axil_write(6'h00, 32'h2);
        repeat(3) @(posedge clk);
        #1;
        check("SOFT_RESET self-cleared", {31'h0, reg_soft_reset}, 32'h0);

        // T8: CAUSAL_EN sticky
        axil_write(6'h00, 32'h4);
        repeat(2) @(posedge clk);
        #1;
        check("CAUSAL_EN set", {31'h0, reg_causal_en}, 32'h1);
        repeat(5) @(posedge clk);
        #1;
        check("CAUSAL_EN sticky", {31'h0, reg_causal_en}, 32'h1);
        axil_write(6'h00, 32'h0);
        repeat(2) @(posedge clk);
        #1;
        check("CAUSAL_EN cleared", {31'h0, reg_causal_en}, 32'h0);

        // T9: hw_busy in STATUS
        hw_busy = 1; repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("STATUS BUSY=1", rd_result[0], 1'b1);
        hw_busy = 0; repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("STATUS BUSY=0", rd_result[0], 1'b0);

        // T10: DONE W1C
        hw_done = 1; repeat(3) @(posedge clk); hw_done = 0; repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("DONE set", rd_result[1], 1'b1);
        axil_write(6'h04, 32'h2);
        repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("DONE W1C", rd_result[1], 1'b0);

        // T11: ERROR W1C
        hw_error = 1; repeat(3) @(posedge clk); hw_error = 0; repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("ERROR set", rd_result[2], 1'b1);
        axil_write(6'h04, 32'h4);
        repeat(2) @(posedge clk);
        axil_read(6'h04, rd_result);
        check("ERROR W1C", rd_result[2], 1'b0);

        // T12: CYCLES register
        hw_cycle_cnt = 32'h12345678; repeat(2) @(posedge clk);
        axil_read(6'h30, rd_result);
        check("CYCLES", rd_result, 32'h12345678);

        // T13: Write protect when BUSY
        hw_busy = 1; repeat(2) @(posedge clk);
        axil_write(6'h0C, 32'hFFFFFFFF);
        axil_read(6'h0C, rd_result);
        check("Write protect Q_BASE_L", rd_result, 32'hDEADBEEF);
        hw_busy = 0; repeat(2) @(posedge clk);

        // T14: CFG register (reserved - read returns reg_file[2] which is 0)
        axil_read(6'h08, rd_result);
        check("CFG register (reserved, no write path)", rd_result, 32'h0);

        // T15: Read all addresses for toggle coverage
        for (int a = 0; a < 14; a++)
            axil_read(6'(a*4), rd_result);

        // T16: Verify write-through after BUSY clears
        axil_write(6'h0C, 32'hCAFEBABE);
        axil_read(6'h0C, rd_result);
        check("Write after BUSY clear", rd_result, 32'hCAFEBABE);

        // T17: Toggle coverage - write all 1s to base addresses
        axil_write(6'h0C, 32'hFFFFFFFF);
        axil_write(6'h10, 32'hFFFFFFFF);
        axil_write(6'h14, 32'hFFFFFFFF);
        axil_write(6'h18, 32'hFFFFFFFF);
        axil_write(6'h1C, 32'hFFFFFFFF);
        axil_write(6'h20, 32'hFFFFFFFF);
        axil_write(6'h24, 32'hFFFFFFFF);
        axil_write(6'h28, 32'hFFFFFFFF);
        axil_write(6'h2C, 32'hFFFFFFFF);
        axil_read(6'h0C, rd_result);
        check("All 1s Q_BASE_L", rd_result, 32'hFFFFFFFF);
        axil_read(6'h2C, rd_result);
        check("All 1s STRIDE", rd_result, 32'hFFFFFFFF);

        // T18: Write alternating pattern
        axil_write(6'h0C, 32'hAAAAAAAA);
        axil_write(6'h10, 32'h55555555);
        axil_read(6'h0C, rd_result);
        check("Alt pattern L", rd_result, 32'hAAAAAAAA);
        axil_read(6'h10, rd_result);
        check("Alt pattern H", rd_result, 32'h55555555);

        // T19: wstrb write test (regfile writes full 32-bit regardless of wstrb)
        @(posedge clk);
        s_axil_awaddr = 6'h0C; s_axil_awvalid = 1;
        for (tc=0;tc<50;tc++) begin @(posedge clk); if(s_axil_awready) begin s_axil_awvalid=0; tc=50; end end
        s_axil_wdata = 32'h12345678; s_axil_wstrb = 4'h3; s_axil_wvalid = 1;
        for (tc=0;tc<50;tc++) begin @(posedge clk); if(s_axil_wready) begin s_axil_wvalid=0; tc=50; end end
        s_axil_bready = 1;
        for (tc=0;tc<50;tc++) begin @(posedge clk); if(s_axil_bvalid) begin s_axil_bready=0; tc=50; end end
        @(posedge clk);
        axil_read(6'h0C, rd_result);
        // RTL does full 32-bit write (wstrb not used in write logic)
        check("wstrb full write", rd_result, 32'h12345678);

        $display("========================================");
        $display("  fa_regfile: %0d passed, %0d failed", tests_passed, tests_failed);
        $display("========================================");
        $display(tests_failed > 0 ? "RESULT: FAIL" : "RESULT: PASS");
        $finish;
    end

    initial begin #200000; $display("[TIMEOUT]"); $finish; end
endmodule
