// ============================================================================
// Testbench: tb_button_edge_detector
// Project: DE10-Standard LCD Message System
// Description: Verifies the button_edge_detector module with:
//   1. Single pulse on rising edge
//   2. Held button produces only 1 pulse
//   3. Quick re-press produces 2 separate pulses
//   4. Multi-button simultaneous edge
//   5. Reset behavior
// ============================================================================

`timescale 1ns / 1ps

module tb_button_edge_detector;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam NUM_BUTTONS = 4;
    localparam CLK_PERIOD  = 20;  // 50 MHz → 20 ns period

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg  [NUM_BUTTONS-1:0] btn_debounced;
    wire [NUM_BUTTONS-1:0] btn_pulse;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    button_edge_detector #(
        .NUM_BUTTONS(NUM_BUTTONS)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .btn_debounced (btn_debounced),
        .btn_pulse     (btn_pulse)
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

    task check;
        input [NUM_BUTTONS-1:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            if (btn_pulse !== expected) begin
                $display("FAIL Test %0d [%0s]: Expected=%b, Got=%b at time %0t",
                         test_num, test_name, expected, btn_pulse, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS Test %0d [%0s]: btn_pulse=%b at time %0t",
                         test_num, test_name, btn_pulse, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        $display("=== TB: button_edge_detector ===");

        btn_debounced = 4'b0000;
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ============================================================
        // TEST 1: Rising edge on button 0 → single pulse
        // ============================================================
        btn_debounced[0] = 1'b1;
        @(posedge clk);  // Pulse appears after this edge
        #1;              // Small delay to let combinational settle
        check(4'b0001, "Rising edge BTN0");

        // ============================================================
        // TEST 2: Held button — next cycle should show NO pulse
        // ============================================================
        @(posedge clk);
        #1;
        check(4'b0000, "Held BTN0 no pulse");

        // ============================================================
        // TEST 3: Continue holding — still no pulse
        // ============================================================
        repeat (10) @(posedge clk);
        #1;
        check(4'b0000, "Still held no pulse");

        // ============================================================
        // TEST 4: Release button 0
        // ============================================================
        btn_debounced[0] = 1'b0;
        @(posedge clk);
        #1;
        check(4'b0000, "Release BTN0");

        // ============================================================
        // TEST 5: Re-press → second pulse
        // ============================================================
        @(posedge clk);
        btn_debounced[0] = 1'b1;
        @(posedge clk);
        #1;
        check(4'b0001, "Re-press BTN0");

        btn_debounced[0] = 1'b0;
        @(posedge clk);
        #1;

        // ============================================================
        // TEST 6: Multi-button simultaneous rising edge
        // ============================================================
        btn_debounced = 4'b0000;
        @(posedge clk);

        btn_debounced = 4'b1010;  // BTN1 + BTN3 pressed
        @(posedge clk);
        #1;
        check(4'b1010, "Multi BTN1+BTN3");

        @(posedge clk);
        #1;
        check(4'b0000, "Multi held no pulse");

        // ============================================================
        // TEST 7: Reset during active button
        // ============================================================
        btn_debounced = 4'b0100;  // BTN2 pressed
        @(posedge clk);
        #1;
        // Should see pulse
        check(4'b0100, "BTN2 pulse before reset");

        rst_n = 1'b0;
        @(posedge clk);
        #1;
        check(4'b0000, "Reset clears pulse");

        rst_n = 1'b1;
        btn_debounced = 4'b0000;
        @(posedge clk);

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
        $dumpfile("tb_button_edge_detector.vcd");
        $dumpvars(0, tb_button_edge_detector);
    end

endmodule
