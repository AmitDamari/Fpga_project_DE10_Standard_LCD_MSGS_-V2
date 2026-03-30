#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>

#include "LCD_Hw.h"
#include "LCD_Lib.h"
#include "lcd_graphic.h"
#include "font.h"
#include "messages.h"

#define HW_REGS_BASE          0xFC000000
#define HW_REGS_SPAN          0x04000000
#define HW_REGS_MASK          (HW_REGS_SPAN - 1)
#define ALT_LWFPGASLVS_OFST   0xFF200000
#define BUTTON_PIO_BASE       0x5000
#define FSM_STATUS_PIO_BASE   0x6000   // NEW: [7:5]=FSM state, [4:0]=FSM message index
#define TIMER_STATUS_PIO_BASE 0x7000   // NEW: timeout flag + seconds remaining
#define BUTTON_MASK           0x0F
#define TIMEOUT_SECONDS       15

#define FSM_STATUS_STATE_SHIFT 5
#define FSM_STATUS_STATE_MASK  0xE0
#define FSM_STATUS_INDEX_MASK  0x1F

#define FSM_STATE_FROM_REG(v)  (((v) & FSM_STATUS_STATE_MASK) >> FSM_STATUS_STATE_SHIFT)
#define FSM_INDEX_FROM_REG(v)  ((v) & FSM_STATUS_INDEX_MASK)
#define MSG_COUNT              18

typedef enum {
    HW_FSM_INIT  = 0,
    HW_FSM_IDLE  = 1,
    HW_FSM_HOME  = 2,
    HW_FSM_MSG   = 3,
    HW_FSM_SLEEP = 4
} HwFsmState;

// FSM States
typedef enum {
    STATE_IDLE,
    STATE_HOME,
    STATE_MESSAGE
} State;

// Global variables
void *virtual_base = NULL;
volatile uint32_t *button_addr = NULL;
volatile uint32_t *fsm_status_addr = NULL;    // NEW: FPGA FSM status register
volatile uint32_t *timer_status_addr = NULL;  // NEW: FPGA timer status register
int fd = -1;

static const char* hw_fsm_state_name(int state) {
    switch (state) {
        case HW_FSM_INIT:  return "INIT";
        case HW_FSM_IDLE:  return "IDLE";
        case HW_FSM_HOME:  return "HOME";
        case HW_FSM_MSG:   return "MSG";
        case HW_FSM_SLEEP: return "SLEEP";
        default:           return "UNKNOWN";
    }
}

