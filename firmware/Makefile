#===============================================================================
# AEGIS-RV Firmware Build Makefile
#===============================================================================

CROSS_COMPILE ?= riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
AS      = $(CROSS_COMPILE)as
LD      = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

CFLAGS  = -march=rv32imac_zicsr -mabi=ilp32 -O2 -Wall \
          -fno-builtin -fno-common -static -nostdlib \
          -DSAFETY_MODE -DXDRONE_EXT

ASFLAGS = -march=rv32imac_zicsr -mabi=ilp32

LDFLAGS = -T link.ld -nostdlib -static

TARGET  = build/rt_test.elf

SOURCES = boot.S rt_test.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCES) link.ld
	@mkdir -p build
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SOURCES)
	$(OBJCOPY) -O binary $@ build/rt_test.bin
	@echo "[✓] Firmware built: $(TARGET)"

clean:
	rm -rf build/
