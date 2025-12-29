#ifndef _LCD_HW_H_
#define _LCD_HW_H_

#include <stdint.h>
#include <stdbool.h>

void LCDHW_Init(void *virtual_base);
void LCDHW_BackLight(bool bON);
void LCDHW_Write8(uint8_t bIsData, uint8_t Data);

#endif // _LCD_HW_H_