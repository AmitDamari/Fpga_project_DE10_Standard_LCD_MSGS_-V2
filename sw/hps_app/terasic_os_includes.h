#ifndef _TERASIC_OS_INCLUDE_H_
#define _TERASIC_OS_INCLUDE_H_

// Standard C Libraries
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include <math.h>
#include <stdint.h>
#include <stdbool.h>

// Type Definitions (replaces hwlib.h and socal)
typedef uint32_t alt_u32;
typedef int32_t  alt_32;
typedef uint16_t alt_u16;
typedef int16_t  alt_16;
typedef uint8_t  alt_u8;
typedef int8_t   alt_8;

// HPS Peripheral Base Addresses (replaces socal/hps.h)
#define ALT_STM_OFST        0xFC000000  // HPS Peripherals
#define ALT_LWFPGASLVS_OFST 0xFF200000  // Lightweight Bridge

// GPIO Base Addresses (replaces socal/alt_gpio.h)
#define ALT_GPIO0_OFST      0xFF708000
#define ALT_GPIO1_OFST      0xFF709000
#define ALT_GPIO2_OFST      0xFF70A000

// SPI Base Addresses (replaces socal/alt_spim.h)
#define ALT_SPIM0_OFST      0xFFF00000
#define ALT_SPIM1_OFST      0xFFF01000

#endif  //_TERASIC_OS_INCLUDE_H_