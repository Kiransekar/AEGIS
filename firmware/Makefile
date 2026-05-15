#===============================================================================
# AEGIS-RV Firmware Build Makefile
#===============================================================================

ISA     ?= rv32imacf
ABI     ?= ilp32

CROSS_COMPILE ?= riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
AS      = $(CROSS_COMPILE)as
LD      = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

CFLAGS  = -march=$(ISA) -mabi=$(ABI) -mcmodel=medlow -O2 -Wall \
          -fno-builtin -fno-common -static -nostdlib \
          -DSAFETY_MODE -DXDRONE_EXT

ASFLAGS = -march=$(ISA) -mabi=$(ABI)

LDFLAGS = -T link.ld -nostdlib -static

TARGET  = build/firmware.elf

SRCS    = boot.S main.c syscalls.c rt_test.c

.PHONY: all clean

all: $(TARGET) build/firmware.hex

$(TARGET): $(SRCS) link.ld
	@mkdir -p build
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	$(OBJCOPY) -O binary $@ build/firmware.bin
	@echo "[✓] Firmware built: $(TARGET)"

build/firmware.hex: $(TARGET)
	$(OBJCOPY) -O verilog $< $@
	@echo "[✓] Verilog hex generated: build/firmware.hex"

clean:
	rm -rf build/
