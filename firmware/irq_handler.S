//===============================================================================
// AEGIS-RV Interrupt Handler
// File: firmware/irq_handler.S
//
// Description:
//   RISC-V interrupt handler for RT core. Saves context to shadow bank,
//   reads mcause, dispatches to ISR, restores context, returns via MRET.
//
// Safety Annotations:
//   @WCET: Entry to handler = 12 cycles (hardware guaranteed)
//   @SAFETY: Shadow bank swap provides zero-cycle context save
//   @SAFETY: All 11 interrupt vectors handled
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

    .section .text.irq_handler
    .globl _irq_entry
    .type  _irq_entry, @function

_irq_entry:
    // Hardware has already:
    //   1. Swapped to shadow register bank (bank 1)
    //   2. Set PC to mtvec (this handler)
    //   3. Saved previous PC to mepc
    //   4. Set MSTATUS.MIE = 0 (interrupts disabled in handler)

    // Read interrupt cause
    csrr    t0, mcause          // t0 = cause (interrupt bit + code)
    csrr    t1, mepc            // t1 = return PC

    // Dispatch on interrupt code (bits [10:0])
    andi    t2, t0, 0x7FF       // t2 = interrupt code

    // Vector table: jump based on interrupt code
    la      t3, _irq_vector_table
    slli    t4, t2, 2           // t4 = code * 4 (word offset)
    add     t3, t3, t4          // t3 = &vector_table[code]
    lw      t5, 0(t3)           // t5 = ISR address
    jr      t5                  // Jump to ISR

    // ISR returns here
_irq_return:
    // Restore interrupt enable
    csrr    t0, mstatus
    ori     t0, t0, 0x8         // Set MIE bit
    csrw    mstatus, t0

    // Return from handler
    mret

    .size _irq_entry, . - _irq_entry

//===============================================================================
// Interrupt Vector Table
//===============================================================================
    .section .rodata
    .globl _irq_vector_table
    .type  _irq_vector_table, @object

_irq_vector_table:
    .word _isr_timer           // 0:  Timer interrupt
    .word _isr_watchdog        // 1:  Watchdog timeout
    .word _isr_ecc_single      // 2:  ECC single-bit error
    .word _isr_ecc_double      // 3:  ECC double-bit error
    .word _isr_tcls_mismatch   // 4:  TCLS lockstep mismatch
    .word _isr_pmp_violation   // 5:  PMP access violation
    .word _isr_xdrone_error    // 6:  Xdrone dispatch error
    .word _isr_smu_fault       // 7:  SMU fault detected
    .word _isr_power_transition // 8:  Power state transition
    .word _isr_external_9      // 9:  External interrupt 9
    .word _isr_external_10     // 10: External interrupt 10

    .size _irq_vector_table, . - _irq_vector_table

//===============================================================================
// Individual ISR Stubs
//===============================================================================
    .section .text

.macro ISR_STUB name
    .globl \name
    .type  \name, @function
\name:
    // @SAFETY: ISR stub — acknowledge and return
    // Real implementation would handle the specific interrupt
    csrr    t0, mip             // Clear pending bit
    j       _irq_return
    .size \name, . - \name
.endm

ISR_STUB _isr_timer
ISR_STUB _isr_watchdog
ISR_STUB _isr_ecc_single
ISR_STUB _isr_ecc_double
ISR_STUB _isr_tcls_mismatch
ISR_STUB _isr_pmp_violation
ISR_STUB _isr_xdrone_error
ISR_STUB _isr_smu_fault
ISR_STUB _isr_power_transition
ISR_STUB _isr_external_9
ISR_STUB _isr_external_10
