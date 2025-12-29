#ifndef _LCD_LIB_H_
#define _LCD_LIB_H_

#include <stdint.h>
#include <stdbool.h>

void LCD_Init(void);
void LCD_Clear(void);
void LCD_SetStartAddr(uint8_t x, uint8_t y);
void LCD_FrameCopy(uint8_t *Data);

#endif // _LCD_LIB_H_