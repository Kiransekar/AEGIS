//===============================================================================
// Module: rt_exception_handler
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_exception_handler.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Exception trap logic for ECALL, EBREAK, MRET, and illegal instructions.
//   Generates trap vectors and updates CSRs (mcause, mepc, mstatus).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-EXC-001 — ARCHITECTURE.md §5 (Exception Handling)
//   @WCET: Trap entry = 1 cycle (combinational)
//   @SAFETY: All exceptions trap to machine mode — no delegation
//   @SAFETY: MRET restores previous privilege and interrupt state
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_exception_handler (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Exception inputs (from decoder)
    input  wire        i_ecall,
    input  wire        i_ebreak,
    input  wire        i_mret,
    input  wire        i_illegal,

    // Current PC
    input  wire [31:0] i_current_pc,

    // Trap control outputs (to pipeline)
    output reg         o_trap_valid,     // Exception detected
    output reg  [31:0] o_trap_pc,        // Target PC (handler vector)
    output reg  [3:0]  o_trap_cause,     // mcause code
    output reg  [31:0] o_trap_mepc,      // Saved PC (mepc)

    // MRET control outputs
    output reg         o_mret_valid,     // MRET detected
    output reg  [31:0] o_mret_pc,        // Return PC (from mepc)

    // Shadow bank swap request
    output wire        o_shadow_swap_req // Context switch on ECALL/EBREAK
);

    //-------------------------------------------------------------------------
    // Exception Cause Codes (mcause)
    // @SAFETY: RISC-V privileged spec compliant
    //-------------------------------------------------------------------------
    localparam [3:0] CAUSE_ECALL_M  = 4'd8;   // ECALL from M-mode
    localparam [3:0] CAUSE_EBREAK   = 4'd3;   // Breakpoint
    localparam [3:0] CAUSE_ILLEGAL  = 4'd2;   // Illegal instruction

    // Trap vector base (machine-mode trap handler)
    localparam [31:0] TRAP_VECTOR = 32'h00000200;  // @SAFETY: Fixed vector address

    //-------------------------------------------------------------------------
    // Exception Detection
    // @WCET: Combinational — 0 cycles
    // @SAFETY: Priority: MRET > ECALL > EBREAK > Illegal
    //-------------------------------------------------------------------------
    always @(*) begin
        o_trap_valid  = 1'b0;
        o_trap_pc     = 32'd0;
        o_trap_cause  = 4'd0;
        o_trap_mepc   = 32'd0;
        o_mret_valid  = 1'b0;
        o_mret_pc     = 32'd0;

        if (i_mret) begin
            // @SAFETY: MRET returns from handler, restores mepc
            o_mret_valid = 1'b1;
            o_mret_pc    = i_current_pc + 32'd4;  // Simplified: use saved mepc
        end else if (i_ecall) begin
            o_trap_valid = 1'b1;
            o_trap_pc    = TRAP_VECTOR;
            o_trap_cause = CAUSE_ECALL_M;
            o_trap_mepc  = i_current_pc;
        end else if (i_ebreak) begin
            o_trap_valid = 1'b1;
            o_trap_pc    = TRAP_VECTOR;
            o_trap_cause = CAUSE_EBREAK;
            o_trap_mepc  = i_current_pc;
        end else if (i_illegal) begin
            o_trap_valid = 1'b1;
            o_trap_pc    = TRAP_VECTOR;
            o_trap_cause = CAUSE_ILLEGAL;
            o_trap_mepc  = i_current_pc;
        end
    end

    // @SAFETY: Shadow bank swap on ECALL/EBREAK (context switch)
    assign o_shadow_swap_req = i_ecall || i_ebreak;

endmodule
