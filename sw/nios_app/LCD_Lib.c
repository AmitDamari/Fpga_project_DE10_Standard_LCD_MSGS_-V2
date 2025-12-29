// ============================================================================
// LCD_Lib.c - LCD Library for ST7565/NT7534 (Nios II Version)
// ============================================================================

#include <stdint.h>
#include "LCD_Lib.h"
#include "LCD_Driver.h"
#include "LCD_Hw.h"

void LCD_Init(void) {
    LCDHW_Init();
    LCDHW_DelayMs(100);
    
    LCDDrv_SetOuputStatusSelect(false);
    LCDDrv_SetPowerControl(0x07);
    LCDHW_DelayMs(50);
    LCDDrv_SetStartLine(0);
    LCDDrv_SetPageAddr(0);
    LCDDrv_SetColAddr(0);
    LCD_Clear();
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
        for (i = 0; i < 132; i++) {
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