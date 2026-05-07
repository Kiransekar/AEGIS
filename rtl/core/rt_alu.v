//===============================================================================
// Module: rt_alu
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_alu.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   ALU for RT core: integer operations only.
//   Deterministic timing — all operations complete in 1 cycle.
//   FPU operations are handled by rt_fpu (separate module).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-ALU-001 — ARCHITECTURE.md §3 (ALU)
//   @WCET: All integer ops = 1 cycle
//   @SAFETY: FPU ops delegated to rt_fpu with FTZ mode
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_alu #(
    parameter DATA_WIDTH = 32
) (
    input  wire [3:0]  i_alu_op,        // ALU operation select
    input  wire [DATA_WIDTH-1:0] i_operand_a,
    input  wire [DATA_WIDTH-1:0] i_operand_b,
    input  wire        i_use_imm,       // Use immediate for operand_b
    input  wire [DATA_WIDTH-1:0] i_imm, // Immediate value
    output wire [DATA_WIDTH-1:0] o_result,
    output wire        o_zero,          // Result is zero
    output wire        o_negative,      // Result is negative (MSB)
    output wire        o_overflow       // Overflow detected
);

    // ALU Operation Encoding
    localparam [3:0] ALU_ADD  = 4'd0;
    localparam [3:0] ALU_SUB  = 4'd1;
    localparam [3:0] ALU_AND  = 4'd2;
    localparam [3:0] ALU_OR   = 4'd3;
    localparam [3:0] ALU_XOR  = 4'd4;
    localparam [3:0] ALU_SLT  = 4'd5;
    localparam [3:0] ALU_SLTU = 4'd6;
    localparam [3:0] ALU_SLL  = 4'd7;
    localparam [3:0] ALU_SRL  = 4'd8;
    localparam [3:0] ALU_SRA  = 4'd9;
    localparam [3:0] ALU_FADD = 4'd10;  // FPU add (delegated to rt_fpu)
    localparam [3:0] ALU_FMUL = 4'd11;  // FPU multiply (delegated to rt_fpu)
    localparam [3:0] ALU_PASS_A = 4'd12; // Pass operand A through
    localparam [3:0] ALU_PASS_B = 4'd13; // Pass operand B through

    // Operand B selection
    wire [DATA_WIDTH-1:0] operand_b = i_use_imm ? i_imm : i_operand_b;

    // Shift amount (lower 5 bits)
    wire [4:0] shift_amount = operand_b[4:0];

    //-------------------------------------------------------------------------
    // Integer ALU
    // @WCET: All operations combinational — 1 cycle
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] alu_result;
    reg overflow_reg;

    always @* begin
        alu_result = {DATA_WIDTH{1'b0}};
        overflow_reg = 1'b0;

        case (i_alu_op)
            ALU_ADD: begin
                {overflow_reg, alu_result} = {1'b0, i_operand_a} + {1'b0, operand_b};
            end
            ALU_SUB: begin
                {overflow_reg, alu_result} = {1'b0, i_operand_a} - {1'b0, operand_b};
            end
            ALU_AND:  alu_result = i_operand_a & operand_b;
            ALU_OR:   alu_result = i_operand_a | operand_b;
            ALU_XOR:  alu_result = i_operand_a ^ operand_b;
            ALU_SLT:  alu_result = ($signed(i_operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (i_operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_SLL:  alu_result = i_operand_a << shift_amount;
            ALU_SRL:  alu_result = i_operand_a >> shift_amount;
            ALU_SRA:  alu_result = $signed(i_operand_a) >>> shift_amount;
            ALU_PASS_A: alu_result = i_operand_a;
            ALU_PASS_B: alu_result = operand_b;
            // @SAFETY: FPU ops delegated to rt_fpu — ALU returns 0 if reached
            ALU_FADD: alu_result = {DATA_WIDTH{1'b0}};
            ALU_FMUL: alu_result = {DATA_WIDTH{1'b0}};
            default:  alu_result = {DATA_WIDTH{1'b0}}; // @SAFETY: Default prevents latch
        endcase
    end

    assign o_result   = alu_result;
    assign o_zero     = (alu_result == {DATA_WIDTH{1'b0}});
    assign o_negative = alu_result[DATA_WIDTH-1];
    assign o_overflow = overflow_reg;

endmodule
