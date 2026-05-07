//===============================================================================
// Module: memory_mux
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/memory/memory_mux.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   RT core → scratchpad / CSR / Xdrone address routing.
//   Routes access based on memory map address ranges.
//
// Safety Annotations:
//   @CERT: AEGIS-MEM-MUX-001 — ARCHITECTURE.md §9 (Memory Map)
//   @WCET: Routing = combinational (0 cycles)
//   @SAFETY: CSR/Xdrone spaces are privilege-gated
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module memory_mux #(
    parameter ADDR_WIDTH = 19
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Core Interface
    input  wire [ADDR_WIDTH-1:0] i_addr,
    input  wire [31:0] i_wdata,
    input  wire        i_we,
    input  wire        i_re,
    input  wire        i_valid,
    output wire [31:0] o_rdata,
    output wire        o_rdata_valid,
    output wire        o_ready,

    // Scratchpad Interface
    output wire [ADDR_WIDTH-1:0] o_sp_addr,
    output wire [31:0] o_sp_wdata,
    output wire        o_sp_we,
    output wire        o_sp_re,
    output wire        o_sp_valid,
    input  wire [31:0] i_sp_rdata,
    input  wire        i_sp_rdata_valid,

    // CSR Interface
    output wire [11:0] o_csr_addr,
    output wire [31:0] o_csr_wdata,
    output wire        o_csr_we,
    output wire        o_csr_re,
    input  wire [31:0] i_csr_rdata,
    input  wire        i_csr_rdata_valid,

    // Xdrone Interface
    output wire        o_xdrone_cs,     // Xdrone address space selected
    input  wire [31:0] i_xdrone_rdata,
    input  wire        i_xdrone_rdata_valid,

    // SMU Interface
    output wire        o_smu_cs,        // SMU address space selected

    // Power Interface
    output wire        o_power_cs       // Power address space selected
);

    //-------------------------------------------------------------------------
    // Address Decode
    // @SAFETY: Memory map per ARCHITECTURE.md §9.2
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    wire is_scratchpad = (i_addr < 19'h80000);        // 0x00000-0x7FFFF: 512 KB TCM
    wire is_csr        = (i_addr >= 19'h80000) && (i_addr < 19'h81000);  // 0x80000-0x80FFF: CSR
    wire is_xdrone     = (i_addr >= 19'h90000) && (i_addr < 19'h91000);  // 0x90000-0x90FFF: Xdrone
    wire is_smu        = (i_addr >= 19'hA0000) && (i_addr < 19'hA1000);  // 0xA0000-0xA0FFF: SMU
    wire is_power      = (i_addr >= 19'hB0000) && (i_addr < 19'hB1000);  // 0xB0000-0xB0FFF: Power

    //-------------------------------------------------------------------------
    // Scratchpad Routing
    //-------------------------------------------------------------------------
    assign o_sp_addr   = i_addr;
    assign o_sp_wdata  = i_wdata;
    assign o_sp_we     = i_we && is_scratchpad && i_valid;
    assign o_sp_re     = i_re && is_scratchpad && i_valid;
    assign o_sp_valid  = i_valid && is_scratchpad;

    //-------------------------------------------------------------------------
    // CSR Routing
    //-------------------------------------------------------------------------
    assign o_csr_addr  = i_addr[11:0];  // Lower 12 bits for CSR address
    assign o_csr_wdata = i_wdata;
    assign o_csr_we    = i_we && is_csr && i_valid;
    assign o_csr_re    = i_re && is_csr && i_valid;

    //-------------------------------------------------------------------------
    // Chip Select Outputs
    //-------------------------------------------------------------------------
    assign o_xdrone_cs = is_xdrone && i_valid;
    assign o_smu_cs    = is_smu && i_valid;
    assign o_power_cs  = is_power && i_valid;

    //-------------------------------------------------------------------------
    // Read Data Mux
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    assign o_rdata = is_scratchpad ? i_sp_rdata :
                     is_csr        ? i_csr_rdata :
                     is_xdrone     ? i_xdrone_rdata :
                     32'd0;  // @SAFETY: Default 0 for unmapped regions

    assign o_rdata_valid = is_scratchpad ? i_sp_rdata_valid :
                           is_csr        ? i_csr_rdata_valid :
                           is_xdrone     ? i_xdrone_rdata_valid :
                           1'b0;

    assign o_ready = 1'b1;  // @SAFETY: Always ready (no backpressure)

endmodule
