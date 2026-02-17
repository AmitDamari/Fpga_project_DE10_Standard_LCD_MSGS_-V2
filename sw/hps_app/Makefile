# Simple Makefile for on-board or cross-compilation

# Default to gcc (native compilation on DE10)
# To cross-compile, run: make CC=arm-linux-gnueabihf-gcc
CC ?= gcc
CFLAGS = -g -Wall -O2
LDFLAGS = 

# Source files
SRCS = main.c LCD_Hw.c LCD_Lib.c lcd_graphic.c font.c
OBJS = $(SRCS:.c=.o)
TARGET = lcd_msg_app

# Rules
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
