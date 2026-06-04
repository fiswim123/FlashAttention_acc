//      // verilator_coverage annotation
        // =============================================================================
        // Testbench: fa_systolic (Verilator-compatible)
        // Tests: MAC QK/SV, accumulation, pipeline with MAC_FLUSH, acc_clear
        // RTL: MAC_FLUSH state holds pipeline. acc_en gated by MAC_RUN -> 62 products.
        //      No pipeline residual: mul_reg overwritten by new MAC before accumulation.
        // =============================================================================
        `timescale 1ns/1ps
        
        module tb_fa_systolic;
~001847     logic clk, rst_n, mac_start, mac_done, mac_mode, acc_clear;
%000007     logic [255:0] q_data, kv_data, score_in;
            logic [639:0] acc_out;
        
%000001     integer tp=0, tf=0, tid=0;
        
            fa_systolic dut (.*);
%000001     initial clk = 0;
 001847     always #5 clk = ~clk;
        
 000024     function automatic [255:0] pack16(
                input signed [15:0] v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15);
 000024         pack16 = {v15,v14,v13,v12,v11,v10,v9,v8,v7,v6,v5,v4,v3,v2,v1,v0};
            endfunction
        
 000044     function automatic signed [39:0] acc_elem(input [639:0] acc, input int idx);
 000044         acc_elem = $signed(acc[idx*40 +: 40]);
            endfunction
        
 000012     task check40(input string n, input signed [39:0] a, input signed [39:0] e);
 000012         tid++;
~000012         if (a===e) begin tp++; $display("[PASS] Test %0d: %s = %0d", tid, n, a);
%000000         end else begin tf++; $display("[FAIL] Test %0d: %s = %0d, exp %0d", tid, n, a, e); end
            endtask
        
 000012     task run_mac(input [255:0] a, input [255:0] b, input mode, input clear);
~000010         if (clear) begin @(posedge clk); acc_clear=1; @(posedge clk); acc_clear=0; end
 000012         @(posedge clk); q_data=a; kv_data=b; score_in=a; mac_mode=mode; mac_start=1;
 000012         @(posedge clk); mac_start=0;
 000792         for (int i=0; i<200; i++) begin @(posedge clk); if (mac_done) i=200; end
 000012         @(posedge clk);
            endtask
        
            // Pipeline: 62 products accumulated (MAC_FLUSH doesn't accumulate).
            // No pipeline residual: mul_reg overwritten by new MAC inputs in cycle 1.
            localparam int PRODUCTS = 62;
        
%000001     initial begin
%000001         $dumpfile("sim_results/tb_fa_systolic.vcd");
%000001         $dumpvars(0, tb_fa_systolic);
%000001         q_data=0; kv_data=0; score_in=0; mac_mode=0; mac_start=0; acc_clear=0;
%000004         rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);
        
                // T1: QK mode - all 1.0 * [1.0, 0, 0, ...]
%000001         run_mac(
%000001             pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001             pack16(256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b1);
%000001         check40("acc[0] QK", acc_elem(acc_out,0), 40'(PRODUCTS * 256 * 256));
%000001         check40("acc[1] QK zero", acc_elem(acc_out,1), 40'sd0);
        
                // T2: Zero inputs (no residual from T1)
%000001         run_mac(
%000001             pack16(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001             pack16(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b1);
%000001         check40("acc[0] zero", acc_elem(acc_out,0), 40'sd0);
        
                // T3: SV mode (no residual from T2)
%000001         run_mac(
%000001             pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001             pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001             1'b1, 1'b1);
%000001         check40("acc[0] SV", acc_elem(acc_out,0), 40'(PRODUCTS * 256 * 256));
        
                // T4: Negative * positive (no residual from T3)
%000001         run_mac(
%000001             pack16(-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256,-256),
%000001             pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001             1'b0, 1'b1);
%000001         check40("acc[0] neg*pos", acc_elem(acc_out,0), -(40'(PRODUCTS * 256 * 256)));
        
                // T5: mac_done pulse
%000001         @(posedge clk); q_data=0; kv_data=0; mac_mode=0; acc_clear=1;
%000001         @(posedge clk); acc_clear=0; mac_start=1;
%000001         @(posedge clk); mac_start=0;
%000001         #1; tid++;
%000001         if (!mac_done) begin tp++; $display("[PASS] Test %0d: mac_done not early", tid);
%000000         end else begin tf++; $display("[FAIL] Test %0d: mac_done early", tid); end
~000066         for (int i=0; i<200; i++) begin @(posedge clk); if (mac_done) i=200; end
%000001         @(posedge clk); #1;
%000001         tid++;
%000001         if (!mac_done) begin tp++; $display("[PASS] Test %0d: mac_done cleared", tid);
%000000         end else begin tf++; $display("[FAIL] Test %0d: mac_done stuck", tid); end
        
                // T6: Two MACs with clear (no residual between them)
%000001         run_mac(pack16(256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001                 pack16(256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b1);
%000001         run_mac(pack16(256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001                 pack16(256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b0);
                // First: 62*256*256 = 4063232. Second (no clear): keeps first + 62*256*256
%000001         check40("acc[0] accumulated", acc_elem(acc_out,0), 40'(2 * PRODUCTS * 256 * 256));
        
                // T7: All 16 elements active (with clear, no residual)
%000001         run_mac(pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001                 pack16(256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256),
%000001                 1'b0, 1'b1);
~000016         for (int i=0; i<16; i++)
 000016             $display("  acc[%0d] = %0d", i, acc_elem(acc_out, i));
%000001         check40("acc[0] all16", acc_elem(acc_out,0), 40'(PRODUCTS * 256 * 256));
%000001         check40("acc[15] all16", acc_elem(acc_out,15), 40'(PRODUCTS * 256 * 256));
        
                // T8: Asymmetric values (with clear, no residual)
%000001         run_mac(pack16(100,200,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500,1600),
%000001                 pack16(16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1),
%000001                 1'b0, 1'b1);
%000001         check40("acc[0] asymmetric", acc_elem(acc_out,0), 40'(62*100*16));
%000001         check40("acc[15] asymmetric", acc_elem(acc_out,15), 40'(62*1600*1));
        
                // T9: Non-negative for positive inputs
%000001         run_mac(pack16(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1),
%000001                 pack16(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1), 1'b0, 1'b1);
%000001         tid++;
%000001         begin
                    logic all_nonneg;
%000001             all_nonneg = 1;
~000016             for (int i = 0; i < 16; i++)
~000016                 if (acc_elem(acc_out, i) < 0) all_nonneg = 0;
%000001             if (all_nonneg) begin tp++; $display("[PASS] Test %0d: all acc non-negative", tid);
%000000             end else begin tf++; $display("[FAIL] Test %0d: some acc negative", tid); end
                end
        
                // T10: Two MACs with different products
%000001         run_mac(pack16(10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001                 pack16(10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b1);
%000001         run_mac(pack16(10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001                 pack16(10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b0);
                // First: 62*100=6200. Second (no clear): keeps first + 62*100
%000001         check40("acc[0] 2 MACs", acc_elem(acc_out, 0), 40'(2 * PRODUCTS * 10 * 10));
        
                // T11: Single element active
%000001         run_mac(pack16(1000,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
%000001                 pack16(500,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0), 1'b0, 1'b1);
%000001         check40("acc[0] single elem", acc_elem(acc_out,0), 40'(62*1000*500));
        
%000001         $display("========================================");
%000001         $display("  fa_systolic: %0d passed, %0d failed", tp, tf);
%000001         $display("========================================");
%000001         $display(tf > 0 ? "RESULT: FAIL" : "RESULT: PASS");
%000001         $finish;
            end
        
%000000     initial begin #200000; $display("[TIMEOUT]"); $finish; end
        endmodule
        
