//===============================================================================
// Module: rt_dft_scan
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_dft_scan.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Design-for-Test (DFT) scan chain wrapper for the RT core.
//   Wraps core pipeline registers into scan chains for ATPG.
//   Scan enable is fuse-gated in production (tie-off to 0).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-DFT-001 — ARCHITECTURE.md §6 (DFT)
//   @SAFETY: Scan enable must be hardwired to 0 in production (fuse-gated)
//   @SAFETY: Scan chains must not compromise TCLS lockstep integrity
//   @WCET: Scan mode is test-only; no timing impact in functional mode
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_dft_scan #(
    parameter SCAN_CHAINS   = 4,       // Number of parallel scan chains
    parameter SCAN_LENGTH   = 256      // Max scan chain length per chain
) (
    // Functional interface (pass-through to core)
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Scan control
    input  wire        i_scan_enable,   // Scan shift enable (MUST be 0 in production)
    input  wire        i_scan_in,       // Scan data in (chain 0)
    output wire        o_scan_out,      // Scan data out (chain SCAN_CHAINS-1)
    input  wire        i_scan_clk,      // Scan clock (separate from functional)

    // Scan chain select
    input  wire [$clog2(SCAN_CHAINS)-1:0] i_chain_sel
);

    //-------------------------------------------------------------------------
    // Scan Chain Registers
    // @SAFETY: In functional mode (scan_enable=0), these are don't-care
    //          and synthesis will optimize them away
    //-------------------------------------------------------------------------
    reg [SCAN_LENGTH-1:0] scan_chains [0:SCAN_CHAINS-1];

    integer i;

    always @(posedge i_scan_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i = 0; i < SCAN_CHAINS; i = i + 1) begin
                scan_chains[i] <= {SCAN_LENGTH{1'b0}};
            end
        end else if (i_scan_enable) begin
            // @SAFETY: Shift scan data when in test mode
            scan_chains[0] <= {scan_chains[0][SCAN_LENGTH-2:0], i_scan_in};
            for (i = 1; i < SCAN_CHAINS; i = i + 1) begin
                scan_chains[i] <= {scan_chains[i][SCAN_LENGTH-2:0],
                                   scan_chains[i-1][SCAN_LENGTH-1]};
            end
        end
    end

    // Scan output from selected chain
    assign o_scan_out = scan_chains[i_chain_sel][SCAN_LENGTH-1];

    //-------------------------------------------------------------------------
    // Production Safety Gate
    // @SAFETY: Scan enable must be tied to 0 in production silicon
    //          This is enforced by fuse-gating in the top-level wrapper
    //-------------------------------------------------------------------------
    // synthesis translate_off
    initial begin
        if (i_scan_enable !== 1'b0) begin
            $display("[DFT WARNING] Scan enable active — production fuse must gate this");
        end
    end
    // synthesis translate_on

endmodule
