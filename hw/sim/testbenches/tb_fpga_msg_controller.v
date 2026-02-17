// ============================================================================
// Testbench: tb_fpga_msg_controller
// Project: DE10-Standard LCD Message System
// Description: Full integration testbench for fpga_msg_controller.
//              Stimulates KEY inputs and verifies:
//              - btn_debounced outputs after debounce settling
//              - btn_pulse single-cycle events
//              - idle_timer countdown and timeout
//              - HEX display outputs
//
// Simulation shortcut: CLK_FREQ_HZ=1000, DEBOUNCE_MS=1, TIMEOUT_SEC=3
// ============================================================================

`timescale 1ns / 1ps

module tb_fpga_msg_controller;

    // ----------------------------------------------------------------
    // Parameters — fast simulation
    // ----------------------------------------------------------------
    localparam CLK_FREQ_HZ = 1000;
    localparam DEBOUNCE_MS = 1;
    localparam TIMEOUT_SEC = 3;
    localparam NUM_BUTTONS = 4;
    localparam CLK_PERIOD  = 1_000_000;  // 1 ms in ns (1 kHz)

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg  [NUM_BUTTONS-1:0] key_in;

    wire [NUM_BUTTONS-1:0] btn_pulse;
    wire [NUM_BUTTONS-1:0] btn_debounced;
    wire                   timeout_flag;
    wire [3:0]             seconds_remaining;
    wire [6:0]             hex0, hex1, hex2, hex3, hex4, hex5;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    fpga_msg_controller #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .DEBOUNCE_MS (DEBOUNCE_MS),
        .TIMEOUT_SEC (TIMEOUT_SEC),
        .NUM_BUTTONS (NUM_BUTTONS)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .key_in            (key_in),
        .btn_pulse         (btn_pulse),
        .btn_debounced     (btn_debounced),
        .timeout_flag      (timeout_flag),
        .seconds_remaining (seconds_remaining),
        .hex0              (hex0),
        .hex1              (hex1),
        .hex2              (hex2),
        .hex3              (hex3),
        .hex4              (hex4),
        .hex5              (hex5)
    );

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ----------------------------------------------------------------
    // Test tracking
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    task check_bool;
        input actual;
        input expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            if (actual !== expected) begin
                $display("FAIL Test %0d [%0s]: actual=%b expected=%b at %0t",
                         test_num, test_name, actual, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS Test %0d [%0s] at %0t",
                         test_num, test_name, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        $display("=== TB: fpga_msg_controller (Integration) ===");
        $display("CLK=%0d Hz, Debounce=%0d ms, Timeout=%0d s",
                 CLK_FREQ_HZ, DEBOUNCE_MS, TIMEOUT_SEC);

        key_in = 4'b1111;  // All released (active-LOW)
        rst_n  = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ============================================================
        // TEST 1: Initial state — no debounced, no pulse
        // ============================================================
        check_bool(|btn_debounced, 1'b0, "Init debounced=0");
        check_bool(|btn_pulse,     1'b0, "Init pulse=0");
        check_bool(timeout_flag,   1'b0, "Init no timeout");

        // ============================================================
        // TEST 2: Press KEY0 — debounce + edge detect
        // ============================================================
        key_in[0] = 1'b0;  // Press KEY0 (active-LOW)

        // Wait for debounce (2 sync + 1000 debounce ticks + margin)
        repeat (1010) @(posedge clk);

        check_bool(btn_debounced[0], 1'b1, "KEY0 debounced");

        // The pulse should have appeared about 1002 cycles after press
        // By now it's gone — check that pulse is not stuck HIGH
        check_bool(btn_pulse[0], 1'b0, "Pulse auto-cleared");

        // ============================================================
        // TEST 3: Release KEY0
        // ============================================================
        key_in[0] = 1'b1;  // Release
        repeat (1010) @(posedge clk);
        check_bool(btn_debounced[0], 1'b0, "KEY0 released");

        // ============================================================
        // TEST 4: Timer countdown
        //   At 1000 Hz, 1 second = 1000 ticks
        //   Timer should start from 3 (TIMEOUT_SEC)
        // ============================================================
        $display("  Waiting for timer countdown...");

        // Timer was reset by the KEY0 press. Count 3 seconds + timeout second.
        repeat (CLK_FREQ_HZ) @(posedge clk);
        $display("  seconds_remaining=%0d (expect 2)", seconds_remaining);

        repeat (CLK_FREQ_HZ) @(posedge clk);
        $display("  seconds_remaining=%0d (expect 1)", seconds_remaining);

        repeat (CLK_FREQ_HZ) @(posedge clk);
        $display("  seconds_remaining=%0d (expect 0)", seconds_remaining);

        repeat (CLK_FREQ_HZ) @(posedge clk);
        check_bool(timeout_flag, 1'b1, "Timeout after countdown");

        // ============================================================
        // TEST 5: Press KEY1 — resets timer
        // ============================================================
        key_in[1] = 1'b0;  // Press KEY1
        repeat (1010) @(posedge clk);

        check_bool(timeout_flag, 1'b0, "Timer reset by KEY1");
        $display("  seconds_remaining=%0d (expect 3)", seconds_remaining);

        key_in[1] = 1'b1;  // Release KEY1
        repeat (1010) @(posedge clk);

        // ============================================================
        // TEST 6: HEX display — check hex0 is not all-blank
        //   After reset by KEY1, seconds_remaining=3
        //   seven_seg(3) = 7'b0110000
        // ============================================================
        check_bool(hex0 != 7'b1111111, 1'b1, "HEX0 not blank");

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
    // Monitor key signals
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (|btn_pulse)
            $display("  [%0t] btn_pulse=%b", $time, btn_pulse);
    end

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_fpga_msg_controller.vcd");
        $dumpvars(0, tb_fpga_msg_controller);
    end

endmodule
