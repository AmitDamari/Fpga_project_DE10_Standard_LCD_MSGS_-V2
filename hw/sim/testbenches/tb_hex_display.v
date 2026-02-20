// ============================================================================
// Testbench: tb_hex_display
// Project: DE10-Standard LCD Message System
// File: hw/sim/testbenches/tb_hex_display.v
//
// Description: Exhaustive combinational verification of hex_display module.
//   - Tests all 16 hex digit values (0x0–0xF) on all 6 display channels.
//   - Verifies active-LOW 7-segment encoding against known-good table.
//   - Verifies independence: each display channel is driven separately.
//   - Checks the blank (all-segments-off) default is unreachable via 0-F inputs.
//
// 7-segment encoding used (DE10-Standard convention):
//   hex[6:0] bit order = {g, f, e, d, c, b, a}  — bit[0]=segment_a, bit[6]=segment_g
//   active-LOW: 0 = segment ON, 1 = segment OFF
//
//   Digit |  g  f  e  d  c  b  a  | Binary    | Hex
//   ------+------------------------+-----------+------
//     0   |  1  0  0  0  0  0  0  | 7'b1000000| 0x40
//     1   |  1  1  1  1  0  0  1  | 7'b1111001| 0x79
//     2   |  0  1  0  0  1  0  0  | 7'b0100100| 0x24
//     3   |  0  1  1  0  0  0  0  | 7'b0110000| 0x30
//     4   |  0  0  1  1  0  0  1  | 7'b0011001| 0x19
//     5   |  0  0  1  0  0  1  0  | 7'b0010010| 0x12
//     6   |  0  0  0  0  0  1  0  | 7'b0000010| 0x02
//     7   |  1  1  1  1  0  0  0  | 7'b1111000| 0x78
//     8   |  0  0  0  0  0  0  0  | 7'b0000000| 0x00
//     9   |  0  0  1  0  0  0  0  | 7'b0010000| 0x10
//     A   |  0  0  0  1  0  0  0  | 7'b0001000| 0x08
//     B   |  0  0  0  0  0  1  1  | 7'b0000011| 0x03
//     C   |  1  0  0  0  1  1  0  | 7'b1000110| 0x46
//     D   |  0  1  0  0  0  0  1  | 7'b0100001| 0x21
//     E   |  0  0  0  0  1  1  0  | 7'b0000110| 0x06
//     F   |  0  0  0  1  1  1  0  | 7'b0001110| 0x0E
// ============================================================================

