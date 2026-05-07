//===============================================================================
// CSR Address Map — Auto-generated for AEGIS-RV RT Core v2.0
// Reference: ARCHITECTURE.md §6 (CSRs), RISC-V Privileged Spec v1.12
//
// Usage: Include in firmware (C/ASM) to access CSR addresses
// Generate: python3 scripts/gen_csr_map.py > fw/rt_csr_map.h
//===============================================================================

#ifndef AEGIS_RV_CSR_MAP_H
#define AEGIS_RV_CSR_MAP_H

//-------------------------------------------------------------------
// Standard RISC-V CSRs (Machine-level)
//-------------------------------------------------------------------
#define CSR_MSTATUS     0x300   // Machine status
#define CSR_MISA        0x301   // ISA and extensions
#define CSR_MIE         0x304   // Interrupt enable
#define CSR_MTVEC       0x305   // Trap vector base
#define CSR_MSCRATCH    0x340   // Scratch register
#define CSR_MEPC        0x341   // Exception PC
#define CSR_MCAUSE      0x342   // Exception cause
#define CSR_MTVAL       0x343   // Trap value
#define CSR_MIP         0x344   // Interrupt pending

//-------------------------------------------------------------------
// AEGIS-RV Custom CSRs (0x7C0–0x7FF, custom read/write)
// @SAFETY: All custom CSRs are machine-mode only
//-------------------------------------------------------------------
#define CSR_RT_CFG          0x7C0   // RT pipeline configuration
#define CSR_RT_CFG_PMP_EN       0   // [0]   PMP enable
#define CSR_RT_CFG_FPU_FTZ      1   // [1]   FPU flush-to-zero
#define CSR_RT_CFG_XDRONE_EN    2   // [2]   Xdrone extension enable
#define CSR_RT_CFG_IRQ_PRIO     4   // [4:3] IRQ priority scheme

#define CSR_WATCHDOG_CFG    0x7C1   // Watchdog timer configuration
#define CSR_WATCHDOG_TIMEOUT    0   // [15:0] Timeout value (cycles)
#define CSR_WATCHDOG_EN        16   // [16]  Watchdog enable

#define CSR_POWER_CFG       0x7C2   // Power domain configuration
#define CSR_POWER_CFG_SLEEP     0   // [0]   Sleep mode enable
#define CSR_POWER_CFG_ISO      1   // [1]   Isolation enable
#define CSR_POWER_CFG_RET      2   // [2]   Retention mode
#define CSR_POWER_CFG_SWITCH    3   // [3]   Power switch (active-low)

#define CSR_ECC_SCRUB_CFG   0x7C3   // ECC scrubber configuration
#define CSR_ECC_SCRUB_EN        0   // [0]   Scrubber enable
#define CSR_ECC_SCRUB_INTERVAL  1   // [7:1] Scrub interval (cycles)
#define CSR_ECC_SCRUB_ADDR     8   // [26:8] Current scrub address

#define CSR_TCLS_CFG        0x7C4   // TCLS lockstep configuration
#define CSR_TCLS_EN             0   // [0]   Lockstep enable
#define CSR_TCLS_THRESHOLD      4   // [7:4] Mismatch threshold

#define CSR_DFT_CFG         0x7C5   // DFT scan chain configuration
#define CSR_DFT_SCAN_EN         0   // [0]   Scan enable (fuse-gated)
#define CSR_DFT_CHAIN_SEL       4   // [5:4] Chain select (0-3)

#define CSR_XDRONE_CFG      0x7C6   // Xdrone extension configuration
#define CSR_XDRONE_MAX_DEPTH    0   // [3:0] Max dispatch depth
#define CSR_XDRONE_PRECISION    4   // [7:4] Fixed-point precision

#define CSR_SMU_FAULT       0x7C7   // SMU fault code (read-only)
#define CSR_SMU_FAULT_CODE      0   // [7:0] Current fault code

//-------------------------------------------------------------------
// SMU Fault Codes
//-------------------------------------------------------------------
#define SMU_FAULT_NONE          0x00
#define SMU_FAULT_TCLS_MISMATCH 0x01
#define SMU_FAULT_ECC_DOUBLE    0x02
#define SMU_FAULT_WATCHDOG      0x08
#define SMU_FAULT_PMP_VIOLATION 0x10
#define SMU_FAULT_POWER_FAIL    0x20
#define SMU_FAULT_ILLEGAL_INSN  0x40
#define SMU_FAULT_AXI_TIMEOUT   0x80

//-------------------------------------------------------------------
// IRQ Vector Numbers
//-------------------------------------------------------------------
#define IRQ_TCLS_MISMATCH   0
#define IRQ_ECC_DOUBLE      1
#define IRQ_WATCHDOG        2
#define IRQ_PMP_VIOLATION   3
#define IRQ_POWER_FAIL      4
#define IRQ_SMU_FAULT       5
#define IRQ_AXI_TIMEOUT     6
#define IRQ_XDRONE_ERROR    7
#define IRQ_ILLEGAL_INSN    8
#define IRQ_ECC_SINGLE      9
#define IRQ_SCRUB_DONE      10

#endif // AEGIS_RV_CSR_MAP_H
