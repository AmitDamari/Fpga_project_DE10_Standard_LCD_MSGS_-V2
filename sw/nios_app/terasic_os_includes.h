// ============================================================================
// terasic_os_includes.h - Nios II Version for DE10-Standard
// Replaces HPS version with Nios II compatible includes
// ============================================================================

#ifndef _TERASIC_OS_INCLUDE_H_
#define _TERASIC_OS_INCLUDE_H_

// Standard C libraries
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

// Nios II HAL
#include "system.h"                    // Qsys-generated system definitions
#include <unistd.h>                    // usleep()
#include "alt_types.h"                 // Altera type definitions

// Nios II Peripheral Drivers
#include "altera_avalon_spi.h"
#include "altera_avalon_pio_regs.h"

// Type compatibility (HPS used these)
#ifndef ALT_STATUS_CODE
typedef int ALT_STATUS_CODE;
#define ALT_E_SUCCESS   0
#define ALT_E_ERROR     -1
#endif

#endif  // _TERASIC_OS_INCLUDE_H_