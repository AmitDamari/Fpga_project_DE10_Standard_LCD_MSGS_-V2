// ============================================================================
// LCD_Lib.c - LCD Library for ST7565/NT7534 (Nios II Version)
// ============================================================================

#include <stdint.h>        // ADD: for uint8_t
#include "LCD_Lib.h"
#include "LCD_Driver.h"
#include "LCD_Hw.h"        // ADD: for LCDHW_Init, LCDHW_DelayMs

void LCD_Init(void) {
    
    // ADD: Hardware initialization first
    LCDHW_Init();          // Initialize SPI, GPIO pins, and reset LCD
    LCDHW_DelayMs(100);    // Wait for LCD to stabilize after reset
    
    // Common output state selection (~normal)
    LCDDrv_SetOuputStatusSelect(false); // invert to match mechanism
    
    // Power control register (D2, D1, D0) = (follower, regulator, booster) = (1, 1, 1)
    LCDDrv_SetPowerControl(0x07);

    // ADD: Recommended initialization sequence for ST7565
    LCDHW_DelayMs(50);     // Wait for power to stabilize
    
    // Set display start line: at first line
    LCDDrv_SetStartLine(0);

    // Page address register set at page 0
    LCDDrv_SetPageAddr(0);
    
    // Column address counter set at address 0
    LCDDrv_SetColAddr(0);
    
    // Clear display before turning on (prevents garbage)
    LCD_Clear();           // ADD: Clear before display on
    
    // Display on
    LCDDrv_Display(true);
}

void LCD_SetStartAddr(uint8_t x, uint8_t y) {
    LCDDrv_SetPageAddr(y / 8);
    LCDDrv_SetColAddr(x);
}

void LCD_Clear(void) {
    int Page, i;
    for (Page = 0; Page < 8; Page++) {
        LCDDrv_SetPageAddr(Page);
        LCDDrv_SetColAddr(0);
        for (i = 0; i < 132; i++) {    // 132 to cover full internal RAM
            LCDDrv_WriteData(0x00);
        }    
    }
}

void LCD_FrameCopy(uint8_t *Data) {
    int Page;
    uint8_t *pPageData = Data;
    
    for (Page = 0; Page < 8; Page++) {
        LCD_SetStartAddr(0, Page * 8);
        LCDDrv_WriteMultiData(pPageData, 128);
        pPageData += 128;
    }   	
}