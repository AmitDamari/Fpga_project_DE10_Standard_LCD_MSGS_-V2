#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdbool.h>
#include "LCD_Hw.h"

#define HW_REGS_SPAN           0x04000000
#define HW_REGS_MASK           (HW_REGS_SPAN - 1)

#define GPIO1_BASE_OFFSET      0x03709000
#define GPIO_SWPORTA_DR        0x00
#define GPIO_SWPORTA_DDR       0x04

#define SPIM0_BASE_OFFSET      0x03F00000
#define SPIM_CTLR0             0x00
#define SPIM_SSIENR            0x08
#define SPIM_SER               0x10
#define SPIM_BAUDR             0x14
#define SPIM_SR                0x28
#define SPIM_DR                0x60

#define RSTMGR_BASE_OFFSET     0x03D05000
#define RSTMGR_PERMODRST       0x14

#define HPS_LCM_D_C_BIT        (0x00001000)
#define HPS_LCM_RESETn_BIT     (0x00008000)
#define HPS_LCM_BACKLIGHT_BIT  (0x00000100)

#define alt_read_word(addr)        (*(volatile uint32_t *)(addr))
#define alt_write_word(addr, val)  (*(volatile uint32_t *)(addr) = (val))
#define alt_setbits_word(addr, bits) (*(volatile uint32_t *)(addr) |= (bits))
#define alt_clrbits_word(addr, bits) (*(volatile uint32_t *)(addr) &= ~(bits))

static void *lcd_virtual_base = NULL;

void LCDHW_Init(void *virtual_base) {
    lcd_virtual_base = virtual_base;
    
    uint32_t gpio1_addr = (uint32_t)virtual_base + GPIO1_BASE_OFFSET;
    uint32_t spim0_addr = (uint32_t)virtual_base + SPIM0_BASE_OFFSET;
    uint32_t rstmgr_addr = (uint32_t)virtual_base + RSTMGR_BASE_OFFSET;

    printf("LCDHW_Init: Base=%p\n", virtual_base);

    alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DDR, HPS_LCM_RESETn_BIT);
    alt_clrbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_RESETn_BIT);
    usleep(10000);
    alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_RESETn_BIT);
    usleep(10000);

    alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DDR, HPS_LCM_BACKLIGHT_BIT);
    alt_clrbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_BACKLIGHT_BIT);

    alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DDR, HPS_LCM_D_C_BIT);
    alt_clrbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_D_C_BIT);

    alt_clrbits_word(rstmgr_addr + RSTMGR_PERMODRST, 0x00040000);
    alt_clrbits_word(spim0_addr + SPIM_SSIENR, 1);

    uint32_t ctrl0 = alt_read_word(spim0_addr + SPIM_CTLR0);
    ctrl0 &= ~(0x3 << 8);
    ctrl0 |= (1 << 8);
    alt_write_word(spim0_addr + SPIM_CTLR0, ctrl0);

    alt_write_word(spim0_addr + SPIM_BAUDR, 64);
    alt_write_word(spim0_addr + SPIM_SER, 1);
    alt_setbits_word(spim0_addr + SPIM_SSIENR, 1);

    printf("LCD Hardware Initialized.\n");
}

void LCDHW_BackLight(bool bON) {
    if (!lcd_virtual_base) return;
    uint32_t gpio1_addr = (uint32_t)lcd_virtual_base + GPIO1_BASE_OFFSET;

    if (bON)
        alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_BACKLIGHT_BIT);
    else
        alt_clrbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_BACKLIGHT_BIT);
}

static void SPIM_WriteTxData(uint8_t Data) {
    uint32_t spim0_addr = (uint32_t)lcd_virtual_base + SPIM0_BASE_OFFSET;

    while (!(alt_read_word(spim0_addr + SPIM_SR) & 0x4));
    alt_write_word(spim0_addr + SPIM_DR, Data);
    while (!(alt_read_word(spim0_addr + SPIM_SR) & 0x4));
    while (alt_read_word(spim0_addr + SPIM_SR) & 0x1);
}

static void PIO_DC_Set(bool bIsData) {
    uint32_t gpio1_addr = (uint32_t)lcd_virtual_base + GPIO1_BASE_OFFSET;

    if (bIsData)
        alt_setbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_D_C_BIT);
    else
        alt_clrbits_word(gpio1_addr + GPIO_SWPORTA_DR, HPS_LCM_D_C_BIT);
}

void LCDHW_Write8(uint8_t bIsData, uint8_t Data) {
    static uint8_t bPreIsData = 0xFF;
    if (bPreIsData != bIsData) {
        PIO_DC_Set(bIsData);
        bPreIsData = bIsData;
    }
    SPIM_WriteTxData(Data);
}