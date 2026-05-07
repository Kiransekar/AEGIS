//===============================================================================
// Module: rt_pipeline_if
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_pipeline_if.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Pipeline interface signals for 4-stage RT core (IF → ID → EX → WB).
//   Struct-like bundle using separate wires (Verilog 2001 compatible).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-PIPE-001 — Pipeline interface (ARCHITECTURE.md §3)
//   @WCET: Pipeline stages advance every cycle (no stalls in normal operation)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_pipeline_if (
    // IF/ID Stage Interface
    input  wire [31:0] if_pc,
    input  wire [31:0] if_instr,
    input  wire        if_valid,
    output wire        if_ready,

    // ID/EX Stage Interface
    input  wire [31:0] id_pc,
    input  wire [31:0] id_rs1_data,
    input  wire [31:0] id_rs2_data,
    input  wire [31:0] id_imm,
    input  wire [4:0]  id_rd_addr,
    input  wire [3:0]  id_alu_op,
    input  wire        id_alu_use_imm,
    input  wire        id_mem_we,
    input  wire        id_mem_re,
    input  wire        id_reg_we,
    input  wire        id_branch,
    input  wire        id_xdrone_valid,
    input  wire [31:0] id_xdrone_opcode,
    input  wire        id_valid,
    output wire        id_ready,

    // EX/WB Stage Interface
    input  wire [31:0] ex_pc,
    input  wire [31:0] ex_alu_result,
    input  wire [4:0]  ex_rd_addr,
    input  wire        ex_reg_we,
    input  wire        ex_mem_we,
    input  wire [31:0] ex_mem_wdata,
    input  wire        ex_valid,
    output wire        ex_ready,

    // WB Stage Interface
    input  wire [31:0] wb_result,
    input  wire [4:0]  wb_rd_addr,
    input  wire        wb_reg_we,
    input  wire        wb_valid,

    // Pipeline Control
    input  wire        i_stall,        // Pipeline stall (e.g., TCM bank conflict)
    input  wire        i_flush,        // Pipeline flush (e.g., branch mispredict)
    input  wire        i_clk,
    input  wire        i_rst_n
);

    // @SAFETY: Pipeline always advances unless stalled
    // @WCET: No stalls in normal operation (TCM 1-cycle, no cache)
    assign if_ready = !i_stall;
    assign id_ready = !i_stall;
    assign ex_ready = !i_stall;

endmodule
