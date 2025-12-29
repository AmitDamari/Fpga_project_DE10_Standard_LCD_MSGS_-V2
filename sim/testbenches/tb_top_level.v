// ============================================================================
// top_level.v - DE10-Standard LCD Message Display System
// File: hw/rtl/top_level.v
// ============================================================================

module top_level (
    // Clock and Reset
    input wire CLOCK_50,
    input wire [3:0] KEY,           // Active low pushbuttons
    
    // LCD SPI Interface (DIRECTLY TO GPIO - DIRECTLY DIRECTLY)
    output wire LCD_SPI_CLK,
    output wire LCD_SPI_MOSI,
    output wire LCD_SPI_CS_N,
    output wire LCD_A0,
    output wire LCD_RST,
    
    // Optional: LEDs for debugging
    output wire [9:0] LEDR
);

    // ========================================
    // Internal Signals
    // ========================================
    
    wire system_clk;
    wire system_reset_n;
    
    // SPI signals from Qsys
    wire spi_clk;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs_n;
    
    // PIO signals
    wire [0:0] lcd_a0_out;
    wire [0:0] lcd_rst_out;
    wire [1:0] button_in;
    
    // Debounced buttons
    wire button_next_debounced;
    wire button_back_debounced;
    
    // ========================================
    // Clock and Reset
    // ========================================
    
    assign system_clk = CLOCK_50;
    assign system_reset_n = KEY[0];  // KEY0 as system reset
    
    // ========================================
    // Button Assignment and Debouncing
    // ========================================
    
    // Raw button inputs (directly directly directly directly)
    wire button_next_raw = ~KEY[1];  // KEY1 = NEXT (active low → active high)
    wire button_back_raw = ~KEY[2];  // KEY2 = BACK
    
    // Button debouncer for NEXT button
    button_debouncer #(
        .DEBOUNCE_TIME(1000000)  // 20ms at 50MHz
    ) debouncer_next (
        .clk(system_clk),
        .rst_n(system_reset_n),
        .button_in(button_next_raw),
        .button_out(button_next_debounced)
    );
    
    // Button debouncer for BACK button
    button_debouncer #(
        .DEBOUNCE_TIME(1000000)
    ) debouncer_back (
        .clk(system_clk),
        .rst_n(system_reset_n),
        .button_in(button_back_raw),
        .button_out(button_back_debounced)
    );
    
    // Combine debounced buttons for PIO input
    assign button_in = {button_back_debounced, button_next_debounced};
    
    // ========================================
    // Nios II System Instance
    // ========================================
    
    nios_system u_nios_system (
        // Clock and Reset
        .clk_clk(system_clk),
        .reset_reset_n(system_reset_n),
        
        // SPI LCD External
        .spi_lcd_external_MISO(1'b0),           // LCD doesn't send data back
        .spi_lcd_external_MOSI(spi_mosi),
        .spi_lcd_external_SCLK(spi_clk),
        .spi_lcd_external_SS_n(spi_cs_n),
        
        // LCD Control PIOs
        .lcd_a0_external_export(lcd_a0_out),
        .lcd_rst_external_export(lcd_rst_out),
        
        // Button PIO
        .button_external_export(button_in)
    );
    
    // ========================================
    // Output Assignments
    // ========================================
    
    assign LCD_SPI_CLK = spi_clk;
    assign LCD_SPI_MOSI = spi_mosi;
    assign LCD_SPI_CS_N = spi_cs_n;
    assign LCD_A0 = lcd_a0_out[0];
    assign LCD_RST = lcd_rst_out[0];
    
    // Debug LEDs
    assign LEDR[0] = button_next_debounced;
    assign LEDR[1] = button_back_debounced;
    assign LEDR[9:2] = 8'b0;

endmodule