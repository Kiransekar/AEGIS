//===============================================================================
// Module: isolation_cell_1bit
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/power/isolation_cell_1bit.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Default-clamp isolation cell for power domain boundary signals.
//   When isolation is enabled, output clamps to safe default value.
//
// Safety Annotations:
//   @CERT: AEGIS-PWR-ISO-001 — Power domain isolation (ISO 26262-5:2018 §8.4.3)
//   @SAFETY: Isolation prevents undefined signals from powered-down domain
//            from propagating to always-on domain
//   @WCET: Combinational — 0 cycles
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module isolation_cell_1bit #(
    parameter CLAMP_VALUE = 1'b0    // Default clamp value (0 for safety)
) (
    input  wire i_signal,           // Signal from power-down domain
    input  wire i_iso_en,           // Isolation enable (active-high)
    output wire o_signal            // Isolated signal output
);

    // @SAFETY: When iso_en=1, output clamps to CLAMP_VALUE regardless of input
    // @SAFETY: When iso_en=0, signal passes through transparently
    assign o_signal = i_iso_en ? CLAMP_VALUE : i_signal;

endmodule