int main() {
    // === SETUP (exactly like combined_test.c) ===
    printf("Opening /dev/mem...\n");
    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        printf("ERROR: Cannot open /dev/mem\n");
        return 1;
    }
    
    printf("Memory mapping...\n");
    virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        printf("ERROR: mmap failed\n");
        close(fd);
        return 1;
    }
    printf("  virtual_base = %p\n", virtual_base);
    
    printf("Setting up button address...\n");
    button_addr = (uint32_t *)(virtual_base + ((ALT_LWFPGASLVS_OFST + BUTTON_PIO_BASE) & HW_REGS_MASK));
    printf("  button_addr = %p\n", (void*)button_addr);
    
    // NEW: Map FPGA status registers
    printf("Setting up FPGA status registers...\n");
    fsm_status_addr = (uint32_t *)(virtual_base +
        ((ALT_LWFPGASLVS_OFST + FSM_STATUS_PIO_BASE) & HW_REGS_MASK));
    timer_status_addr = (uint32_t *)(virtual_base +
        ((ALT_LWFPGASLVS_OFST + TIMER_STATUS_PIO_BASE) & HW_REGS_MASK));
    printf("  fsm_status_addr   = %p\n", (void*)fsm_status_addr);
    printf("  timer_status_addr = %p\n", (void*)timer_status_addr);
    
    printf("Initializing LCD...\n");
    LCDHW_Init(virtual_base);
    LCD_Init();
    LCD_GraphicClear();
    LCDHW_BackLight(true);
    printf("LCD Ready.\n");
    
    // === UI RENDER TRACKING ===
    int last_hw_state = -1;
    int last_hw_msg_index = -1;
    bool backlight_on = true;
    int last_warn_code = 0;
    
    printf("\n=== LCD MESSAGE SYSTEM STARTED ===\n");
    printf("Using FPGA hardware debouncing + idle timer.\n");
    printf("Press buttons to navigate.\n\n");
    
    // === MAIN LOOP ===
    while (1) {
        // ============================================================
        // Read FPGA hardware status registers
        // ============================================================
        uint32_t fsm_status = *fsm_status_addr;
        int hw_fsm_state = FSM_STATE_FROM_REG(fsm_status);
        int hw_msg_index = FSM_INDEX_FROM_REG(fsm_status);
        
        uint32_t timer_status = *timer_status_addr;
        bool timeout = timer_status & 1;             // [0] timeout flag (sticky until button press)
        int secs_left = (timer_status >> 1) & 0x0F;  // [4:1] seconds remaining

        // Runtime sanity checks (diagnostic only, no control impact)
        // Warn once per warning type transition to avoid log spam.
        if ((hw_fsm_state == HW_FSM_SLEEP) && !timeout) {
            if (last_warn_code != 1) {
                printf("[WARN] FSM=SLEEP but timeout_flag=0 (unexpected combination)\n");
                last_warn_code = 1;
            }
        } else if ((hw_fsm_state == HW_FSM_MSG) && (hw_msg_index >= MSG_COUNT)) {
            if (last_warn_code != 2) {
                printf("[WARN] FSM=MSG with out-of-range msg_index=%d\n", hw_msg_index);
                last_warn_code = 2;
            }
        } else {
            last_warn_code = 0;
        }

        // HPS is a renderer only; hardware FSM is the control authority.
        if ((hw_fsm_state != last_hw_state) ||
            ((hw_fsm_state == HW_FSM_MSG) && (hw_msg_index != last_hw_msg_index))) {

            printf("HW FSM: %s(%d), msg_idx=%d, secs_left=%d, timeout=%d\n",
                   hw_fsm_state_name(hw_fsm_state), hw_fsm_state,
                   hw_msg_index, secs_left, timeout ? 1 : 0);

            switch (hw_fsm_state) {
                case HW_FSM_INIT:
                case HW_FSM_IDLE:
                    if (!backlight_on) {
                        LCDHW_BackLight(true);
                        backlight_on = true;
                    }
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  "==================");
                    LCD_TextOut(0, 16, "  DE10-Standard   ");
                    LCD_TextOut(0, 32, "   LCD Message    ");
                    LCD_TextOut(0, 48, "  Press Any Key   ");
                    break;

                case HW_FSM_HOME:
                    if (!backlight_on) {
                        LCDHW_BackLight(true);
                        backlight_on = true;
                    }
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  "==================");
                    LCD_TextOut(0, 16, "  Welcome User!   ");
                    LCD_TextOut(0, 32, " KEY1/KEY2: Msgs  ");
                    LCD_TextOut(0, 48, " KEY0: Back       ");
                    break;

                case HW_FSM_MSG: {
                    int safe_idx = (hw_msg_index < MSG_COUNT) ? hw_msg_index : 0;
                    if (!backlight_on) {
                        LCDHW_BackLight(true);
                        backlight_on = true;
                    }
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  (char*)MSG_LIST[safe_idx][0]);
                    LCD_TextOut(0, 16, (char*)MSG_LIST[safe_idx][1]);
                    LCD_TextOut(0, 32, (char*)MSG_LIST[safe_idx][2]);
                    LCD_TextOut(0, 48, (char*)MSG_LIST[safe_idx][3]);
                    break;
                }

                case HW_FSM_SLEEP:
                    LCD_GraphicClear();
                    if (backlight_on) {
                        LCDHW_BackLight(false);
                        backlight_on = false;
                    }
                    break;

                default:
                    if (!backlight_on) {
                        LCDHW_BackLight(true);
                        backlight_on = true;
                    }
                    LCD_GraphicClear();
                    LCD_TextOut(0, 16, "  FSM ERROR STATE ");
                    break;
            }

            last_hw_state = hw_fsm_state;
            last_hw_msg_index = hw_msg_index;
        }
        
        usleep(20000);  // 20ms polling interval (FPGA handles debouncing)
    }
    
    close(fd);
    return 0;
}