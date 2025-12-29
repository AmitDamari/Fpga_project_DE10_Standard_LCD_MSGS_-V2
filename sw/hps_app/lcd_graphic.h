#ifndef _LCD_GRAPHIC_H_
#define _LCD_GRAPHIC_H_

#include <stdint.h>
#include <stdbool.h>
#include "font.h"

typedef struct {
    int Width;
    int Height;
    int FrameSize;
    uint8_t *pFrame;
} LCD_CANVAS;

void DRAW_Pixel(LCD_CANVAS *pCanvas, int X, int Y, int Color);
void DRAW_Refresh(LCD_CANVAS *pCanvas);
void DRAW_Line(LCD_CANVAS *pCanvas, int X1, int Y1, int X2, int Y2, int Color);
void DRAW_Rect(LCD_CANVAS *pCanvas, int X1, int Y1, int X2, int Y2, int Color);
void DRAW_Circle(LCD_CANVAS *pCanvas, int x0, int y0, int Radius, int Color);
void DRAW_Clear(LCD_CANVAS *pCanvas, int nValue);
void DRAW_PrintChar(LCD_CANVAS *pCanvas, int X0, int Y0, char Text, int Color, FONT_TABLE *font_table);
void DRAW_PrintString(LCD_CANVAS *pCanvas, int X0, int Y0, char *pText, int Color, FONT_TABLE *font_table);

void LCD_TextOut(int x, int y, char *text);
void LCD_GraphicClear(void);

#endif // _LCD_GRAPHIC_H_