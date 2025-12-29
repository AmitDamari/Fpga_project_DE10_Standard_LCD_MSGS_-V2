#include <stdint.h>
#include <stdbool.h>
#include "LCD_Lib.h"
#include "LCD_Driver.h"

void LCD_Init(void) {
    LCDDrv_SetOuputStatusSelect(false);
    LCDDrv_SetPowerControl(0x07);
    LCDDrv_SetStartLine(0);
    LCDDrv_SetPageAddr(0);
    LCDDrv_SetColAddr(0);
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