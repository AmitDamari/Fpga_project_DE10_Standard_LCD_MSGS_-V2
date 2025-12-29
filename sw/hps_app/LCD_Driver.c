#include <stdint.h>
#include <stdbool.h>
#include "LCD_Driver.h"
#include "LCD_Hw.h"

#define CMD_DISPLAY_OFF         0xAE
#define CMD_DISPLAY_ON          0xAF
#define CMD_SET_START_LINE      0x40
#define CMD_SET_PAGE            0xB0
#define CMD_SET_COL_LOW         0x00
#define CMD_SET_COL_HIGH        0x10
#define CMD_OUTPUT_NORMAL       0xC0
#define CMD_OUTPUT_REVERSE      0xC8
#define CMD_POWER_CONTROL       0x28

static void LCD_WriteCmd(uint8_t cmd) {
    LCDHW_Write8(0, cmd);
}

static void LCD_WriteData(uint8_t data) {
    LCDHW_Write8(1, data);
}

void LCDDrv_Display(bool bOn) {
    LCD_WriteCmd(bOn ? CMD_DISPLAY_ON : CMD_DISPLAY_OFF);
}

void LCDDrv_SetStartLine(uint8_t StartLine) {
    LCD_WriteCmd(CMD_SET_START_LINE | (StartLine & 0x3F));
}

void LCDDrv_SetPageAddr(uint8_t PageAddr) {
    LCD_WriteCmd(CMD_SET_PAGE | (PageAddr & 0x0F));
}

void LCDDrv_SetColAddr(uint8_t ColAddr) {
    LCD_WriteCmd(CMD_SET_COL_LOW | (ColAddr & 0x0F));
    LCD_WriteCmd(CMD_SET_COL_HIGH | ((ColAddr >> 4) & 0x0F));
}

void LCDDrv_WriteData(uint8_t Data) {
    LCD_WriteData(Data);
}

void LCDDrv_WriteMultiData(uint8_t *Data, uint16_t num) {
    for (uint16_t i = 0; i < num; i++) {
        LCD_WriteData(Data[i]);
    }
}

void LCDDrv_SetOuputStatusSelect(bool bNormal) {
    LCD_WriteCmd(bNormal ? CMD_OUTPUT_NORMAL : CMD_OUTPUT_REVERSE);
}

void LCDDrv_SetPowerControl(uint8_t PowerMask) {
    LCD_WriteCmd(CMD_POWER_CONTROL | (PowerMask & 0x07));
}

void LCDDrv_SetADC(bool bNormal) {}
void LCDDrv_SetReverse(bool bNormal) {}
void LCDDrv_SetBias(bool bDefault) {}
void LCDDrv_ReadModifyWrite_Start(void) {}
void LCDDrv_ReadModifyWrite_End(void) {}
void LCDDrv_Reset(void) {}
void LCDDrv_SetOsc(bool bDefault) {}
void LCDDrv_SetResistorRatio(uint8_t Value) {}
void LCDDrv_SetOuputResistorRatio(uint8_t Value) {}