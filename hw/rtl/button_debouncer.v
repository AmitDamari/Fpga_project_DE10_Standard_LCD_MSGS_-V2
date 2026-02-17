// ============================================================================
// Module: button_debouncer
// Project: DE10-Standard LCD Message System
// Description: Parameterized multi-channel button debouncer with 2-FF
//              synchronizer for metastability protection.
//              Input: active-LOW buttons (DE10-Standard KEY pins)
//              Output: active-HIGH debounced signals
// Default: 50ms debounce at 50 MHz clock
// ============================================================================

module button_debouncer #(
    parameter CLK_FREQ_HZ  = 50_000_000,  // System clock frequency
    parameter DEBOUNCE_MS  = 50,           // Debounce settling time in ms
    parameter NUM_BUTTONS  = 4             // Number of button channels
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [NUM_BUTTONS-1:0]  btn_in,    // Raw buttons, active-LOW
    output reg  [NUM_BUTTONS-1:0]  btn_out    // Debounced output, active-HIGH
);

    // ----------------------------------------------------------------
    // Derived parameters
    // ----------------------------------------------------------------
    // DEBOUNCE_TICKS = CLK_FREQ_HZ * DEBOUNCE_MS / 1000
    // For 50 MHz, 50 ms: 50_000_000 * 50 / 1000 = 2_500_000
    localparam DEBOUNCE_TICKS = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam CNT_WIDTH      = $clog2(DEBOUNCE_TICKS + 1);  // 22 bits for default

    // ----------------------------------------------------------------
    // 2-FF Synchronizer — prevents metastability
    // Also inverts active-LOW to active-HIGH
    // ----------------------------------------------------------------
    reg [NUM_BUTTONS-1:0] btn_sync_r1;
    reg [NUM_BUTTONS-1:0] btn_sync_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_r1 <= {NUM_BUTTONS{1'b0}};
            btn_sync_r2 <= {NUM_BUTTONS{1'b0}};
        end else begin
            btn_sync_r1 <= ~btn_in;       // Stage 1: invert active-LOW → active-HIGH
            btn_sync_r2 <= btn_sync_r1;   // Stage 2: stable synchronized input
        end
    end

    // ----------------------------------------------------------------
    // Per-button debounce counters (generate block)
    // Output changes only after input has been stable for DEBOUNCE_TICKS
    // ----------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_BUTTONS; g = g + 1) begin : gen_debounce
            reg [CNT_WIDTH-1:0] counter;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    counter    <= {CNT_WIDTH{1'b0}};
                    btn_out[g] <= 1'b0;
                end else begin
                    if (btn_sync_r2[g] != btn_out[g]) begin
                        // Input differs from current output — count stability
                        if (counter == DEBOUNCE_TICKS - 1) begin
                            btn_out[g] <= btn_sync_r2[g];  // Accept new state
                            counter    <= {CNT_WIDTH{1'b0}};
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end else begin
                        // Input matches output — reset counter
                        counter <= {CNT_WIDTH{1'b0}};
                    end
                end
            end
        end
    endgenerate

endmodule
