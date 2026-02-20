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
    // TIMING RULE for this TB:
    //   btn_pulse is a COMBINATIONAL output: btn_debounced & ~btn_prev
    //   btn_prev is a registered signal updated via NBA at posedge clk.
    //
    //   SAFE PATTERN: always use "@(posedge clk); #1;" together.
    //   The #1 delay (1 ns) advances past the NBA update region, so
    //   btn_prev is fully settled before we set or check any signal.
    //   Input changes made in this settled zone are captured at the
    //   NEXT posedge cleanly, with no race conditions.
    // ----------------------------------------------------------------
    initial begin
        $display("=== TB: button_edge_detector ===");

        btn_debounced = 4'b0000;
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk); #1;  // Settle NBA (btn_prev→0), now in safe zone

        // ============================================================
        // TEST 1: Rising edge on button 0 → single pulse
        //   Pattern: set input → #1 (delta flush) → check → @posedge (capture)
        //   The #1 is required because 'assign btn_pulse = btn_debounced & ~btn_prev'
        //   is a continuous assignment that re-evaluates in the NEXT delta cycle
        //   after btn_debounced changes. Without #1, btn_pulse is still 0.
        // ============================================================
        btn_debounced[0] = 1'b1;
        #1;  // Let continuous assignment delta-propagate
        check(4'b0001, "Rising edge BTN0");

        // ============================================================
        // TEST 2: Held button — next cycle should show NO pulse
        //   @posedge: btn_prev captures btn_debounced=1 → pulse disappears
        // ============================================================
        @(posedge clk); #1;
        check(4'b0000, "Held BTN0 no pulse");

        // ============================================================
        // TEST 3: Continue holding — still no pulse
        // ============================================================
        repeat (10) @(posedge clk);
        #1;
        check(4'b0000, "Still held no pulse");

        // ============================================================
        // TEST 4: Release button 0
        //   Falling edge: no pulse (edge detector only detects rising)
        // ============================================================
        btn_debounced[0] = 1'b0;
        @(posedge clk); #1;  // btn_prev captures 0 → settled
        check(4'b0000, "Release BTN0");

        // ============================================================
        // TEST 5: Re-press → second pulse
        //   btn_prev=0 (settled after Test 4 posedge + #1)
        // ============================================================
        btn_debounced[0] = 1'b1;
        #1;  // Delta flush for continuous assign
        check(4'b0001, "Re-press BTN0");

        // ============================================================
        // TEST 6: Multi-button simultaneous rising edge
        //   Release BTN0, let posedge settle btn_prev=0, then press multi
        // ============================================================
        @(posedge clk); #1;   // btn_prev captures 1 (Re-press)
        btn_debounced[0] = 1'b0;  // Release BTN0
        @(posedge clk); #1;   // btn_prev captures 0 → settled

        btn_debounced = 4'b1010;  // BTN1+BTN3: btn_prev=0 → pulse=1010
        #1;  // Delta flush
        check(4'b1010, "Multi BTN1+BTN3");

        // ============================================================
        // TEST 7: Multi held — no pulse
        // ============================================================
        @(posedge clk); #1;   // btn_prev captures 1010
        check(4'b0000, "Multi held no pulse");

        // ============================================================
        // TEST 8: BTN2 rising edge during multi-hold state
        //   btn_prev=1010. Set btn_debounced=0100 → pulse = 0100 & ~1010
        //                                                  = 0100 & 0101 = 0100
        // ============================================================
        btn_debounced = 4'b0100;
        #1;  // Delta flush
        check(4'b0100, "BTN2 pulse before reset");

        // ============================================================
        // TEST 9: Reset clears btn_prev
        //   Release all buttons, apply async reset → btn_prev→0 immediately
        // ============================================================
        @(posedge clk); #1;   // btn_prev captures 0100
        btn_debounced = 4'b0000;  // Release all
        rst_n = 1'b0;             // Async reset → btn_prev→0
        #1;  // Let async reset propagate
        check(4'b0000, "Reset clears pulse");

        @(posedge clk); #1;
        rst_n = 1'b1;
        @(posedge clk); #1;

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
