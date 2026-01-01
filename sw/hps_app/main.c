#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#include "LCD_Hw.h"
#include "LCD_Lib.h"
#include "lcd_graphic.h"
#include "font.h"
#include "messages.h"

// --- Hardware Constants (From GHRD Qsys) ---
#define HW_REGS_BASE          0xFC000000
#define HW_REGS_SPAN          0x04000000
#define HW_REGS_MASK          (HW_REGS_SPAN - 1)
#define ALT_LWFPGASLVS_OFST   0xFF200000

// From your Qsys memory map:
#define BUTTON_PIO_BASE       0x5000
#define LED_PIO_BASE          0x3000
#define DIPSW_PIO_BASE        0x4000

#define BUTTON_MASK           0x0F

// --- FSM States ---
typedef enum {
    STATE_INIT,
    STATE_IDLE,
    STATE_HOME,
    STATE_MESSAGE
} State;

// --- Globals ---
void *virtual_base = NULL;
volatile uint32_t *h2p_lw_button_addr = NULL;
volatile uint32_t *h2p_lw_led_addr = NULL;
int fd = -1;

int setup_hps_fpga() {
    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERROR: Could not open /dev/mem\n");
        return 0;
    }
    
    virtual_base = mmap(NULL, HW_REGS_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        printf("ERROR: mmap() failed\n");
        close(fd);
        return 0;
    }
    
    h2p_lw_button_addr = (uint32_t *)(virtual_base + ((ALT_LWFPGASLVS_OFST + BUTTON_PIO_BASE) & HW_REGS_MASK));
    h2p_lw_led_addr = (uint32_t *)(virtual_base + ((ALT_LWFPGASLVS_OFST + LED_PIO_BASE) & HW_REGS_MASK));
    
    printf("Button addr: %p\n", (void*)h2p_lw_button_addr);
    printf("LED addr: %p\n", (void*)h2p_lw_led_addr);
    
    return 1;
}

int read_buttons() {
    uint32_t state = *h2p_lw_button_addr;
    return (~state) & BUTTON_MASK;
}

int main() {
    if (!setup_hps_fpga()) return 1;
    
    LCDHW_Init(virtual_base);
    LCD_Init();
    LCD_GraphicClear();
    LCDHW_BackLight(true);

    State currentState = STATE_INIT;
    int msgIndex = 0;
    int buttonState = 0;
    int lastButtonState = 0;
    time_t lastActivityTime = time(NULL);
    const int TIMEOUT_SECONDS = 15;

    printf("LCD Message System Started.\n");

    while (1) {
        buttonState = read_buttons();
        int btnPressed = (buttonState != 0 && lastButtonState == 0);
        lastButtonState = buttonState;

        if (btnPressed) {
            lastActivityTime = time(NULL);
            printf("Button pressed: %d\n", buttonState);
        }

        switch (currentState) {
            case STATE_INIT:
                LCD_GraphicClear();
                currentState = STATE_IDLE;
                break;

            case STATE_IDLE:
                LCD_TextOut(0, 16, "  DE10-Standard   ");
                LCD_TextOut(0, 32, "   LCD Message    ");
                LCD_TextOut(0, 48, "  Press Button    ");
                
                if (btnPressed) {
                    LCD_GraphicClear();
                    currentState = STATE_HOME;
                }
                break;

            case STATE_HOME:
                LCD_TextOut(0, 0,  "==================");
                LCD_TextOut(0, 16, "  Welcome User!   ");
                LCD_TextOut(0, 32, "  KEY1: Next      ");
                LCD_TextOut(0, 48, "  KEY2: Back      ");

                if (btnPressed) {
                    if ((buttonState & 2) || (buttonState & 4)) {
                        LCD_GraphicClear();
                        currentState = STATE_MESSAGE;
                        msgIndex = 0;
                    }
                }
                
                if (difftime(time(NULL), lastActivityTime) > TIMEOUT_SECONDS) {
                    LCD_GraphicClear();
                    currentState = STATE_IDLE;
                }
                break;

            case STATE_MESSAGE:
                LCD_TextOut(0, 0,  (char*)MSG_LIST[msgIndex][0]);
                LCD_TextOut(0, 16, (char*)MSG_LIST[msgIndex][1]);
                LCD_TextOut(0, 32, (char*)MSG_LIST[msgIndex][2]);
                LCD_TextOut(0, 48, (char*)MSG_LIST[msgIndex][3]);

                if (btnPressed) {
                    if (buttonState & 2) {
                        msgIndex++;
                        if (msgIndex >= 18) msgIndex = 0;
                        LCD_GraphicClear();
                    }
                    if (buttonState & 4) {
                        msgIndex--;
                        if (msgIndex < 0) msgIndex = 17;
                        LCD_GraphicClear();
                    }
                }

                if (difftime(time(NULL), lastActivityTime) > TIMEOUT_SECONDS) {
                    LCD_GraphicClear();
                    currentState = STATE_IDLE;
                }
                break;
        }

        usleep(50000);
    }

    close(fd);
    return 0;
}