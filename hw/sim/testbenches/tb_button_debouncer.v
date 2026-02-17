// ============================================================================
// Testbench: tb_button_debouncer
// Project: DE10-Standard LCD Message System
// Description: Verifies the button_debouncer module with:
//   1. Clean press (held >50ms) → output goes HIGH
//   2. Noise rejection (bounce <50ms) → output stays LOW
//   3. Clean release → output returns LOW
//   4. Multi-button simultaneous press
//   5. Reset behavior
//
// Simulation shortcut: CLK_FREQ_HZ=1000, DEBOUNCE_MS=1
//   → 1000 ticks = 1ms debounce time (fast simulation)
// ============================================================================

`timescale 1ns / 1ps

module tb_button_debouncer;

    // ----------------------------------------------------------------
    // Parameters — fast simulation settings
    // ----------------------------------------------------------------
    localparam CLK_FREQ_HZ = 1000;    // 1 kHz clock for fast sim
    localparam DEBOUNCE_MS = 1;       // 1 ms debounce → 1000 ticks
    localparam NUM_BUTTONS = 4;
    localparam CLK_PERIOD  = 1_000_000; // 1 ms in ns (for 1 kHz clock)

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg  [NUM_BUTTONS-1:0] btn_in;    // Active-LOW (simulating KEY pins)
    wire [NUM_BUTTONS-1:0] btn_out;   // Active-HIGH debounced

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    button_debouncer #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .DEBOUNCE_MS (DEBOUNCE_MS),
        .NUM_BUTTONS (NUM_BUTTONS)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .btn_in (btn_in),
        .btn_out(btn_out)
    );

    // ----------------------------------------------------------------
    // Clock generation: 1 kHz (period = 1 ms = 1,000,000 ns)
    // ----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ----------------------------------------------------------------
    // Test results tracking
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    task check;
        input [NUM_BUTTONS-1:0] expected;
        input [255:0] test_name;  // Verilog string (packed)
        begin
            test_num = test_num + 1;
            if (btn_out !== expected) begin
                $display("FAIL Test %0d [%0s]: Expected=%b, Got=%b at time %0t",
                         test_num, test_name, expected, btn_out, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS Test %0d [%0s]: btn_out=%b at time %0t",
                         test_num, test_name, btn_out, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        $display("=== TB: button_debouncer ===");
        $display("CLK_FREQ_HZ=%0d, DEBOUNCE_MS=%0d, DEBOUNCE_TICKS=%0d",
                 CLK_FREQ_HZ, DEBOUNCE_MS, CLK_FREQ_HZ/1000*DEBOUNCE_MS);

        // Initialize
        btn_in = 4'b1111;     // All buttons released (active-LOW)
        rst_n  = 1'b0;        // Assert reset

        // Hold reset for 5 clock cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1;         // Release reset
        repeat (2) @(posedge clk);

        // ============================================================
        // TEST 1: Reset state — all outputs should be LOW
        // ============================================================
        check(4'b0000, "Reset state");

        // ============================================================
        // TEST 2: Clean press of KEY0 — hold for > debounce time
        //   btn_in[0] goes LOW (active-LOW = pressed)
        //   After 2-FF sync (2 cycles) + debounce (1000 cycles) = ~1002 cycles
        // ============================================================
        btn_in[0] = 1'b0;     // Press KEY0

        // Wait for 2-FF sync + debounce to settle
        // 2 cycles for sync + 1000 cycles for debounce = 1002
        repeat (1005) @(posedge clk);

        check(4'b0001, "Clean press KEY0");

        // ============================================================
        // TEST 3: Release KEY0 — output returns LOW after debounce
        // ============================================================
        btn_in[0] = 1'b1;     // Release KEY0

        repeat (1005) @(posedge clk);

        check(4'b0000, "Release KEY0");

        // ============================================================
        // TEST 4: Noise rejection — bounce within debounce window
        //   Press, release quickly (before debounce settles), re-press
        // ============================================================
        btn_in[1] = 1'b0;     // Press KEY1
        repeat (500) @(posedge clk);  // Only 500 ticks (< 1000)
        btn_in[1] = 1'b1;     // Release before debounce completes
        repeat (100) @(posedge clk);

        check(4'b0000, "Noise rejection");

        // ============================================================
        // TEST 5: Multi-button press — KEY2 + KEY3 simultaneously
        // ============================================================
        btn_in[2] = 1'b0;     // Press KEY2
        btn_in[3] = 1'b0;     // Press KEY3

        repeat (1005) @(posedge clk);

        check(4'b1100, "Multi-button KEY2+KEY3");

        // Release both
        btn_in[2] = 1'b1;
        btn_in[3] = 1'b1;
        repeat (1005) @(posedge clk);

        check(4'b0000, "Release KEY2+KEY3");

        // ============================================================
        // TEST 6: Reset during active press
        // ============================================================
        btn_in[0] = 1'b0;       // Press KEY0
        repeat (1005) @(posedge clk);
        // btn_out[0] should be 1 now

        rst_n = 1'b0;            // Assert reset
        repeat (3) @(posedge clk);
        check(4'b0000, "Reset clears output");

        rst_n = 1'b1;            // Release reset
        btn_in[0] = 1'b1;        // Release KEY0
        repeat (5) @(posedge clk);

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
    // Optional: VCD waveform dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_button_debouncer.vcd");
        $dumpvars(0, tb_button_debouncer);
    end

endmodule
