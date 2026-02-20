`timescale 1ns/1ps
module debug_tb;
    localparam NUM_BUTTONS = 4;
    localparam CLK_PERIOD  = 20;
    reg clk, rst_n;
    reg  [NUM_BUTTONS-1:0] btn_debounced;
    wire [NUM_BUTTONS-1:0] btn_pulse;
    button_edge_detector #(.NUM_BUTTONS(NUM_BUTTONS)) dut (
        .clk(clk), .rst_n(rst_n),
        .btn_debounced(btn_debounced), .btn_pulse(btn_pulse)
    );
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    initial begin
        btn_debounced = 0; rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1;
        $display("t=%0t  btn_debounced=%b  btn_prev=%b  btn_pulse=%b  (BEFORE set)",
                  $time, btn_debounced, dut.btn_prev, btn_pulse);
        btn_debounced[0] = 1;
        $display("t=%0t  btn_debounced=%b  btn_prev=%b  btn_pulse=%b  (AFTER set)",
                  $time, btn_debounced, dut.btn_prev, btn_pulse);
        #1;
        $display("t=%0t  btn_debounced=%b  btn_prev=%b  btn_pulse=%b  (after #1 more)",
                  $time, btn_debounced, dut.btn_prev, btn_pulse);
        $finish;
    end
endmodule
