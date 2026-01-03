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
#define BUTTON_MASK           0x0F
#define TIMEOUT_SECONDS       15

// FSM States
typedef enum {
    STATE_IDLE,
    STATE_HOME,
    STATE_MESSAGE
} State;

// Global variables (same as combined_test.c)
void *virtual_base = NULL;
volatile uint32_t *button_addr = NULL;
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
    int lastBtn = 0;
    time_t lastActivityTime = time(NULL);
    
    printf("\n=== LCD MESSAGE SYSTEM STARTED ===\n");
    printf("Press buttons to navigate.\n\n");
    
    // === MAIN LOOP ===
    while (1) {
        // Read buttons (exactly like combined_test.c)
        uint32_t raw = *button_addr;
        int btn = (~raw) & BUTTON_MASK;
        
        // Detect button press (transition from 0 to non-0)
        bool btnPressed = (btn != 0 && lastBtn == 0);
        lastBtn = btn;
        
        if (btnPressed) {
            lastActivityTime = time(NULL);
            printf("Button pressed: %d (KEY0=%d KEY1=%d KEY2=%d KEY3=%d)\n",
                   btn, (btn&1), (btn&2)>>1, (btn&4)>>2, (btn&8)>>3);
        }
        
        // Check for timeout
        bool timeout = (difftime(time(NULL), lastActivityTime) > TIMEOUT_SECONDS);
        
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
        
        usleep(50000);  // 50ms delay
    }
    
    close(fd);
    return 0;
}