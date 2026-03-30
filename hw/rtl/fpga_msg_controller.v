// ============================================================================
// Module: fpga_msg_controller
// Project: DE10-Standard LCD Message System
// Description: Top-level FPGA wrapper that integrates all custom modules:
//              - button_debouncer (50ms, 4-channel)
//              - button_edge_detector (rising-edge pulse)
//              - idle_timer (15s countdown)
//              - hex_display (7-seg decoder for HEX0-5)
//
//              Outputs are exposed as conduit signals for connection to
//              Avalon PIOs in Platform Designer (Qsys), readable by HPS
//              via the Lightweight H2F bridge.
// ============================================================================

module fpga_msg_controller #(
    parameter CLK_FREQ_HZ  = 50_000_000,
    parameter DEBOUNCE_MS  = 50,
    parameter TIMEOUT_SEC  = 15,
    parameter NUM_BUTTONS  = 4
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // ---- Button inputs (active-LOW from KEY pins) ----
    input  wire [NUM_BUTTONS-1:0]  key_in,

    // ---- Outputs to PIO conduit exports (readable by HPS) ----
    output wire [NUM_BUTTONS-1:0]  btn_pulse,         // Single-cycle press events
    output wire [NUM_BUTTONS-1:0]  btn_debounced,     // Current debounced levels
    output wire                    timeout_flag,       // Idle timer expired
    output wire [3:0]              seconds_remaining,  // BCD countdown for display
    output wire [2:0]              fsm_state,          // Verilog UI FSM state
    output wire [4:0]              fsm_msg_index,      // Verilog UI FSM message index

    // ---- HEX display outputs (active-LOW 7-segment) ----
    output wire [6:0]              hex0,
    output wire [6:0]              hex1,
    output wire [6:0]              hex2,
    output wire [6:0]              hex3,
    output wire [6:0]              hex4,
    output wire [6:0]              hex5
);

    // ================================================================
    // Stage 1: Button Debouncing
    // ================================================================
    button_debouncer #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .DEBOUNCE_MS (DEBOUNCE_MS),
        .NUM_BUTTONS (NUM_BUTTONS)
    ) u_debouncer (
        .clk     (clk),
        .rst_n   (rst_n),
        .btn_in  (key_in),
        .btn_out (btn_debounced)
    );

    // ================================================================
    // Stage 2: Edge Detection (single-cycle pulse per press)
    // ================================================================
    button_edge_detector #(
        .NUM_BUTTONS (NUM_BUTTONS)
    ) u_edge_det (
        .clk           (clk),
        .rst_n         (rst_n),
        .btn_debounced (btn_debounced),
        .btn_pulse     (btn_pulse)
    );

    // ================================================================
    // Stage 3: Idle Timer (15-second countdown)
    //   reset_timer: any button press restarts the countdown
    //   enable:      always enabled (HPS FSM can ignore timeout if needed)
    // ================================================================
    wire any_btn_pulse;
    assign any_btn_pulse = |btn_pulse;

    idle_timer #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .TIMEOUT_SEC (TIMEOUT_SEC)
    ) u_timer (
        .clk               (clk),
        .rst_n             (rst_n),
        .reset_timer       (any_btn_pulse),
        .enable            (1'b1),
        .timeout           (timeout_flag),
        .seconds_remaining (seconds_remaining)
    );

    // ================================================================
    // Stage 4: Verilog UI FSM (project-critical control logic)
    // ================================================================
    message_fsm #(
        .MSG_COUNT (18),
        .INDEX_W   (5)
    ) u_message_fsm (
        .clk         (clk),
        .rst_n       (rst_n),
        .btn_pulse   (btn_pulse),
        .timeout_flag(timeout_flag),
        .state       (fsm_state),
        .msg_index   (fsm_msg_index)
    );

    // ================================================================
    // Stage 5: HEX Display
    //   HEX0: Timer countdown (0–F seconds)
    //   HEX1: Last button pressed (0–3, F=none)
    //   HEX2: Timeout status (0=running, 1=expired)
    //   HEX3-5: Reserved (show 0)
    // ================================================================
    // Encode which button was last pressed (priority: KEY0 > KEY1 > KEY2 > KEY3)
    reg [3:0] last_btn_display;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            last_btn_display <= 4'hF;
        else if (btn_pulse[0])
            last_btn_display <= 4'd0;
        else if (btn_pulse[1])
            last_btn_display <= 4'd1;
        else if (btn_pulse[2])
            last_btn_display <= 4'd2;
        else if (btn_pulse[3])
            last_btn_display <= 4'd3;
        // else: hold last value
    end

    hex_display u_hex (
        .digit0 (seconds_remaining),       // HEX0: timer countdown
        .digit1 (last_btn_display),         // HEX1: last button (F=none)
        .digit2 ({3'b0, timeout_flag}),     // HEX2: timeout status
        .digit3 (4'h0),                     // HEX3: reserved
        .digit4 (4'h0),                     // HEX4: reserved
        .digit5 (4'h0),                     // HEX5: reserved
        .hex0   (hex0),
        .hex1   (hex1),
        .hex2   (hex2),
        .hex3   (hex3),
        .hex4   (hex4),
        .hex5   (hex5)
    );

endmodule
