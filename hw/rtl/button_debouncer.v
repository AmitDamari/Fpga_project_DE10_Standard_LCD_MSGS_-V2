//=============================================================================
// Module: button_debouncer
// Description: Debounces a mechanical button input with metastability protection
//              using a 2-FF synchronizer and a counter-based stability check.
//=============================================================================

module button_debouncer #(
    parameter CLK_FREQ    = 50_000_000,  // Clock frequency in Hz (default: 50 MHz)
    parameter DEBOUNCE_MS = 50           // Debounce time in milliseconds (default: 50 ms)
)(
    input  wire clk,      // System clock
    input  wire rst_n,    // Active-low asynchronous reset
    input  wire btn_in,   // Raw button input (from physical pin)
    output reg  btn_out   // Debounced button output
);

    //=========================================================================
    // Local Parameters
    //=========================================================================
    
    // Calculate the maximum count value for debounce timing
    // COUNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS
    localparam COUNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS;
    
    // Calculate required counter width: ceil(log2(COUNT_MAX + 1))
    // For 50MHz and 50ms: COUNT_MAX = 2,500,000 -> need 22 bits
    localparam COUNTER_WIDTH = $clog2(COUNT_MAX + 1);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // 2-FF Synchronizer for metastability protection
    reg btn_sync_0;  // First stage of synchronizer
    reg btn_sync_1;  // Second stage of synchronizer (synchronized input)
    
    // Stability counter
    reg [COUNTER_WIDTH-1:0] counter;

    //=========================================================================
    // 2-FF Synchronizer
    // Protects against metastability when sampling asynchronous button input
    //=========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end
        else begin
            btn_sync_0 <= btn_in;      // First stage: capture raw input
            btn_sync_1 <= btn_sync_0;  // Second stage: stable synchronized value
        end
    end

    //=========================================================================
    // Debounce Counter Logic
    // Counts how long the synchronized input differs from current output
    //=========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {COUNTER_WIDTH{1'b0}};
            btn_out <= 1'b0;
        end
        else begin
            // Check if synchronized input differs from current output
            if (btn_sync_1 != btn_out) begin
                // Input is different - increment counter
                if (counter == COUNT_MAX) begin
                    // Counter reached maximum - input has been stable long enough
                    // Update output to match synchronized input
                    btn_out <= btn_sync_1;
                    counter <= {COUNTER_WIDTH{1'b0}};  // Reset counter
                end
                else begin
                    // Keep counting
                    counter <= counter + 1'b1;
                end
            end
            else begin
                // Input matches output - reset counter
                counter <= {COUNTER_WIDTH{1'b0}};
            end
        end
    end

endmodule