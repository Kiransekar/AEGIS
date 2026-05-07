//===============================================================================
// Module: iopmp_ctrl
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/interconnect/iopmp_ctrl.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   IOPMP controller (64 entries, 4KB granule, deny-by-default).
//   Phase 1 stub — pass-through with violation detection.
//
// Safety Annotations:
//   @CERT: AEGIS-SEC-IOP-001 — ARCHITECTURE.md §8 (IOPMP)
//   @SAFETY: Deny-by-default for DMA to safety peripherals
//   @WCET: Access check = combinational (0 cycles)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module iopmp_ctrl #(
    parameter NUM_ENTRIES = 64,
    parameter GRANULE_BITS = 12
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [31:0] i_access_addr,
    input  wire        i_access_we,
    output wire        o_access_ok,
    output wire        o_violation
);

    // Phase 1 stub: allow all accesses
    assign o_access_ok = 1'b1;
    assign o_violation = 1'b0;

endmodule
