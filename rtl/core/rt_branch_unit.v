//===============================================================================
// Module: rt_branch_unit
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_branch_unit.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Branch comparator + PC mux with deterministic timing.
//   No cache miss paths — all branches resolve in 1 cycle.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-BRANCH-001 — ARCHITECTURE.md §5 (Determinism)
//   @WCET: Branch resolution = 1 cycle (no cache miss paths)
//   @SAFETY: Fixed branch latency prevents timing side-channels
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_branch_unit (
    input  wire [31:0] i_pc,
    input  wire [31:0] i_rs1_data,
    input  wire [31:0] i_rs2_data,
    input  wire [31:0] i_imm,
    input  wire        i_branch_eq,      // BEQ
    input  wire        i_branch_ne,      // BNE
    input  wire        i_branch_lt,      // BLT
    input  wire        i_branch_ge,      // BGE
    input  wire        i_branch_ltu,     // BLTU
    input  wire        i_branch_geu,     // BGEU
    input  wire        i_jump,           // JAL/JALR
    input  wire        i_irq_redirect,   // IRQ vector redirect
    input  wire [31:0] i_irq_pc_target,  // IRQ handler PC

    output wire        o_branch_taken,
    output wire [31:0] o_branch_target,
    output wire [31:0] o_pc_next
);

    //-------------------------------------------------------------------------
    // Branch Condition Evaluation
    // @WCET: Combinational — 0 cycles
    // @SAFETY: No data-dependent timing (constant evaluation time)
    //-------------------------------------------------------------------------
    reg branch_taken_reg;

    always @* begin
        branch_taken_reg = 1'b0;
        if (i_irq_redirect) begin
            // @SAFETY: IRQ redirect has absolute priority
            branch_taken_reg = 1'b1;
        end else if (i_jump) begin
            branch_taken_reg = 1'b1;
        end else if (i_branch_eq) begin
            branch_taken_reg = (i_rs1_data == i_rs2_data);
        end else if (i_branch_ne) begin
            branch_taken_reg = (i_rs1_data != i_rs2_data);
        end else if (i_branch_lt) begin
            branch_taken_reg = ($signed(i_rs1_data) < $signed(i_rs2_data));
        end else if (i_branch_ge) begin
            branch_taken_reg = ($signed(i_rs1_data) >= $signed(i_rs2_data));
        end else if (i_branch_ltu) begin
            branch_taken_reg = (i_rs1_data < i_rs2_data);
        end else if (i_branch_geu) begin
            branch_taken_reg = (i_rs1_data >= i_rs2_data);
        end
    end

    //-------------------------------------------------------------------------
    // Branch Target Calculation
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    wire [31:0] branch_target = i_pc + i_imm;  // PC-relative branch
    wire [31:0] jump_target   = (i_rs1_data & 32'hFFFFFFFE) + i_imm;  // JALR (LSB=0)

    // Target selection
    reg [31:0] target_reg;
    always @* begin
        if (i_irq_redirect) begin
            target_reg = i_irq_pc_target;
        end else if (i_jump) begin
            target_reg = jump_target;
        end else begin
            target_reg = branch_target;
        end
    end

    assign o_branch_taken  = branch_taken_reg;
    assign o_branch_target = target_reg;
    assign o_pc_next       = branch_taken_reg ? target_reg : (i_pc + 32'd4);

endmodule
