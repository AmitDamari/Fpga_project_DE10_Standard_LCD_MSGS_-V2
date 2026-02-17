// ============================================================================
// Module: idle_timer
// Project: DE10-Standard LCD Message System
// Description: Countdown timer with 1-second granularity.
//              Counts down from TIMEOUT_SEC (default 15) to 0.
//              Asserts 'timeout' flag when countdown reaches zero.
//              'reset_timer' input restarts the countdown (e.g., on button press).
//              'seconds_remaining' output drives HEX display.
// Default: 15 seconds at 50 MHz
// ============================================================================

module idle_timer #(
    parameter CLK_FREQ_HZ  = 50_000_000,  // System clock frequency
    parameter TIMEOUT_SEC  = 15            // Countdown duration in seconds
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        reset_timer,         // Pulse HIGH to restart countdown
    input  wire        enable,              // Timer counts only when enabled
    output reg         timeout,             // HIGH when countdown expired
    output reg  [3:0]  seconds_remaining    // BCD countdown 0–15 for HEX display
);

    // ----------------------------------------------------------------
    // Derived parameters
    // ----------------------------------------------------------------
    localparam ONE_SEC_TICKS = CLK_FREQ_HZ;                   // 50,000,000
    localparam TICK_CNT_W    = $clog2(ONE_SEC_TICKS + 1);     // 26 bits
    localparam SEC_CNT_W     = $clog2(TIMEOUT_SEC + 1);       // 4 bits for 15

    // ----------------------------------------------------------------
    // Internal registers
    // ----------------------------------------------------------------
    reg [TICK_CNT_W-1:0] tick_counter;   // Sub-second tick counter
    reg [SEC_CNT_W-1:0]  sec_counter;    // Seconds remaining (internal, full width)

    // ----------------------------------------------------------------
    // Main countdown logic
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Hardware reset — initialize all to starting values
            tick_counter      <= {TICK_CNT_W{1'b0}};
            sec_counter       <= TIMEOUT_SEC[SEC_CNT_W-1:0];
            timeout           <= 1'b0;
            seconds_remaining <= TIMEOUT_SEC[3:0];
        end else if (reset_timer) begin
            // Button press — restart countdown
            tick_counter      <= {TICK_CNT_W{1'b0}};
            sec_counter       <= TIMEOUT_SEC[SEC_CNT_W-1:0];
            timeout           <= 1'b0;
            seconds_remaining <= TIMEOUT_SEC[3:0];
        end else if (enable && !timeout) begin
            // Active countdown
            if (tick_counter == ONE_SEC_TICKS - 1) begin
                tick_counter <= {TICK_CNT_W{1'b0}};
                if (sec_counter <= 1) begin
                    // Timer expired (transition from 1→0 or already 0)
                    timeout           <= 1'b1;
                    sec_counter       <= {SEC_CNT_W{1'b0}};
                    seconds_remaining <= 4'd0;
                end else begin
                    sec_counter       <= sec_counter - 1'b1;
                    seconds_remaining <= sec_counter[3:0] - 4'd1;
                end
            end else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
        // If !enable or timeout already asserted: hold state (do nothing)
    end

endmodule
