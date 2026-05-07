//===============================================================================
// Module: smu_fault_codes
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/security/smu_fault_codes.vh
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   ISO 26262 / DO-254 fault code definitions for the Safety Monitor Unit.
//   Each fault code maps to a specific safety requirement clause.
//
// Safety Annotations:
//   @CERT: All fault codes traceable to ISO 26262-5:2018 §8.4.3
//   @SAFETY: Fault codes are immutable constants (no runtime modification)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

`ifndef AEGIS_SMU_FAULT_CODES_VH
`define AEGIS_SMU_FAULT_CODES_VH

//-----------------------------------------------------------------------------
// ISO 26262 Fault Code Definitions (8-bit)
// Format: FC_<CATEGORY>_<TYPE>
// @CERT: Each code maps to ISO 26262-5:2018 §8.4.3 fault classification
//-----------------------------------------------------------------------------

//--- No Fault ---
`define FC_NONE                     8'd0

//--- Single-Point Faults (SPF) — ISO 26262-5:2018 §8.4.3 ---
// @SAFETY: SPF must be detected and mitigated within TCLS_QUARANTINE_CYCLES
`define FC_TCLS_MISMATCH            8'd1    // @CERT: AEGIS-RT-TCLS-001 — Lockstep comparator mismatch
`define FC_TCLS_QUARANTINE          8'd2    // @CERT: AEGIS-RT-TCLS-002 — Quarantine threshold reached
`define FC_ECC_SINGLE_BIT           8'd3    // @CERT: AEGIS-MEM-ECC-001 — Single-bit ECC error (correctable)
`define FC_WATCHDOG_TIMEOUT         8'd4    // @CERT: AEGIS-RT-WDG-001  — Watchdog timer expired
`define FC_IRQ_LATENCY_VIOLATION    8'd5    // @CERT: AEGIS-RT-INT-001  — Interrupt entry exceeded 12 cycles
`define FC_CONTEXT_SWITCH_OVERRUN   8'd6    // @CERT: AEGIS-RT-CTX-001  — Context switch exceeded 26 cycles

//--- Latent Faults (LF) — ISO 26262-5:2018 §8.4.3 ---
// @SAFETY: LF detected by background scrubber or periodic self-test
`define FC_ECC_DOUBLE_BIT           8'd16   // @CERT: AEGIS-MEM-ECC-002 — Double-bit ECC error (uncorrectable)
`define FC_SCRUBBER_CORRECTED       8'd17   // @CERT: AEGIS-MEM-SCR-001 — Scrubber corrected a latent error
`define FC_POWER_GLITCH             8'd18   // @CERT: AEGIS-PWR-GLT-001 — Power supply glitch detected
`define FC_CLOCK_MONITOR_TRIP       8'd19   // @CERT: AEGIS-CLK-MON-001 — Clock frequency out of bounds
`define FC_RETENTION_RESTORE_FAIL   8'd20   // @CERT: AEGIS-PWR-RET-001 — Retention register restore mismatch

//--- Multiple-Point Faults (MPF) — Aggregation Required ---
// @SAFETY: MPF requires aggregation before safe-state trigger
`define FC_SPU_VIOLATION            8'd32   // @CERT: AEGIS-SEC-SPU-001 — SPU access violation
`define FC_PMP_VIOLATION            8'd33   // @CERT: AEGIS-SEC-PMP-001 — PMP region access violation
`define FC_IOPMP_VIOLATION          8'd34   // @CERT: AEGIS-SEC-IOP-001 — IOPMP DMA access violation
`define FC_AXI_TIMEOUT              8'd35   // @CERT: AEGIS-INT-AXI-001 — AXI bus timeout (deadlock risk)
`define FC_SAFE_STATE_VIOLATION     8'd36   // @CERT: AEGIS-PWR-SAFE-001 — Safe-state sequence violated

//--- PMHF (Probabilistic Metric for Hardware Failure) ---
// @SAFETY: Aggregated fault rate must meet PMHF target per ISO 26262-5
`define FC_PMHF_THRESHOLD_EXCEEDED 8'd48   // @CERT: AEGIS-PMHF-001 — Aggregated fault rate above target

//-----------------------------------------------------------------------------
// Fault Severity Levels (for SMU aggregation)
//-----------------------------------------------------------------------------
`define SEV_NONE        2'd0    // No fault
`define SEV_LOW         2'd1    // SPF — single-point, immediate action
`define SEV_MEDIUM      2'd2    // LF — latent, background correction
`define SEV_HIGH        2'd3    // MPF/PMHF — safe-state trigger

//-----------------------------------------------------------------------------
// SMU Aggregation Thresholds
// @WCET: Aggregation completes in 1 cycle (combinational priority encode)
//-----------------------------------------------------------------------------
`define AGG_THRESHOLD_SPF   3'd1   // Single SPF triggers safe-state
`define AGG_THRESHOLD_LF    3'd3   // 3 LFs trigger safe-state
`define AGG_THRESHOLD_MPF   3'd1   // Single MPF triggers safe-state

`endif // AEGIS_SMU_FAULT_CODES_VH
