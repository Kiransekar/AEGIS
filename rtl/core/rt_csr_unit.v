//===============================================================================
// Module: rt_csr_unit
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_csr_unit.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   CSR access + privilege mode handling for RT core.
//   All CSRs accessible only in Machine mode (privilege level 3).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-CSR-001 — ARCHITECTURE.md §9 (CSR Map)
//   @SAFETY: Machine-mode only access prevents unprivileged CSR modification
//   @WCET: CSR read/write = 1 cycle (mapped to scratchpad address space)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_csr_unit #(
    parameter CSR_ADDR_WIDTH = 12
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // CSR Access Interface
    input  wire [CSR_ADDR_WIDTH-1:0] i_csr_addr,
    input  wire        i_csr_rd_req,
    input  wire        i_csr_wr_req,
    input  wire [31:0] i_csr_wr_data,
    output wire [31:0] o_csr_rd_data,
    output wire        o_csr_rd_valid,

    // Privilege Check
    input  wire [1:0]  i_current_priv,  // Current privilege level
    output wire        o_access_fault,   // Access violation

    // CSR Outputs (to respective modules)
    output wire [31:0] o_rt_cfg,        // 0x7C0: aegis_rt_cfg
    output wire [31:0] o_watchdog_cfg,  // 0x7C2: watchdog_cfg
    output wire [31:0] o_ecc_scrub_cfg, // 0x7C4: ecc_scrub_cfg
    output wire [31:0] o_xdrone_cfg,    // 0x7C6: xdrone_cfg
    output wire [31:0] o_smu_ctrl,      // 0x7C9: smu_ctrl
    output wire [31:0] o_power_cfg,     // 0x7CA: power_cfg

    // CSR Inputs (from respective modules)
    input  wire [31:0] i_rt_status,     // 0x7C1: aegis_rt_status
    input  wire [31:0] i_watchdog_status, // 0x7C3: watchdog_status
    input  wire [31:0] i_ecc_scrub_status, // 0x7C5: ecc_scrub_status
    input  wire [31:0] i_xdrone_status, // 0x7C7: xdrone_status
    input  wire [31:0] i_smu_fault_code, // 0x7C8: smu_fault_code
    input  wire [31:0] i_power_status   // 0x7CB: power_status
);

    //-------------------------------------------------------------------------
    // Privilege Check
    // @SAFETY: Only Machine mode (priv=2'b11) can access CSRs
    // @CERT: AEGIS-RT-CSR-002 — Privilege gating (ISO 26262-6:2018 §6.4.3)
    //-------------------------------------------------------------------------
    wire access_allowed = (i_current_priv == 2'b11);

    assign o_access_fault = (i_csr_rd_req || i_csr_wr_req) && !access_allowed;

    //-------------------------------------------------------------------------
    // CSR Read Data Mux
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    reg [31:0] csr_rd_data_reg;

    always @* begin
        csr_rd_data_reg = 32'd0;
        case (i_csr_addr)
            12'h7C0: csr_rd_data_reg = o_rt_cfg;         // RW
            12'h7C1: csr_rd_data_reg = i_rt_status;       // RO
            12'h7C2: csr_rd_data_reg = o_watchdog_cfg;    // RW
            12'h7C3: csr_rd_data_reg = i_watchdog_status; // RW1C
            12'h7C4: csr_rd_data_reg = o_ecc_scrub_cfg;   // RW
            12'h7C5: csr_rd_data_reg = i_ecc_scrub_status; // RO
            12'h7C6: csr_rd_data_reg = o_xdrone_cfg;      // RW
            12'h7C7: csr_rd_data_reg = i_xdrone_status;    // RO
            12'h7C8: csr_rd_data_reg = i_smu_fault_code;   // RW1C
            12'h7C9: csr_rd_data_reg = o_smu_ctrl;         // RW
            12'h7CA: csr_rd_data_reg = o_power_cfg;        // RW
            12'h7CB: csr_rd_data_reg = i_power_status;     // RO
            default: csr_rd_data_reg = 32'd0;              // @SAFETY: Reserved reads as 0
        endcase
    end

    assign o_csr_rd_data  = access_allowed ? csr_rd_data_reg : 32'd0;
    assign o_csr_rd_valid = i_csr_rd_req && access_allowed;

    //-------------------------------------------------------------------------
    // CSR Write Registers
    // @SAFETY: Writes only allowed in Machine mode
    //-------------------------------------------------------------------------
    reg [31:0] rt_cfg_reg;
    reg [31:0] watchdog_cfg_reg;
    reg [31:0] ecc_scrub_cfg_reg;
    reg [31:0] xdrone_cfg_reg;
    reg [31:0] smu_ctrl_reg;
    reg [31:0] power_cfg_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rt_cfg_reg        <= 32'd0;
            watchdog_cfg_reg  <= 32'd0;
            ecc_scrub_cfg_reg <= 32'd0;
            xdrone_cfg_reg    <= 32'd0;
            smu_ctrl_reg      <= 32'd0;
            power_cfg_reg     <= 32'd0;
        end else if (i_csr_wr_req && access_allowed) begin
            case (i_csr_addr)
                12'h7C0: rt_cfg_reg        <= i_csr_wr_data;
                12'h7C2: watchdog_cfg_reg  <= i_csr_wr_data;
                12'h7C4: ecc_scrub_cfg_reg <= i_csr_wr_data;
                12'h7C6: xdrone_cfg_reg    <= i_csr_wr_data;
                12'h7C9: smu_ctrl_reg      <= i_csr_wr_data;
                12'h7CA: power_cfg_reg     <= i_csr_wr_data;
                default: ; // Read-only or reserved — ignore writes
            endcase
        end
    end

    assign o_rt_cfg        = rt_cfg_reg;
    assign o_watchdog_cfg  = watchdog_cfg_reg;
    assign o_ecc_scrub_cfg = ecc_scrub_cfg_reg;
    assign o_xdrone_cfg    = xdrone_cfg_reg;
    assign o_smu_ctrl      = smu_ctrl_reg;
    assign o_power_cfg     = power_cfg_reg;

endmodule