`timescale 1ns / 1ps

module tb_hex_display;

    // ----------------------------------------------------------------
    // DUT Signals
    // ----------------------------------------------------------------
    reg  [3:0] digit0, digit1, digit2, digit3, digit4, digit5;
    wire [6:0] hex0, hex1, hex2, hex3, hex4, hex5;

    // ----------------------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------------------
    hex_display dut (
        .digit0 (digit0),
        .digit1 (digit1),
        .digit2 (digit2),
        .digit3 (digit3),
        .digit4 (digit4),
        .digit5 (digit5),
        .hex0   (hex0),
        .hex1   (hex1),
        .hex2   (hex2),
        .hex3   (hex3),
        .hex4   (hex4),
        .hex5   (hex5)
    );

    // ----------------------------------------------------------------
    // Expected 7-segment table (all 16 hex digits)
    // Indexed by 4-bit digit value 0–15
    // ----------------------------------------------------------------
    reg [6:0] expected_seg [0:15];

    initial begin
        expected_seg[4'h0] = 7'b1000000;  // 0
        expected_seg[4'h1] = 7'b1111001;  // 1
        expected_seg[4'h2] = 7'b0100100;  // 2
        expected_seg[4'h3] = 7'b0110000;  // 3
        expected_seg[4'h4] = 7'b0011001;  // 4
        expected_seg[4'h5] = 7'b0010010;  // 5
        expected_seg[4'h6] = 7'b0000010;  // 6
        expected_seg[4'h7] = 7'b1111000;  // 7
        expected_seg[4'h8] = 7'b0000000;  // 8
        expected_seg[4'h9] = 7'b0010000;  // 9
        expected_seg[4'hA] = 7'b0001000;  // A
        expected_seg[4'hB] = 7'b0000011;  // b
        expected_seg[4'hC] = 7'b1000110;  // C
        expected_seg[4'hD] = 7'b0100001;  // d
        expected_seg[4'hE] = 7'b0000110;  // E
        expected_seg[4'hF] = 7'b0001110;  // F
    end

    // ----------------------------------------------------------------
    // Test tracking
    // ----------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;
    integer i;

    // ----------------------------------------------------------------
    // Check task: compare one segment output against expected
    // ----------------------------------------------------------------
    task check_seg;
        input [6:0]   actual;
        input [6:0]   expected;
        input [3:0]   digit_val;
        input integer display_num;
    begin
        test_num = test_num + 1;
        if (actual !== expected) begin
            $display("  FAIL Test %0d: HEX%0d digit=0x%0H  got=%b  expected=%b",
                     test_num, display_num, digit_val, actual, expected);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS Test %0d: HEX%0d digit=0x%0H  seg=%b",
                     test_num, display_num, digit_val, actual);
            pass_count = pass_count + 1;
        end
    end
    endtask

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_hex_display.vcd");
        $dumpvars(0, tb_hex_display);
    end

    // ----------------------------------------------------------------
    // Main Test Sequence
    // ----------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 0;

        // Set all unused digits to 0 initially
        digit0 = 4'h0;
        digit1 = 4'h0;
        digit2 = 4'h0;
        digit3 = 4'h0;
        digit4 = 4'h0;
        digit5 = 4'h0;

        $display("=============================================================");
        $display("          HEX DISPLAY TESTBENCH                             ");
        $display("=============================================================");

        // ================================================================
        // TEST GROUP 1: HEX0 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX0: All 16 digit values ---");
        digit1 = 4'h0; digit2 = 4'h0; digit3 = 4'h0; digit4 = 4'h0; digit5 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit0 = i[3:0];
            #10;  // Combinational — small delay for propagation
            check_seg(hex0, expected_seg[i[3:0]], i[3:0], 0);
        end

        // ================================================================
        // TEST GROUP 2: HEX1 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX1: All 16 digit values ---");
        digit0 = 4'h0; digit2 = 4'h0; digit3 = 4'h0; digit4 = 4'h0; digit5 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit1 = i[3:0];
            #10;
            check_seg(hex1, expected_seg[i[3:0]], i[3:0], 1);
        end

        // ================================================================
        // TEST GROUP 3: HEX2 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX2: All 16 digit values ---");
        digit0 = 4'h0; digit1 = 4'h0; digit3 = 4'h0; digit4 = 4'h0; digit5 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit2 = i[3:0];
            #10;
            check_seg(hex2, expected_seg[i[3:0]], i[3:0], 2);
        end

        // ================================================================
        // TEST GROUP 4: HEX3 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX3: All 16 digit values ---");
        digit0 = 4'h0; digit1 = 4'h0; digit2 = 4'h0; digit4 = 4'h0; digit5 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit3 = i[3:0];
            #10;
            check_seg(hex3, expected_seg[i[3:0]], i[3:0], 3);
        end

        // ================================================================
        // TEST GROUP 5: HEX4 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX4: All 16 digit values ---");
        digit0 = 4'h0; digit1 = 4'h0; digit2 = 4'h0; digit3 = 4'h0; digit5 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit4 = i[3:0];
            #10;
            check_seg(hex4, expected_seg[i[3:0]], i[3:0], 4);
        end

        // ================================================================
        // TEST GROUP 6: HEX5 — all 16 digit values
        // ================================================================
        $display("");
        $display("--- HEX5: All 16 digit values ---");
        digit0 = 4'h0; digit1 = 4'h0; digit2 = 4'h0; digit3 = 4'h0; digit4 = 4'h0;

        for (i = 0; i < 16; i = i + 1) begin
            digit5 = i[3:0];
            #10;
            check_seg(hex5, expected_seg[i[3:0]], i[3:0], 5);
        end

        // ================================================================
        // TEST GROUP 7: Independence — simultaneous different values
        //   Verify changing one digit does NOT affect others
        // ================================================================
        $display("");
        $display("--- Independence: simultaneous different values on all 6 channels ---");
        digit0 = 4'h0;
        digit1 = 4'h1;
        digit2 = 4'h5;
        digit3 = 4'hA;
        digit4 = 4'hF;
        digit5 = 4'h8;
        #10;

        check_seg(hex0, expected_seg[4'h0], 4'h0, 0);
        check_seg(hex1, expected_seg[4'h1], 4'h1, 1);
        check_seg(hex2, expected_seg[4'h5], 4'h5, 2);
        check_seg(hex3, expected_seg[4'hA], 4'hA, 3);
        check_seg(hex4, expected_seg[4'hF], 4'hF, 4);
        check_seg(hex5, expected_seg[4'h8], 4'h8, 5);

        // ================================================================
        // TEST GROUP 8: Verify '8' shows all segments ON (0x00 = all bits low)
        // ================================================================
        $display("");
        $display("--- Digit 8: all segments ON (all zeros in active-LOW) ---");
        digit0 = 4'h8;
        #10;
        if (hex0 === 7'b0000000) begin
            $display("  PASS: HEX0 digit=8 all segments ON (hex0=0000000)");
            pass_count = pass_count + 1;
            test_num = test_num + 1;
        end else begin
            $display("  FAIL: HEX0 digit=8 expected 0000000 got %b", hex0);
            fail_count = fail_count + 1;
            test_num = test_num + 1;
        end

        // ================================================================
        // Summary
        // ================================================================
        $display("");
        $display("=============================================================");
        $display("  Total Tests : %0d", test_num);
        $display("  Passed      : %0d", pass_count);
        $display("  Failed      : %0d", fail_count);
        $display("=============================================================");

        if (fail_count == 0) begin
            $display("  *** ALL TESTS PASSED ***");
        end else begin
            $display("  *** SOME TESTS FAILED ***");
        end

        $display("=============================================================");
        $display("");

        #10;
        $finish;
    end

endmodule
