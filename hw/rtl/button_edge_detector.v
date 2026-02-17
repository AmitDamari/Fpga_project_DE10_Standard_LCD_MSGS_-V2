// ============================================================================
// Module: button_edge_detector
// Project: DE10-Standard LCD Message System
// Description: Detects rising edges on debounced button signals.
//              Produces a single clock-cycle pulse per button press event.
//              Prevents repeated triggers when a button is held down.
// ============================================================================

module button_edge_detector #(
    parameter NUM_BUTTONS = 4
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [NUM_BUTTONS-1:0]  btn_debounced,  // Stable, active-HIGH
    output wire [NUM_BUTTONS-1:0]  btn_pulse        // Single-cycle rising edge
);

    // ----------------------------------------------------------------
    // Previous-state register
    // ----------------------------------------------------------------
    reg [NUM_BUTTONS-1:0] btn_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            btn_prev <= {NUM_BUTTONS{1'b0}};
        else
            btn_prev <= btn_debounced;
    end

    // ----------------------------------------------------------------
    // Rising edge detection: was 0 last cycle, is 1 this cycle
    // ----------------------------------------------------------------
    assign btn_pulse = btn_debounced & ~btn_prev;

endmodule
