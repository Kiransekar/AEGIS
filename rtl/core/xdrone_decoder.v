//===============================================================================
// Module: xdrone_decoder
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/xdrone_decoder.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Custom opcode decoder for Xdrone instructions (custom-0/custom-1).
//   Decodes RISC-V custom opcodes into Xdrone operation + operand fields.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-XDR-001 — ARCHITECTURE.md §7 (Xdrone Extension)
//   @WCET: Decode = 1 cycle (combinational)
//   @SAFETY: Fixed-latency dispatch for all Xdrone operations
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module xdrone_decoder (
    input  wire [31:0] i_instr,          // Instruction word
    input  wire        i_valid,          // Instruction valid
    output wire        o_xdrone_valid,   // Xdrone instruction detected
    output wire [7:0]  o_xdrone_opcode,  // Decoded Xdrone operation
    output wire [4:0]  o_rd_addr,        // Destination register
    output wire [4:0]  o_rs1_addr,       // Source register 1
    output wire [4:0]  o_rs2_addr,       // Source register 2
    output wire [31:0] o_imm,            // Immediate field
    output wire [3:0]  o_precision,      // Precision mode (from CSR)
    output wire [3:0]  o_max_depth       // Max pipeline depth (from CSR)
);

    //-------------------------------------------------------------------------
    // Opcode Detection
    // @SAFETY: Xdrone uses custom-0 (0x0B) and custom-1 (0x2B) opcode space
    //-------------------------------------------------------------------------
    wire [6:0] opcode = i_instr[6:0];
    wire is_custom0 = (opcode == 7'h0B);  // custom-0
    wire is_custom1 = (opcode == 7'h2B);  // custom-1

    assign o_xdrone_valid = i_valid && (is_custom0 || is_custom1);

    //-------------------------------------------------------------------------
    // Field Extraction
    // @SAFETY: R-type format for Xdrone instructions
    //-------------------------------------------------------------------------
    assign o_rd_addr  = i_instr[11:7];
    assign o_rs1_addr = i_instr[19:15];
    assign o_rs2_addr = i_instr[24:20];

    // Xdrone-specific function code from funct3 + funct7
    // custom-0: funct3[14:12] + funct7[31:25] → 10-bit operation code
    // Simplified: lower 7 bits of funct7 for primary operation
    assign o_xdrone_opcode = {is_custom1, i_instr[31:25]};

    // Immediate (for I-type custom instructions)
    assign o_imm = {{20{i_instr[31]}}, i_instr[31:20]};

    // Precision and depth from CSR (hardwired stubs for Phase 1)
    assign o_precision = 4'd0;
    assign o_max_depth = 4'd0;

endmodule
