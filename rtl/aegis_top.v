//===============================================================================
// Module: aegis_top
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/aegis_top.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Top-level: domain instantiation + clock/reset routing.
//   Phase 2: RT domain with full ISA support (RV32IMACF + Xdrone).
//
// Safety Annotations:
//   @CERT: AEGIS-TOP-001 — ARCHITECTURE.md §2 (SoC Top)
//   @SAFETY: Domain isolation at top level; independent clock/reset per domain
//   @SAFETY: DFT scan interface fuse-gated in production
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module aegis_top (
    // Primary Clock & Reset
    input  wire        i_clk,           // Main system clock
    input  wire        i_rst_n,         // Main system reset

    // RT Domain Clock & Reset (separate for isolation)
    input  wire        i_rt_clk,        // 240 MHz RT domain clock
    input  wire        i_rt_rst_n,      // RT domain reset

    // TCLS Interface
    input  wire        i_tcls_en,       // Triple lockstep enable

    // AXI Interconnect
    output wire [31:0] o_axi_aw_addr,
    output wire        o_axi_aw_valid,
    input  wire        i_axi_aw_ready,
    output wire [31:0] o_axi_w_data,
    output wire        o_axi_w_valid,
    input  wire        i_axi_w_ready,
    input  wire [1:0]  i_axi_b_resp,
    input  wire        i_axi_b_valid,
    output wire        o_axi_b_ready,
    input  wire [31:0] i_axi_r_data,
    input  wire [1:0]  i_axi_r_resp,
    input  wire        i_axi_r_valid,
    output wire        o_axi_r_ready,
    output wire [31:0] o_axi_ar_addr,
    output wire        o_axi_ar_valid,
    input  wire        i_axi_ar_ready,

    // Interrupt Inputs
    input  wire [10:0] i_irq_pending,

    // Power Domain Outputs
    output wire        o_rt_sleep_en,
    output wire        o_rt_iso_en,
    output wire        o_rt_retention_en,
    output wire        o_rt_pwr_switch_n,

    // Debug
    output wire [31:0] o_debug_pc,
    input  wire        i_debug_halt,

    // TCLS Fault Output
    output wire        o_tcls_fault,

    // DFT Scan Interface (fuse-gated in production)
    // @SAFETY: Scan pins must be tied off in production silicon
    input  wire        i_scan_enable,
    input  wire        i_scan_in,
    output wire        o_scan_out,
    input  wire        i_scan_clk
);

    //-------------------------------------------------------------------------
    // RT Domain Instantiation
    // @SAFETY: RT domain uses independent clock and reset for isolation
    //-------------------------------------------------------------------------
    aegis_rt_top u_rt_domain (
        .i_clk(i_rt_clk),
        .i_rst_n(i_rt_rst_n),
        .i_tcls_en(i_tcls_en),
        .o_tcls_fault(o_tcls_fault),
        .o_axi_aw_addr(o_axi_aw_addr),
        .o_axi_aw_valid(o_axi_aw_valid),
        .i_axi_aw_ready(i_axi_aw_ready),
        .o_axi_w_data(o_axi_w_data),
        .o_axi_w_valid(o_axi_w_valid),
        .i_axi_w_ready(i_axi_w_ready),
        .i_axi_b_resp(i_axi_b_resp),
        .i_axi_b_valid(i_axi_b_valid),
        .o_axi_b_ready(o_axi_b_ready),
        .i_axi_r_data(i_axi_r_data),
        .i_axi_r_resp(i_axi_r_resp),
        .i_axi_r_valid(i_axi_r_valid),
        .o_axi_r_ready(o_axi_r_ready),
        .o_axi_ar_addr(o_axi_ar_addr),
        .o_axi_ar_valid(o_axi_ar_valid),
        .i_axi_ar_ready(i_axi_ar_ready),
        .i_irq_pending(i_irq_pending),
        .o_sleep_en(o_rt_sleep_en),
        .o_iso_en(o_rt_iso_en),
        .o_retention_en(o_rt_retention_en),
        .o_pwr_switch_n(o_rt_pwr_switch_n),
        .o_debug_pc(o_debug_pc),
        .i_debug_halt(i_debug_halt)
    );

    // @SAFETY: Application and Security domains not instantiated in Phase 2
    // These will be added in Phase 3 with proper isolation

    //-------------------------------------------------------------------------
    // DFT Scan Chain (fuse-gated in production)
    // @SAFETY: Scan enable must be tied to 0 in production
    //-------------------------------------------------------------------------
    rt_dft_scan #(
        .SCAN_CHAINS(4),
        .SCAN_LENGTH(256)
    ) u_dft_scan (
        .i_clk(i_rt_clk),
        .i_rst_n(i_rt_rst_n),
        .i_scan_enable(i_scan_enable),
        .i_scan_in(i_scan_in),
        .o_scan_out(o_scan_out),
        .i_scan_clk(i_scan_clk),
        .i_chain_sel(2'd0)
    );

endmodule
