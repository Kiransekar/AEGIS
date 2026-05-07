/*==============================================================================
 * AEGIS-RV Boot Stub
 * Initializes stack, installs vector table, jumps to main
 *============================================================================*/

.section .text.init
.global _start

_start:
    /* Set stack pointer to top of TCM */
    la sp, __stack_top

    /* Install vector table (locked in TCM for deterministic IRQ) */
    la t0, vector_table
    csrw mtvec, t0

    /* Clear BSS section */
    la t0, __bss_start
    la t1, __bss_end
clear_bss:
    bge t0, t1, done_bss
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss
done_bss:

    /* Jump to main */
    call main

    /* Should never return */
halt:
    wfi
    j halt

/*==============================================================================
 * Vector Table (12-cycle guaranteed entry)
 * @SAFETY: Vector table locked in TCM — no cache miss during interrupt
 *============================================================================*/
.section .vector_table
.align 4
vector_table:
    .word irq_handler_0    /* IRQ 0:  Watchdog */
    .word irq_handler_1    /* IRQ 1:  TCLS Mismatch */
    .word irq_handler_2    /* IRQ 2:  ECC Single Error */
    .word irq_handler_3    /* IRQ 3:  ECC Double Error */
    .word irq_handler_4    /* IRQ 4:  SMU Fault */
    .word irq_handler_5    /* IRQ 5:  Power Glitch */
    .word irq_handler_6    /* IRQ 6:  PMP Violation */
    .word irq_handler_7    /* IRQ 7:  IOPMP Violation */
    .word irq_handler_8    /* IRQ 8:  AXI Timeout */
    .word irq_handler_9    /* IRQ 9:  Context Switch Overrun */
    .word irq_handler_10   /* IRQ 10: Reserved */

/*==============================================================================
 * Default Interrupt Handlers
 *============================================================================*/
.section .text
irq_handler_0:
irq_handler_1:
irq_handler_2:
irq_handler_3:
irq_handler_4:
irq_handler_5:
irq_handler_6:
irq_handler_7:
irq_handler_8:
irq_handler_9:
irq_handler_10:
    /* Acknowledge interrupt */
    addi a0, zero, 1
    /* Return from interrupt */
    mret
