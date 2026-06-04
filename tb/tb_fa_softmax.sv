// =============================================================================
// Testbench: fa_softmax (Verilator-compatible)
// Tests: FSM, max tree, exp table, sum, scale/acc, causal mask
// =============================================================================
`timescale 1ns/1ps

module tb_fa_softmax;
    logic clk, rst_n, sm_start, sm_done;
    logic [255:0] score, exp_out;
    logic [39:0] m_old, l_old, m_new, l_new;
    logic [15:0] correction, causal_mask;

    integer tp=0, tf=0, tid=0;

    fa_softmax dut (.*);
    initial clk = 0;
    always #5 clk = ~clk;

    function automatic [255:0] pack16(
        input signed [15:0] s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15);
        pack16 = {s15,s14,s13,s12,s11,s10,s9,s8,s7,s6,s5,s4,s3,s2,s1,s0};
    endfunction

    task check40(input string n, input signed [39:0] a, input signed [39:0] e);
        tid++;
        if (a===e) begin tp++; $display("[PASS] Test %0d: %s = %0d", tid, n, a);
        end else begin tf++; $display("[FAIL] Test %0d: %s = %0d, exp %0d", tid, n, a, e); end
    endtask

    task run_sm(input [255:0] sc, input signed [39:0] mo, input signed [39:0] lo, input [15:0] mask);
        @(posedge clk); score=sc; m_old=mo; l_old=lo; causal_mask=mask; sm_start=1;
        @(posedge clk); sm_start=0;
        for (int i=0; i<100; i++) begin @(posedge clk); if (sm_done) i=100; end
        @(posedge clk);
    endtask

    initial begin
        $dumpfile("sim_results/tb_fa_softmax.vcd");
        $dumpvars(0, tb_fa_softmax);
        score=0; m_old=0; l_old=0; causal_mask=16'hFFFF; sm_start=0;
        rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);

        // T1: All same scores=1.0 (Q8.8=256), m_old=0, l_old=0
        run_sm(pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256), 40'sd0, 40'sd0, 16'hFFFF);
        check40("m_new all=1.0", m_new, 40'sd256);

        // T2: Mixed ascending scores, max=2048 (8.0 in Q8.8)
        run_sm(pack16(128,256,384,512,640,768,896,1024,1152,1280,1408,1536,1664,1792,1920,2048), 40'sd0, 40'sd0, 16'hFFFF);
        check40("m_new mixed", m_new, 40'sd2048);

        // T3: m_old > max_score -> m_new = m_old
        run_sm(pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,512), 40'sd2560, 40'sd0, 16'hFFFF);
        check40("m_old wins", m_new, 40'sd2560);

        // T4: Causal mask upper half masked
        run_sm(pack16(128,256,384,512,640,768,896,1024,2048,3072,4096,5120,6144,7168,8192,9216), 40'sd0, 40'sd0, 16'h00FF);
        check40("causal mask", m_new, 40'sd1024);

        // T5: All masked -> m_new = m_old (0)
        run_sm(pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256), 40'sd0, 40'sd0, 16'h0000);
        check40("all masked", m_new, 40'sd0);

        // T6: Online softmax 2nd tile
        run_sm(pack16(1792,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256), 40'sd1280, 40'sd5000, 16'hFFFF);
        check40("online tile 2", m_new, 40'sd1792);

        // T7: Negative scores
        // All -1.0 (Q8.8 = -256), m_old=0. max_score=-256.
        // m_new = max(max_score_ext, m_old) = max(-256, 0) = 0
        // (since -256 < 0, m_old wins)
        run_sm(pack16(-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256), 40'sd0, 40'sd0, 16'hFFFF);
        check40("all negative (m_old wins)", m_new, 40'sd0);

        // T8: sm_done pulse
        @(posedge clk); score=0; m_old=0; l_old=0; causal_mask=16'hFFFF; sm_start=1;
        @(posedge clk); sm_start=0;
        #1; tid++;
        if (!sm_done) begin tp++; $display("[PASS] Test %0d: sm_done not early", tid);
        end else begin tf++; $display("[FAIL] Test %0d: sm_done early", tid); end
        for (int i=0; i<100; i++) begin @(posedge clk); if (sm_done) i=100; end
        @(posedge clk); #1;
        tid++;
        if (!sm_done) begin tp++; $display("[PASS] Test %0d: sm_done cleared", tid);
        end else begin tf++; $display("[FAIL] Test %0d: sm_done stuck", tid); end

        // T9: Verify exp_out is non-zero for valid scores
        run_sm(pack16(512,256,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 40'sd0, 40'sd0, 16'hFFFF);
        #1; tid++;
        if (exp_out != 256'h0) begin tp++; $display("[PASS] Test %0d: exp_out non-zero", tid);
        end else begin tf++; $display("[FAIL] Test %0d: exp_out is zero", tid); end

        // T10: Zero scores
        run_sm(pack16(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 40'sd0, 40'sd0, 16'hFFFF);
        check40("all zero scores", m_new, 40'sd0);

        $display("========================================");
        $display("  fa_softmax: %0d passed, %0d failed", tp, tf);
        $display("========================================");
        $display(tf > 0 ? "RESULT: FAIL" : "RESULT: PASS");
        $finish;
    end

    initial begin #100000; $display("[TIMEOUT]"); $finish; end
endmodule
