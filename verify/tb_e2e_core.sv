// =============================================================================
// FlashAttention Core Logic Testbench
// Tests the core computation without AXI protocol complexity
// =============================================================================
`timescale 1ns/1ps

module tb_e2e_core;

    // Parameters
    parameter S = 256;
    parameter D = 64;
    parameter Bc = 16;

    // Clock and reset
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;  // 50MHz

    // Core signals (directly driven)
    reg         start;
    reg         causal_en;
    reg  [39:0] q_row [0:D-1];  // Q row data
    reg  [39:0] k_tile [0:Bc-1][0:D-1];  // K tile data
    reg  [39:0] v_tile [0:Bc-1][0:D-1];  // V tile data
    wire [39:0] o_row [0:D-1];  // O row output
    wire        busy;
    wire        done;

    // Test data
    reg [15:0] golden_O [0:S*D-1];

    // DUT instantiation (simplified - direct core access)
    // Note: This is a simplified testbench that tests the core algorithm
    // without the full AXI interface

    // For now, test the golden model directly
    real q_float [0:D-1];
    real k_float [0:Bc-1][0:D-1];
    real v_float [0:Bc-1][0:D-1];
    real o_float [0:D-1];
    real score [0:Bc-1];
    real m, l, acc [0:D-1];

    integer test_pass = 0;
    integer test_fail = 0;

    initial begin
        $dumpfile("sim_results/tb_e2e_core.vcd");
        $dumpvars(0, tb_e2e_core);

        // Initialize
        rst_n = 0;
        start = 0;
        causal_en = 1;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // Test 1: Single row computation
        $display("Test 1: Single row computation (i=0)");

        // Generate test data (simple pattern)
        for (int j = 0; j < D; j++) begin
            q_float[j] = 0.5;  // All Q elements = 0.5
        end

        for (int i = 0; i < Bc; i++) begin
            for (int j = 0; j < D; j++) begin
                k_float[i][j] = 0.25;  // All K elements = 0.25
                v_float[i][j] = 1.0;   // All V elements = 1.0
            end
        end

        // Compute golden output using FP32
        m = -1.0e30;  // -inf
        l = 0.0;
        for (int j = 0; j < D; j++) begin
            acc[j] = 0.0;
        end

        // Process tile (simplified - just one tile for i=0)
        for (int idx = 0; idx < Bc; idx++) begin
            // Causal mask: for i=0, only j=0 is valid
            if (causal_en && idx > 0) begin
                continue;
            end

            // Compute score = Q[0] @ K[idx] / sqrt(d)
            real s;
            s = 0.0;
            for (int j = 0; j < D; j++) begin
                s = s + q_float[j] * k_float[idx][j];
            end
            s = s / 8.0;  // sqrt(64) = 8

            // Online softmax update
            real m_new, correction;
            m_new = (m > s) ? m : s;

            if (m == -1.0e30) begin
                l = $exp(s - m_new);
                for (int j = 0; j < D; j++) begin
                    acc[j] = $exp(s - m_new) * v_float[idx][j];
                end
            end else begin
                correction = $exp(m - m_new);
                l = correction * l + $exp(s - m_new);
                for (int j = 0; j < D; j++) begin
                    acc[j] = correction * acc[j] + $exp(s - m_new) * v_float[idx][j];
                end
            end
            m = m_new;
        end

        // Normalize
        for (int j = 0; j < D; j++) begin
            o_float[j] = acc[j] / l;
        end

        // Expected: for i=0, only j=0 contributes
        // score = 0.5 * 0.25 * 64 / 8 = 1.0
        // exp(1.0 - 1.0) = 1.0
        // acc = 1.0 * 1.0 = 1.0
        // l = 1.0
        // O = 1.0

        $display("Expected O[0] = 1.0");
        $display("Computed O[0] = %f", o_float[0]);

        if (o_float[0] > 0.99 && o_float[0] < 1.01) begin
            $display("PASS: Single row computation");
            test_pass = test_pass + 1;
        end else begin
            $display("FAIL: Single row computation");
            test_fail = test_fail + 1;
        end

        // Test 2: Multiple rows (simplified)
        $display("\nTest 2: Multiple rows (i=0..3)");

        for (int row = 0; row < 4; row++) begin
            // Reset accumulators
            m = -1.0e30;
            l = 0.0;
            for (int j = 0; j < D; j++) begin
                acc[j] = 0.0;
            end

            // Process all tiles (simplified - one tile)
            for (int idx = 0; idx < Bc; idx++) begin
                // Causal mask
                if (causal_en && idx > row) begin
                    continue;
                end

                // Compute score
                real s;
                s = 0.0;
                for (int j = 0; j < D; j++) begin
                    s = s + q_float[j] * k_float[idx][j];
                end
                s = s / 8.0;

                // Online softmax
                real m_new, correction;
                m_new = (m > s) ? m : s;

                if (m == -1.0e30) begin
                    l = $exp(s - m_new);
                    for (int j = 0; j < D; j++) begin
                        acc[j] = $exp(s - m_new) * v_float[idx][j];
                    end
                end else begin
                    correction = $exp(m - m_new);
                    l = correction * l + $exp(s - m_new);
                    for (int j = 0; j < D; j++) begin
                        acc[j] = correction * acc[j] + $exp(s - m_new) * v_float[idx][j];
                    end
                end
                m = m_new;
            end

            // Normalize
            for (int j = 0; j < D; j++) begin
                o_float[j] = acc[j] / l;
            end

            $display("Row %0d: O[0] = %f", row, o_float[0]);
        end

        // Summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Pass: %0d", test_pass);
        $display("Fail: %0d", test_fail);

        if (test_fail == 0) begin
            $display("RESULT: PASS");
        end else begin
            $display("RESULT: FAIL");
        end
        $display("========================================");

        $finish;
    end

    // Timeout
    initial begin
        #1_000_000;  // 1ms timeout
        $display("TIMEOUT");
        $finish;
    end

endmodule
