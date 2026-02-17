// ============================================================================
// Module: hex_display
// Project: DE10-Standard LCD Message System
// Description: Combinational BCD-to-7-segment decoder for 6 HEX displays.
//              Outputs are active-LOW (0 = segment ON, 1 = segment OFF).
//              Supports hex digits 0–F.
//
//              Segment mapping:
//                 --a--
//                |     |
//                f     b
//                |     |
//                 --g--
//                |     |
//                e     c
//                |     |
//                 --d--
//
//              hex[6:0] = {a, b, c, d, e, f, g}   (active-LOW, position 6=a)
//              Alternatively: hex[6:0] = {g, f, e, d, c, b, a  } depending on
//              DE10 standard convention. Here we use: hex = {a,b,c,d,e,f,g}
//              with bit[6]=segment_a ... bit[0]=segment_g
// ============================================================================

module hex_display (
    input  wire [3:0]  digit0,   // HEX0 value (rightmost)
    input  wire [3:0]  digit1,   // HEX1 value
    input  wire [3:0]  digit2,   // HEX2 value
    input  wire [3:0]  digit3,   // HEX3 value
    input  wire [3:0]  digit4,   // HEX4 value
    input  wire [3:0]  digit5,   // HEX5 value (leftmost)
    output wire [6:0]  hex0,     // 7-seg output for HEX0
    output wire [6:0]  hex1,     // 7-seg output for HEX1
    output wire [6:0]  hex2,     // 7-seg output for HEX2
    output wire [6:0]  hex3,     // 7-seg output for HEX3
    output wire [6:0]  hex4,     // 7-seg output for HEX4
    output wire [6:0]  hex5      // 7-seg output for HEX5
);

    // ----------------------------------------------------------------
    // 7-segment decoder function (active-LOW)
    // ----------------------------------------------------------------
    function [6:0] seven_seg;
        input [3:0] val;
        case (val)
            //                   abcdefg
            4'h0: seven_seg = 7'b1000000;  // 0
            4'h1: seven_seg = 7'b1111001;  // 1
            4'h2: seven_seg = 7'b0100100;  // 2
            4'h3: seven_seg = 7'b0110000;  // 3
            4'h4: seven_seg = 7'b0011001;  // 4
            4'h5: seven_seg = 7'b0010010;  // 5
            4'h6: seven_seg = 7'b0000010;  // 6
            4'h7: seven_seg = 7'b1111000;  // 7
            4'h8: seven_seg = 7'b0000000;  // 8
            4'h9: seven_seg = 7'b0010000;  // 9
            4'hA: seven_seg = 7'b0001000;  // A
            4'hB: seven_seg = 7'b0000011;  // b
            4'hC: seven_seg = 7'b1000110;  // C
            4'hD: seven_seg = 7'b0100001;  // d
            4'hE: seven_seg = 7'b0000110;  // E
            4'hF: seven_seg = 7'b0001110;  // F
            default: seven_seg = 7'b1111111; // blank
        endcase
    endfunction

    // ----------------------------------------------------------------
    // Drive all 6 displays
    // ----------------------------------------------------------------
    assign hex0 = seven_seg(digit0);
    assign hex1 = seven_seg(digit1);
    assign hex2 = seven_seg(digit2);
    assign hex3 = seven_seg(digit3);
    assign hex4 = seven_seg(digit4);
    assign hex5 = seven_seg(digit5);

endmodule
