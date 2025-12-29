// ============================================================================
// LCD_Hw.h - Hardware Abstraction Layer for Nios II
// ============================================================================

#ifndef _LCD_HW_H_
#define _LCD_HW_H_

#include <stdint.h>
#include <stdbool.h>

void LCDHW_Init(void);
void LCDHW_Write8(int is_data, uint8_t value);
void LCDHW_Reset(void);
void LCDHW_DelayUs(uint32_t us);
void LCDHW_DelayMs(uint32_t ms);

#endif // _LCD_HW_H_