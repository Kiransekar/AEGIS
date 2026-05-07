/*==============================================================================
 * AEGIS-RV RT Core Linker Script
 * Memory: TCM-only (no cache), 512 KB scratchpad
 *============================================================================*/

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    TCM (rwx) : ORIGIN = 0x00000000, LENGTH = 512K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > TCM

    .rodata : {
        *(.rodata .rodata.*)
    } > TCM

    .data : {
        *(.data .data.*)
    } > TCM

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > TCM

    .vector_table : {
        *(.vector_table)
    } > TCM

    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
    }
}

/* Stack at top of TCM */
__stack_top = ORIGIN(TCM) + LENGTH(TCM);
