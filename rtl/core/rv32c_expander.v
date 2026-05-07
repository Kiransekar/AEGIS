//===============================================================================
// Module: rv32c_expander
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rv32c_expander.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Expands RV32C 16-bit compressed instructions into their 32-bit equivalents.
//   Operates in the IF stage before the decoder, ensuring the decoder
//   only sees standard 32-bit instructions.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-C-001 — ARCHITECTURE.md §3 (Compressed ISA)
//   @WCET: Expansion = combinational (0 cycles, in-line with fetch)
//   @SAFETY: Unrecognized compressed instructions → illegal 32-bit instruction
//   @SAFETY: Expansion is deterministic — no data-dependent timing
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rv32c_expander (
    input  wire [15:0] i_cinstr,         // 16-bit compressed instruction
    input  wire        i_valid,           // Instruction valid
    output wire [31:0] o_instr,          // Expanded 32-bit instruction
    output wire        o_is_compressed,   // Input was compressed
    output wire        o_illegal          // Illegal compressed instruction
);

    //-------------------------------------------------------------------------
    // Compressed instruction field extraction
    //-------------------------------------------------------------------------
    wire [1:0]  op     = i_cinstr[1:0];   // Quadrant (0,1,2)
    wire [2:0]  funct3 = i_cinstr[15:13];
    wire [4:0]  rd     = i_cinstr[11:7];
    wire [4:0]  rs1    = i_cinstr[11:7];  // Overlaps rd in some formats
    wire [2:0]  rs1c   = i_cinstr[9:7];   // Compressed rs1 (x8-x15)
    wire [2:0]  rs2c   = i_cinstr[4:2];   // Compressed rs2 (x8-x15)
    wire [4:0]  rs2    = i_cinstr[6:2];   // Full rs2
    wire [5:0]  imm6   = i_cinstr[12:7];  // 6-bit immediate
    wire [4:0]  imm5   = i_cinstr[12:8];  // 5-bit immediate (shift)

    // Decompressed register mapping: rs1c/rs2c → x8+x
    wire [4:0] rs1c_full = {2'b01, rs1c};  // x8-x15
    wire [4:0] rs2c_full = {2'b01, rs2c};  // x8-x15

    //-------------------------------------------------------------------------
    // Expansion result
    // @SAFETY: Default = illegal instruction (0x00000000 = ADDI x0, x0, 0)
    //          Illegal compressed → 0x00000000 with o_illegal flag
    //-------------------------------------------------------------------------
    reg [31:0] expanded;
    reg        is_compressed_reg;
    reg        illegal_reg;

    always @* begin
        expanded          = 32'd0;
        is_compressed_reg = 1'b0;
        illegal_reg       = 1'b0;

        if (!i_valid) begin
            // No instruction
        end else if (op != 2'b11) begin
            // Compressed instruction detected
            is_compressed_reg = 1'b1;

            case (op)
                //-------------------------------------------------------------
                // Quadrant 0: C.LW / C.SW / C.LWSP
                //-------------------------------------------------------------
                2'b00: begin
                    case (funct3)
                        3'b010: begin
                            // C.LW — loads word from memory
                            // I-type: LW rd', offset(rs1')
                            // offset = {imm[5:3], imm[2|6], 2'b00}
                            begin : c_lw
                                reg [4:0] offset;
                                offset = {i_cinstr[12:10], i_cinstr[6], 2'b00};
                                expanded = {7'd0, offset[5], offset[4:2], rs1c_full,
                                            3'b010, rs2c_full, 7'h03};
                            end
                        end
                        3'b110: begin
                            // C.SW — stores word to memory
                            // S-type: SW rs2', offset(rs1')
                            begin : c_sw
                                reg [4:0] offset;
                                offset = {i_cinstr[12:10], i_cinstr[6], 2'b00};
                                expanded = {7'd0, offset[5], rs2c_full, rs1c_full,
                                            3'b010, offset[4:2], 7'h23};
                            end
                        end
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // Quadrant 1: C.J / C.JAL / C.BEQZ / C.BNEZ / C.LI /
                //             C.LUI / C.ADDI / C.ADDI16SP / C.SRLI /
                //             C.SRAI / C.ANDI / C.SUB / C.XOR / C.OR /
                //             C.AND / C.JR / C.JALR / C.MV / C.ADD /
                //             C.LWSP / C.SWSP
                //-------------------------------------------------------------
                2'b01: begin
                    case (funct3)
                        3'b000: begin
                            // C.ADDI — add immediate to x0 or rd
                            // C.NOP if rd=0
                            expanded = {{22{i_cinstr[12]}}, i_cinstr[12], i_cinstr[6:2],
                                        5'd0, 3'b000, rd, 7'h13};
                        end
                        3'b001: begin
                            // C.JAL — jump and link (rd=x1)
                            // J-type: JAL x1, offset
                            begin : c_jal
                                reg [11:0] offset;
                                offset = {i_cinstr[12], i_cinstr[8], i_cinstr[10:9],
                                          i_cinstr[6], i_cinstr[7], i_cinstr[1:0], 1'b0};
                                expanded = {{9{offset[11]}}, offset[11], offset[9:0],
                                            5'd1, 7'h6F};
                            end
                        end
                        3'b010: begin
                            // C.LI — load immediate
                            expanded = {{22{i_cinstr[12]}}, i_cinstr[12], i_cinstr[6:2],
                                        5'd0, 3'b000, rd, 7'h13};
                        end
                        3'b011: begin
                            // C.LUI — load upper immediate
                            if (rd == 5'd2) begin
                                // C.ADDI16SP — add immediate to sp
                                begin : c_addi16sp
                                    reg [9:0] offset;
                                    offset = {i_cinstr[12], i_cinstr[4:3], i_cinstr[5],
                                              i_cinstr[2], i_cinstr[6], 4'd0};
                                    expanded = {{22{offset[9]}}, offset[9:0],
                                                5'd2, 3'b000, 5'd2, 7'h13};
                                end
                            end else begin
                                // C.LUI — load upper immediate
                                expanded = {{22{i_cinstr[12]}}, i_cinstr[12], i_cinstr[6:2],
                                            rd, 7'h37};
                            end
                        end
                        3'b100: begin
                            // Various ALU ops based on funct2
                            case (i_cinstr[11:10])
                                2'b00: begin
                                    // C.SRLI
                                    expanded = {1'b0, i_cinstr[5], 5'd0, i_cinstr[4:2],
                                                rs1c_full, 3'b101, rs1c_full, 7'h13};
                                end
                                2'b01: begin
                                    // C.SRAI
                                    expanded = {1'b1, i_cinstr[5], 5'd0, i_cinstr[4:2],
                                                rs1c_full, 3'b101, rs1c_full, 7'h13};
                                end
                                2'b10: begin
                                    // C.ANDI
                                    expanded = {{22{i_cinstr[12]}}, i_cinstr[12], i_cinstr[6:2],
                                                rs1c_full, 3'b111, rs1c_full, 7'h13};
                                end
                                2'b11: begin
                                    // C.SUB / C.XOR / C.OR / C.AND
                                    case (i_cinstr[12])
                                        1'b0: begin
                                            case (i_cinstr[6:5])
                                                2'b00: expanded = {7'h20, rs2c_full, rs1c_full,
                                                                   3'b000, rs1c_full, 7'h33};  // C.SUB
                                                2'b01: expanded = {7'd0, rs2c_full, rs1c_full,
                                                                   3'b100, rs1c_full, 7'h33};  // C.XOR
                                                2'b10: expanded = {7'd0, rs2c_full, rs1c_full,
                                                                   3'b110, rs1c_full, 7'h33};  // C.OR
                                                2'b11: expanded = {7'd0, rs2c_full, rs1c_full,
                                                                   3'b111, rs1c_full, 7'h33};  // C.AND
                                            endcase
                                        end
                                        default: illegal_reg = 1'b1;
                                    endcase
                                end
                            endcase
                        end
                        3'b101: begin
                            // C.J — jump (no link)
                            begin : c_j
                                reg [11:0] offset;
                                offset = {i_cinstr[12], i_cinstr[8], i_cinstr[10:9],
                                          i_cinstr[6], i_cinstr[7], i_cinstr[1:0], 1'b0};
                                expanded = {{9{offset[11]}}, offset[11], offset[9:0],
                                            5'd0, 7'h6F};
                            end
                        end
                        3'b110: begin
                            // C.BEQZ — branch if rs1' == 0
                            begin : c_beqz
                                reg [7:0] offset;
                                offset = {i_cinstr[12:10], i_cinstr[6:5], i_cinstr[2],
                                           i_cinstr[11], i_cinstr[7], 1'b0};
                                expanded = {{19{offset[7]}}, offset[7], offset[0],
                                            offset[5:2], rs1c_full, 3'b000,
                                            offset[6:1], 7'h63};
                            end
                        end
                        3'b111: begin
                            // C.BNEZ — branch if rs1' != 0
                            begin : c_bnez
                                reg [7:0] offset;
                                offset = {i_cinstr[12:10], i_cinstr[6:5], i_cinstr[2],
                                           i_cinstr[11], i_cinstr[7], 1'b0};
                                expanded = {{19{offset[7]}}, offset[7], offset[0],
                                            offset[5:2], rs1c_full, 3'b001,
                                            offset[6:1], 7'h63};
                            end
                        end
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // Quadrant 2: C.SLLI / C.LWSP / C.SWSP / C.JR / C.JALR /
                //             C.MV / C.ADD / C.EBREAK
                //-------------------------------------------------------------
                2'b10: begin
                    case (funct3)
                        3'b000: begin
                            // C.SLLI — shift left logical immediate
                            expanded = {1'b0, i_cinstr[5], 5'd0, i_cinstr[4:2],
                                        rd, 3'b001, rd, 7'h13};
                        end
                        3'b010: begin
                            // C.LWSP — load word from stack pointer
                            begin : c_lwsp
                                reg [4:0] offset;
                                offset = {i_cinstr[12], i_cinstr[4:3], i_cinstr[2],
                                           2'b00};
                                expanded = {7'd0, offset[5], offset[4:2], 5'd2,
                                            3'b010, rd, 7'h03};
                            end
                        end
                        3'b100: begin
                            if (i_cinstr[12]) begin
                                // C.JALR / C.EBREAK
                                if (rs1 == 5'd0) begin
                                    // C.EBREAK
                                    expanded = 32'h00100073;  // EBREAK
                                end else begin
                                    // C.JALR — jump and link register
                                    expanded = {12'd0, rs1, 3'b000, 5'd1, 7'h67};
                                end
                            end else begin
                                // C.JR / C.MV
                                if (rs2 == 5'd0) begin
                                    // C.JR — jump register
                                    expanded = {12'd0, rs1, 3'b000, 5'd0, 7'h67};
                                end else begin
                                    // C.MV — move rs2 to rd
                                    expanded = {7'd0, rs2, 5'd0, 3'b000, rd, 7'h33};
                                end
                            end
                        end
                        3'b110: begin
                            // C.SWSP — store word to stack pointer
                            begin : c_swsp
                                reg [4:0] offset;
                                offset = {i_cinstr[12:9], i_cinstr[8:7], 2'b00};
                                expanded = {7'd0, offset[5:2], rs2, 5'd2,
                                            3'b010, offset[1:0], 7'h23};
                            end
                        end
                        default: illegal_reg = 1'b1;
                    endcase
                end

                default: illegal_reg = 1'b1;
            endcase
        end else begin
            // Not compressed — pass through unchanged
            expanded = {16'd0, i_cinstr};
        end
    end

    assign o_instr         = expanded;
    assign o_is_compressed = is_compressed_reg;
    assign o_illegal       = illegal_reg;

endmodule
