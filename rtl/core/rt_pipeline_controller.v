//===============================================================================
// Module: rt_pipeline_controller
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_pipeline_controller.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Pipeline hazard detection and forwarding control for the 4-stage
//   RT pipeline. Handles data hazards (RAW), control hazards (branch),
//   and structural hazards (MULDIV/FPU multi-cycle).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-PIPE-001 — ARCHITECTURE.md §3 (Pipeline)
//   @WCET: Hazard detection = combinational (0 cycles)
//   @SAFETY: No data hazard may produce incorrect result — stall or forward
//   @SAFETY: All stalls are deterministic — no data-dependent stall duration
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_pipeline_controller (
    // Decode stage signals
    input  wire [4:0]  id_rs1_addr,
    input  wire [4:0]  id_rs2_addr,
    input  wire [4:0]  id_rd_addr,
    input  wire        id_reg_we,
    input  wire        id_mem_re,
    input  wire        id_mem_we,

    // Execute stage signals
    input  wire [4:0]  ex_rs1_addr,
    input  wire [4:0]  ex_rs2_addr,
    input  wire [4:0]  ex_rd_addr,
    input  wire        ex_reg_we,
    input  wire        ex_mem_re,
    input  wire        ex_mem_we,
    input  wire        ex_fpu_req,
    input  wire        ex_muldiv_req,
    input  wire        ex_muldiv_busy,
    input  wire        ex_xdrone_valid,
    input  wire        ex_xdrone_done,

    // Writeback stage signals
    input  wire [4:0]  wb_rd_addr,
    input  wire        wb_reg_we,

    // Hazard detection outputs
    output wire        o_stall_fetch,     // Stall IF stage
    output wire        o_stall_decode,    // Stall ID stage
    output wire        o_flush_decode,    // Flush ID stage (branch taken)
    output wire        o_flush_execute,   // Flush EX stage

    // Forwarding control
    output wire [1:0]  o_fwd_rs1_sel,    // 00=none, 01=EX, 10=WB
    output wire [1:0]  o_fwd_rs2_sel     // 00=none, 01=EX, 10=WB
);

    //-------------------------------------------------------------------------
    // Data Hazard Detection (RAW — Read After Write)
    // @SAFETY: Detect when decode reads a register that execute or writeback
    //          will write. Forward when possible, stall when not.
    //-------------------------------------------------------------------------

    // EX hazard: decode reads register that EX will write
    wire ex_rs1_hazard = (id_rs1_addr != 5'd0) && (id_rs1_addr == ex_rd_addr) && ex_reg_we;
    wire ex_rs2_hazard = (id_rs2_addr != 5'd0) && (id_rs2_addr == ex_rd_addr) && ex_reg_we;

    // WB hazard: decode reads register that WB will write
    wire wb_rs1_hazard = (id_rs1_addr != 5'd0) && (id_rs1_addr == wb_rd_addr) && wb_reg_we;
    wire wb_rs2_hazard = (id_rs2_addr != 5'd0) && (id_rs2_addr == wb_rd_addr) && wb_reg_we;

    // Load-use hazard: EX stage is a load, decode uses the loaded register
    // @SAFETY: Must stall 1 cycle — load data not available until WB
    wire load_use_rs1 = ex_rs1_hazard && ex_mem_re;
    wire load_use_rs2 = ex_rs2_hazard && ex_mem_re;
    wire load_use_hazard = load_use_rs1 || load_use_rs2;

    //-------------------------------------------------------------------------
    // Structural Hazard Detection
    // @SAFETY: MULDIV/FPU/Xdrone occupy EX for multiple cycles
    //-------------------------------------------------------------------------
    wire structural_hazard = ex_muldiv_busy || (ex_xdrone_valid && !ex_xdrone_done);

    //-------------------------------------------------------------------------
    // Stall Logic
    // @WCET: Stall duration is deterministic (1 cycle for load-use,
    //         variable but bounded for MULDIV/FPU)
    //-------------------------------------------------------------------------
    assign o_stall_fetch  = load_use_hazard || structural_hazard;
    assign o_stall_decode = load_use_hazard || structural_hazard;

    // @SAFETY: Flush on branch mispredict (not implemented in Phase 2 —
    //          simple in-order pipeline with no speculation)
    assign o_flush_decode  = 1'b0;
    assign o_flush_execute = 1'b0;

    //-------------------------------------------------------------------------
    // Forwarding Control
    // @SAFETY: Forward from EX or WB to avoid unnecessary stalls
    //          Priority: EX > WB (most recent write wins)
    //-------------------------------------------------------------------------
    assign o_fwd_rs1_sel = ex_rs1_hazard ? 2'd2 :  // Forward from EX
                           wb_rs1_hazard ? 2'd3 :  // Forward from WB
                           2'd00;                    // No forward

    assign o_fwd_rs2_sel = ex_rs2_hazard ? 2'd2 :
                           wb_rs2_hazard ? 2'd3 :
                           2'd00;

endmodule
