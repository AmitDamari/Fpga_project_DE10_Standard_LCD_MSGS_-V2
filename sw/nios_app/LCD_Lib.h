// ============================================================================
// LCD_Lib.h - LCD Library for ST7565/NT7534 (Nios II Version)
// ============================================================================

#ifndef _LCD_LIB_H_
#define _LCD_LIB_H_

#include <stdint.h>      // ADD: for uint8_t
#include "LCD_Hw.h"

#define LCD_WIDTH     128
#define LCD_HEIGHT    64

// Initialize LCD (call LCDHW_Init first!)
void LCD_Init(void);

// Set starting address for write
void LCD_SetStartAddr(uint8_t x, uint8_t y);

// Clear entire LCD
void LCD_Clear(void);    // ADD: was missing from original .h!

// Copy frame buffer to LCD
void LCD_FrameCopy(uint8_t *Data);

#endif // _LCD_LIB_H_