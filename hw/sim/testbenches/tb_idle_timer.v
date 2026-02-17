// ============================================================================
// Testbench: tb_idle_timer
// Project: DE10-Standard LCD Message System
// Description: Verifies the idle_timer module with:
//   1. Timeout accuracy — expires after exactly TIMEOUT_SEC seconds
//   2. Reset during countdown — timer restarts
//   3. Enable gate — timer freezes when disabled
//   4. seconds_remaining BCD output verification
//
// Simulation shortcut: CLK_FREQ_HZ=100, TIMEOUT_SEC=3
//   → 100 ticks/sec, 3 seconds = 300 ticks total
// ============================================================================

`timescale 1ns / 1ps

module tb_idle_timer;

    // ----------------------------------------------------------------
    // Parameters — fast simulation
    // ----------------------------------------------------------------
    localparam CLK_FREQ_HZ = 100;    // 100 Hz for fast sim
    localparam TIMEOUT_SEC = 3;      // 3 second countdown
    localparam CLK_PERIOD  = 10_000_000;  // 10 ms in ns (100 Hz)

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        reset_timer;
    reg        enable;
    wire       timeout;
    wire [3:0] seconds_remaining;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    idle_timer #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .TIMEOUT_SEC (TIMEOUT_SEC)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .reset_timer       (reset_timer),
        .enable            (enable),
        .timeout           (timeout),
        .seconds_remaining (seconds_remaining)
    );

    // ----------------------------------------------------------------
    // Clock generation: 100 Hz
    // ----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ----------------------------------------------------------------
    // Test tracking
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    task check_timeout;
        input expected_timeout;
        input [3:0] expected_sec;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            if (timeout !== expected_timeout || seconds_remaining !== expected_sec) begin
                $display("FAIL Test %0d [%0s]: timeout=%b(exp=%b) sec=%0d(exp=%0d) at %0t",
                         test_num, test_name, timeout, expected_timeout,
                         seconds_remaining, expected_sec, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS Test %0d [%0s]: timeout=%b sec=%0d at %0t",
                         test_num, test_name, timeout, seconds_remaining, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        $display("=== TB: idle_timer ===");
        $display("CLK_FREQ_HZ=%0d, TIMEOUT_SEC=%0d", CLK_FREQ_HZ, TIMEOUT_SEC);

        reset_timer = 1'b0;
        enable      = 1'b0;
        rst_n       = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ============================================================
        // TEST 1: Initial state after reset
        // ============================================================
        check_timeout(1'b0, 4'd3, "Initial state");

        // ============================================================
        // TEST 2: Timer disabled — should NOT count
        // ============================================================
        enable = 1'b0;
        repeat (200) @(posedge clk);  // Wait 2 "seconds"
        check_timeout(1'b0, 4'd3, "Disabled no count");

        // ============================================================
        // TEST 3: Enable timer — count 1 second
        // ============================================================
        enable = 1'b1;
        repeat (CLK_FREQ_HZ) @(posedge clk);  // 100 ticks = 1 second
        check_timeout(1'b0, 4'd2, "After 1 second");

        // ============================================================
        // TEST 4: Count another second (2 elapsed)
        // ============================================================
        repeat (CLK_FREQ_HZ) @(posedge clk);
        check_timeout(1'b0, 4'd1, "After 2 seconds");

        // ============================================================
        // TEST 5: Count third second — timeout should assert NOW
        //   (Fixed: timer asserts timeout after exactly TIMEOUT_SEC seconds)
        // ============================================================
        repeat (CLK_FREQ_HZ) @(posedge clk);
        check_timeout(1'b1, 4'd0, "Timeout after 3 secs");

        // ============================================================
        // TEST 6: Timer stays timed-out (doesn't wrap)
        // ============================================================
        repeat (50) @(posedge clk);
        check_timeout(1'b1, 4'd0, "Stays timed out");

        // ============================================================
        // TEST 7: Reset_timer restarts countdown
        // ============================================================
        reset_timer = 1'b1;
        @(posedge clk);
        reset_timer = 1'b0;
        @(posedge clk);

        check_timeout(1'b0, 4'd3, "Reset restarts");

        // ============================================================
        // TEST 8: Enable gating — disable mid-countdown
        // ============================================================
        repeat (CLK_FREQ_HZ) @(posedge clk);  // 1 second
        enable = 1'b0;  // Freeze
        repeat (200) @(posedge clk);
        check_timeout(1'b0, 4'd2, "Frozen at 2");

        enable = 1'b1;  // Resume
        repeat (CLK_FREQ_HZ) @(posedge clk);
        check_timeout(1'b0, 4'd1, "Resumed to 1");

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        $display("=== RESULTS: %0d PASSED, %0d FAILED out of %0d tests ===",
                 pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_idle_timer.vcd");
        $dumpvars(0, tb_idle_timer);
    end

endmodule
