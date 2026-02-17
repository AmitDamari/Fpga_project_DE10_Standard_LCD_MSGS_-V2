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
#define FSM_STATUS_PIO_BASE   0x6000   // NEW: button pulses + debounced levels
#define TIMER_STATUS_PIO_BASE 0x7000   // NEW: timeout flag + seconds remaining
#define BUTTON_MASK           0x0F
#define TIMEOUT_SECONDS       15

// FSM States
typedef enum {
    STATE_IDLE,
    STATE_HOME,
    STATE_MESSAGE
} State;

// Global variables
void *virtual_base = NULL;
volatile uint32_t *button_addr = NULL;
volatile uint32_t *fsm_status_addr = NULL;    // NEW: FPGA button status register
volatile uint32_t *timer_status_addr = NULL;  // NEW: FPGA timer status register
int fd = -1;

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
    
    // === STATE MACHINE VARIABLES ===
    State currentState = STATE_IDLE;
    State lastState = STATE_MESSAGE;  // Different from initial, forces first draw
    int msgIndex = 0;
    int lastMsgIndex = -1;
    int lastBtn = 0;  // For software edge detection on debounced levels
    
    printf("\n=== LCD MESSAGE SYSTEM STARTED ===\n");
    printf("Using FPGA hardware debouncing + idle timer.\n");
    printf("Press buttons to navigate.\n\n");
    
    // === MAIN LOOP ===
    while (1) {
        // ============================================================
        // Read FPGA hardware status registers
        // ============================================================
        uint32_t fsm_status = *fsm_status_addr;
        // [3:0] = btn_debounced: LEVEL signals (active-HIGH), stable for entire press
        // These are NOT single-cycle pulses — they stay HIGH while button is held
        int btn = fsm_status & 0x0F;
        
        uint32_t timer_status = *timer_status_addr;
        bool timeout = timer_status & 1;             // [0] timeout flag (sticky until button press)
        int secs_left = (timer_status >> 1) & 0x0F;  // [4:1] seconds remaining
        
        // Software edge detection: detect press transition (0→1)
        // This is reliable because btn_debounced stays HIGH for the entire
        // button press duration (typically >100ms), easily caught by 20ms polling
        bool btnPressed = (btn != 0 && lastBtn == 0);
        lastBtn = btn;
        
        if (btnPressed) {
            printf("FPGA btn_debounced: 0x%X (KEY0=%d KEY1=%d KEY2=%d KEY3=%d) secs_left=%d\n",
                   btn, (btn&1), (btn&2)>>1, (btn&4)>>2, (btn&8)>>3, secs_left);
        }
        
        // === STATE MACHINE ===
        switch (currentState) {
            
            case STATE_IDLE:
                // Draw screen only when entering this state
                if (currentState != lastState) {
                    printf(">>> Entering STATE_IDLE, drawing screen...\n");
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  "==================");
                    LCD_TextOut(0, 16, "  DE10-Standard   ");
                    LCD_TextOut(0, 32, "   LCD Message    ");
                    LCD_TextOut(0, 48, "  Press Any Key   ");
                    lastState = currentState;
                }
                
                // Any button press goes to HOME
                if (btnPressed) {
                    printf("Transition: IDLE -> HOME\n");
                    currentState = STATE_HOME;
                }
                break;
                
            case STATE_HOME:
                // Draw screen only when entering this state
                if (currentState != lastState) {
                    printf(">>> Entering STATE_HOME, drawing screen...\n");
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  "==================");
                    LCD_TextOut(0, 16, "  Welcome User!   ");
                    LCD_TextOut(0, 32, " KEY1/KEY2: Msgs  ");
                    LCD_TextOut(0, 48, " KEY0: Back       ");
                    lastState = currentState;
                }
                
                // KEY0 (bit 0) = back to IDLE
                if (btnPressed && (btn & 1)) {
                    printf("Transition: HOME -> IDLE\n");
                    currentState = STATE_IDLE;
                }
                // KEY1 (bit 1) or KEY2 (bit 2) = go to messages
                if (btnPressed && ((btn & 2) || (btn & 4))) {
                    printf("Transition: HOME -> MESSAGE\n");
                    currentState = STATE_MESSAGE;
                    msgIndex = 0;
                    lastMsgIndex = -1;  // Force redraw
                }
                
                // Timeout returns to IDLE
                if (timeout) {
                    printf("Timeout: HOME -> IDLE\n");
                    currentState = STATE_IDLE;
                }
                break;
                
            case STATE_MESSAGE:
                // Draw screen when entering state OR message changes
                if (currentState != lastState || msgIndex != lastMsgIndex) {
                    printf(">>> Entering STATE_MESSAGE, showing message %d...\n", msgIndex);
                    LCD_GraphicClear();
                    LCD_TextOut(0, 0,  (char*)MSG_LIST[msgIndex][0]);
                    LCD_TextOut(0, 16, (char*)MSG_LIST[msgIndex][1]);
                    LCD_TextOut(0, 32, (char*)MSG_LIST[msgIndex][2]);
                    LCD_TextOut(0, 48, (char*)MSG_LIST[msgIndex][3]);
                    lastState = currentState;
                    lastMsgIndex = msgIndex;
                }
                
                // KEY0 (bit 0) = back to HOME
                if (btnPressed && (btn & 1)) {
                    printf("Transition: MESSAGE -> HOME\n");
                    currentState = STATE_HOME;
                }
                // KEY1 (bit 1) = next message
                if (btnPressed && (btn & 2)) {
                    msgIndex++;
                    if (msgIndex >= 18) msgIndex = 0;
                    printf("Next message: %d\n", msgIndex);
                }
                // KEY2 (bit 2) = previous message
                if (btnPressed && (btn & 4)) {
                    msgIndex--;
                    if (msgIndex < 0) msgIndex = 17;
                    printf("Previous message: %d\n", msgIndex);
                }
                
                // Timeout returns to IDLE
                if (timeout) {
                    printf("Timeout: MESSAGE -> IDLE\n");
                    currentState = STATE_IDLE;
                }
                break;
        }
        
        usleep(20000);  // 20ms polling interval (FPGA handles debouncing)
    }
    
    close(fd);
    return 0;
}