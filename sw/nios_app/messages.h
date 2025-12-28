// ============================================================================
// messages.h - Predefined Messages for LCD Display System
// ============================================================================
// Display: 128x64 pixels
// Font: 16x16 pixels per character
// Capacity: 8 characters × 4 lines per screen
// ============================================================================

#ifndef _MESSAGES_H_
#define _MESSAGES_H_

// ============================================================================
// Configuration
// ============================================================================

#define TOTAL_MESSAGES      18
#define MAX_LINES           4
#define MAX_CHARS_PER_LINE  8

// ============================================================================
// Message Structure
// ============================================================================

typedef struct {
    const char *line1;
    const char *line2;
    const char *line3;
    const char *line4;
} MESSAGE_T;

// ============================================================================
// Welcome Message (HOME state)
// ============================================================================

static const MESSAGE_T welcomeMessage = {
    "WELCOME!",
    "DE10-LCD",
    "PRESS",
    "BUTTON"
};

// ============================================================================
// Idle Screen Message (IDLE state)
// ============================================================================

static const MESSAGE_T idleMessage = {
    "LCD MSG",
    "DISPLAY",
    "PRESS TO",
    "START"
};

// ============================================================================
// 18 Predefined Messages (MESSAGE state)
// ============================================================================

static const MESSAGE_T messages[TOTAL_MESSAGES] = {
    // Message 0
    {
        "MSG 1/18",
        "HELLO",
        "WORLD!",
        ""
    },
    // Message 1
    {
        "MSG 2/18",
        "FPGA",
        "PROJECT",
        "DEMO"
    },
    // Message 2
    {
        "MSG 3/18",
        "DE10",
        "STANDARD",
        "BOARD"
    },
    // Message 3
    {
        "MSG 4/18",
        "NIOS II",
        "SOFT",
        "CORE"
    },
    // Message 4
    {
        "MSG 5/18",
        "ST7565",
        "LCD",
        "128x64"
    },
    // Message 5
    {
        "MSG 6/18",
        "SPI",
        "SERIAL",
        "BUS"
    },
    // Message 6
    {
        "MSG 7/18",
        "FSM",
        "CONTROL",
        "LOGIC"
    },
    // Message 7
    {
        "MSG 8/18",
        "BUTTON",
        "INPUT",
        "ACTIVE"
    },
    // Message 8
    {
        "MSG 9/18",
        "TIMEOUT",
        "15 SECS",
        "IDLE"
    },
    // Message 9
    {
        "MSG10/18",
        "QSYS",
        "SYSTEM",
        "INTEG"
    },
    // Message 10
    {
        "MSG11/18",
        "VERILOG",
        "HDL",
        "DESIGN"
    },
    // Message 11
    {
        "MSG12/18",
        "QUARTUS",
        "PRIME",
        "TOOL"
    },
    // Message 12
    {
        "MSG13/18",
        "AVALON",
        "BUS",
        "CONNECT"
    },
    // Message 13
    {
        "MSG14/18",
        "GPIO",
        "ACTIVE",
        "PINS"
    },
    // Message 14
    {
        "MSG15/18",
        "CLOCK",
        "50 MHZ",
        "MAIN"
    },
    // Message 15
    {
        "MSG16/18",
        "DEBOUNCE",
        "FILTER",
        "CLEAN"
    },
    // Message 16
    {
        "MSG17/18",
        "SUCCESS",
        "SYSTEM",
        "WORKS!"
    },
    // Message 17
    {
        "MSG18/18",
        "THE END",
        "THANK",
        "YOU!"
    }
};

// ============================================================================
// Helper Macros
// ============================================================================

// Get message by index (with bounds checking)
#define GET_MESSAGE(index) (&messages[(index) % TOTAL_MESSAGES])

// Navigation helpers
#define NEXT_MESSAGE(index) (((index) + 1) % TOTAL_MESSAGES)
#define PREV_MESSAGE(index) (((index) - 1 + TOTAL_MESSAGES) % TOTAL_MESSAGES)

#endif // _MESSAGES_H_