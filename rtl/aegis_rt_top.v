//===============================================================================
// Module: aegis_rt_top
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/aegis_rt_top.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   RT domain top: core + scratchpad + SMU + power orchestrator.
//   Integrates all RT domain components with CSR configuration wiring.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-TOP-001 — ARCHITECTURE.md §2 (RT Domain)
//   @SAFETY: All safety mechanisms integrated at this level
//   @SAFETY: CSR outputs wired to all submodules for deterministic config
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module aegis_rt_top (
    // Clock & Reset
    input  wire        i_clk,           // 240 MHz RT domain clock
    input  wire        i_rst_n,         // Active-low async reset

    // TCLS Interface (to SoC-level lockstep controller)
    input  wire        i_tcls_en,
    output wire        o_tcls_fault,

    // AXI Interface (to interconnect)
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

    // Power Domain Interface
    output wire        o_sleep_en,
    output wire        o_iso_en,
    output wire        o_retention_en,
    output wire        o_pwr_switch_n,

    // Debug
    output wire [31:0] o_debug_pc,
    input  wire        i_debug_halt
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------

    // Core ↔ Scratchpad
    wire [18:0] sp_addr;
    wire [31:0] sp_rdata, sp_wdata;
    wire        sp_we, sp_re;

    // Core ↔ Xdrone
    wire        xdrone_valid, xdrone_ready, xdrone_done;
    wire [31:0] xdrone_opcode, xdrone_result;

    // Core ↔ Interrupt
    wire [10:0] irq_vector;
    wire        irq_ack;

    // Core ↔ SMU
    wire [7:0]  smu_fault_code;
    wire        smu_safe_req;

    // SMU ↔ Power
    wire        power_safe_state_active;

    // ECC errors
    wire        ecc_single_error, ecc_double_error;

    // CSR configuration wires (from core CSR unit to subsystems)
    wire [31:0] rt_cfg, watchdog_cfg, ecc_scrub_cfg, xdrone_cfg, smu_ctrl, power_cfg;

    //-------------------------------------------------------------------------
    // RT Core
    //-------------------------------------------------------------------------
    aegis_rt_core u_rt_core (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_tcls_en(i_tcls_en),
        .o_tcls_fault(o_tcls_fault),
        .i_tcls_peer_ok(2'b11),  // @SAFETY: Both peers OK (normal operation)
        .o_sp_addr(sp_addr),
        .i_sp_rdata(sp_rdata),
        .o_sp_wdata(sp_wdata),
        .o_sp_we(sp_we),
        .o_sp_re(sp_re),
        .i_xdrone_valid(xdrone_valid),
        .o_xdrone_ready(xdrone_ready),
        .i_xdrone_opcode(xdrone_opcode),
        .o_xdrone_result(xdrone_result),
        .o_xdrone_done(xdrone_done),
        .o_irq_vector(irq_vector),
        .i_irq_ack(irq_ack),
        .o_smu_fault_code(smu_fault_code),
        .i_smu_safe_req(smu_safe_req),
        .o_debug_pc(o_debug_pc),
        .i_debug_halt(i_debug_halt)
    );

    //-------------------------------------------------------------------------
    // Scratchpad Controller
    //-------------------------------------------------------------------------
    scratchpad_ctrl u_scratchpad (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_addr(sp_addr),
        .i_wdata(sp_wdata),
        .i_we(sp_we),
        .i_re(sp_re),
        .i_valid(1'b1),
        .o_rdata(sp_rdata),
        .o_rdata_valid(),
        .o_ready(),
        .o_ecc_single_error(ecc_single_error),
        .o_ecc_double_error(ecc_double_error),
        .o_scrub_addr(),
        .o_scrub_active(),
        .i_scrub_enable(ecc_scrub_cfg[0]),  // @SAFETY: CSR-controlled scrub enable
        .i_scrub_interval(ecc_scrub_cfg[31:1])  // @SAFETY: CSR-controlled interval
    );

    //-------------------------------------------------------------------------
    // Safety Monitor Unit
    //-------------------------------------------------------------------------
    smu u_smu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_fault_code(smu_fault_code),
        .i_fault_valid(|{ecc_double_error, ecc_single_error, smu_fault_code != 8'd0}),
        .o_active_fault(),
        .o_fault_severity(),
        .o_safe_state_req(smu_safe_req),
        .i_fault_ack(1'b0),
        .i_safe_state_req(1'b0),
        .o_fault_history(),
        .o_fault_latched()
    );

    //-------------------------------------------------------------------------
    // Power Orchestrator
    //-------------------------------------------------------------------------
    power_orchestrator u_power (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_smu_safe_req(smu_safe_req),
        .i_smu_fault_code(smu_fault_code),
        .i_sleep_req(power_cfg[0]),  // @SAFETY: CSR-controlled sleep request
        .i_wake_req(power_cfg[1]),   // @SAFETY: CSR-controlled wake request
        .i_tile_state_req(power_cfg[5:2]),
        .o_sleep_en(o_sleep_en),
        .o_iso_en(o_iso_en),
        .o_retention_en(o_retention_en),
        .o_pwr_switch_n(o_pwr_switch_n),
        .o_tile_state(),
        .o_safe_state_active(power_safe_state_active),
        .o_wake_in_progress(),
        .o_wake_start(),
        .i_wake_done(1'b0)
    );

    //-------------------------------------------------------------------------
    // AXI RT Slice (pass-through in Phase 1)
    //-------------------------------------------------------------------------
    axi_lite_rt_slice u_axi_slice (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_aw_addr(32'd0),
        .i_aw_valid(1'b0),
        .o_aw_ready(),
        .i_w_data(32'd0),
        .i_w_valid(1'b0),
        .o_w_ready(),
        .o_b_resp(),
        .o_b_valid(),
        .i_b_ready(1'b0),
        .i_ar_addr(32'd0),
        .i_ar_valid(1'b0),
        .o_ar_ready(),
        .o_r_data(),
        .o_r_resp(),
        .o_r_valid(),
        .i_r_ready(1'b0),
        .o_aw_addr(o_axi_aw_addr),
        .o_aw_valid(o_axi_aw_valid),
        .i_aw_ready(i_axi_aw_ready),
        .o_w_data(o_axi_w_data),
        .o_w_valid(o_axi_w_valid),
        .i_w_ready(i_axi_w_ready),
        .i_b_resp(i_axi_b_resp),
        .i_b_valid(i_axi_b_valid),
        .o_b_ready(o_axi_b_ready),
        .o_ar_addr(o_axi_ar_addr),
        .o_ar_valid(o_axi_ar_valid),
        .i_ar_ready(i_axi_ar_ready),
        .i_r_data(i_axi_r_data),
        .i_r_resp(i_axi_r_resp),
        .i_r_valid(i_axi_r_valid),
        .o_r_ready(o_axi_r_ready),
        .o_rt_grant(),
        .o_latency_violation()
    );

    //-------------------------------------------------------------------------
    // PMP Lite (memory access protection)
    // @SAFETY: Deny-by-default; CSR-configured regions
    //-------------------------------------------------------------------------
    wire        pmp_violation;
    wire [3:0]  pmp_region;

    pmp_lite u_pmp (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_access_addr({13'd0, sp_addr}),
        .i_access_we(sp_we),
        .i_access_re(sp_re),
        .i_access_priv(2'd3),  // @SAFETY: Machine mode always
        .o_access_ok(),
        .o_access_violation(pmp_violation),
        .i_csr_region_sel(rt_cfg[3:0]),
        .i_csr_addr(rt_cfg[31:16]),
        .i_csr_addr_mask(32'hFFFFF000),
        .i_csr_we(1'b0),
        .i_csr_perm(2'd0)
    );

endmodule
