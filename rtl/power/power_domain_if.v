//===============================================================================
// Module: power_domain_if
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/power/power_domain_if.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Power domain control signal interface. Aggregates sleep, isolation,
//   retention, and power switch signals for a single power domain.
//
// Safety Annotations:
//   @CERT: AEGIS-PWR-PDIF-001 — Power domain interface (ISO 26262-5:2018)
//   @SAFETY: All signals active-high for consistent control semantics
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module power_domain_if (
    // Control from power orchestrator
    input  wire        i_sleep_en,       // Sleep mode enable
    input  wire        i_iso_en,         // Isolation cell enable
    input  wire        i_retention_en,   // Retention register enable
    input  wire        i_pwr_switch_n,   // Power switch (active-low = ON)

    // Status to power orchestrator
    output wire        o_is_sleeping,    // Domain is in sleep state
    output wire        o_is_isolated,    // Domain outputs are isolated
    output wire        o_is_retained,    // Domain state is retained
    output wire        o_is_powered      // Domain has power
);

    // Status derived directly from control signals
    assign o_is_sleeping  = i_sleep_en;
    assign o_is_isolated  = i_iso_en;
    assign o_is_retained  = i_retention_en;
    assign o_is_powered   = !i_pwr_switch_n;

endmodule
