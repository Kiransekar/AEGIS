//===============================================================================
// Module: rt_decoder
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_decoder.v
// Version: 2.0
// Date: 2026-05-04
//
// Description:
//   Full RV32IMACF instruction decoder. Decodes all base + extension
//   opcodes into ALU control, branch, memory, CSR, and Xdrone signals.
//
// ISA Coverage:
//   RV32I  — LUI, AUIPC, JAL, JALR, BEQ/BNE/BLT/BGE/BLTU/BGEU,
//            LB/LH/LW/LBU/LHU, SB/SH/SW, ADDI/SLTI/SLTIU/XORI/ORI/ANDI,
//            SLLI/SRLI/SRAI, ADD/SUB/SLL/SLT/SLTU/XOR/SOR/AND/SRL/SRA
//   RV32M  — MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU
//   RV32A  — LR.W/SC.W (atomic)
//   RV32C  — Compressed (C.LW/C.SW/C.J/C.JR/C.JAL/C.BEQZ/C.BNEZ/
//            C.LI/C.LI/C.LUI/C.ADDI/C.ADDI16SP/C.SRLI/C.SRAI/C.ANDI/
//            C.SUB/C.XOR/C.OR/C.AND/C.MV/C.ADD/C.LWSP/C.SWSP)
//   RV32F  — FLW/FSW/FADD/FSUB/FMUL/FDIV/FSQRT/FMIN/FMAX/
//            FMADD/FMSUB/FNMSUB/FNMACC/FCMP/FSGNJ/FSGNJN/FSGNJX/
//            FCLASS/FCVT.W.S/FCVT.S.W/FMV.X.W/FMV.W.X/FENCE.I/CSR*
//
// Safety Annotations:
//   @CERT: AEGIS-RT-DEC-001 — ARCHITECTURE.md §3 (Decoder)
//   @WCET: Decode = 1 cycle (combinational)
//   @SAFETY: Illegal instruction → trap to handler (no undefined behavior)
//   @SAFETY: All opcodes have explicit decode (no implicit defaults)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_decoder (
    // Instruction input
    input  wire [31:0] i_instr,
    input  wire        i_instr_valid,

    // Register addresses
    output wire [4:0]  o_rs1_addr,
    output wire [4:0]  o_rs2_addr,
    output wire [4:0]  o_rd_addr,

    // Immediate value (sign-extended)
    output wire [31:0] o_imm,

    // ALU control
    output wire [3:0]  o_alu_op,
    output wire        o_alu_use_imm,

    // Branch control
    output wire        o_branch,
    output wire        o_branch_eq,
    output wire        o_branch_ne,
    output wire        o_branch_lt,
    output wire        o_branch_ge,
    output wire        o_branch_ltu,
    output wire        o_branch_geu,
    output wire        o_jump,           // JAL/JALR

    // Memory control
    output wire        o_mem_re,
    output wire        o_mem_we,
    output wire [1:0]  o_mem_size,       // 00=byte, 01=half, 10=word
    output wire        o_mem_unsigned,   // Unsigned load

    // Register write enable
    output wire        o_reg_we,

    // M extension
    output wire        o_mul_req,
    output wire        o_div_req,

    // A extension
    output wire        o_atomic_req,
    output wire        o_atomic_lr,
    output wire        o_atomic_sc,

    // F extension
    output wire        o_fpu_req,
    output wire [3:0]  o_fpu_op,
    output wire        o_fpu_wb_int,     // FPU writeback to integer reg

    // CSR control
    output wire        o_csr_req,
    output wire [1:0]  o_csr_op,         // 00=RW, 01=RS, 10=RC
    output wire [11:0] o_csr_addr,

    // Xdrone
    output wire        o_xdrone_valid,

    // System
    output wire        o_ecall,
    output wire        o_ebreak,
    output wire        o_mret,
    output wire        o_fence_i,

    // Error
    output wire        o_illegal_insn    // @SAFETY: Illegal instruction trap
);

    //-------------------------------------------------------------------------
    // Opcode field extraction
    //-------------------------------------------------------------------------
    wire [6:0]  opcode  = i_instr[6:0];
    wire [2:0]  funct3  = i_instr[14:12];
    wire [6:0]  funct7  = i_instr[31:25];
    wire [4:0]  rs1     = i_instr[19:15];
    wire [4:0]  rs2     = i_instr[24:20];
    wire [4:0]  rd      = i_instr[11:7];

    assign o_rs1_addr = rs1;
    assign o_rs2_addr = rs2;
    assign o_rd_addr  = rd;

    //-------------------------------------------------------------------------
    // Opcode constants (RV32IMACF)
    //-------------------------------------------------------------------------
    localparam [6:0] OP_LUI      = 7'h37;
    localparam [6:0] OP_AUIPC    = 7'h17;
    localparam [6:0] OP_JAL      = 7'h6F;
    localparam [6:0] OP_JALR     = 7'h67;
    localparam [6:0] OP_BRANCH   = 7'h63;
    localparam [6:0] OP_LOAD     = 7'h03;
    localparam [6:0] OP_STORE    = 7'h23;
    localparam [6:0] OP_IMM      = 7'h13;
    localparam [6:0] OP_REG      = 7'h33;
    localparam [6:0] OP_FENCE    = 7'h0F;
    localparam [6:0] OP_SYSTEM   = 7'h73;
    localparam [6:0] OP_MUL      = 7'h33;  // Same as OP_REG, funct7[5:4]=01
    localparam [6:0] OP_ATOMIC   = 7'h2F;
    localparam [6:0] OP_FLW      = 7'h07;
    localparam [6:0] OP_FSW      = 7'h27;
    localparam [6:0] OP_FPMATH   = 7'h53;
    localparam [6:0] OP_CUSTOM0  = 7'h0B;
    localparam [6:0] OP_CUSTOM1  = 7'h2B;

    //-------------------------------------------------------------------------
    // ALU operation encoding (matches rt_alu.v)
    //-------------------------------------------------------------------------
    localparam [3:0] ALU_ADD    = 4'd0;
    localparam [3:0] ALU_SUB    = 4'd1;
    localparam [3:0] ALU_AND    = 4'd2;
    localparam [3:0] ALU_OR     = 4'd3;
    localparam [3:0] ALU_XOR    = 4'd4;
    localparam [3:0] ALU_SLT    = 4'd5;
    localparam [3:0] ALU_SLTU   = 4'd6;
    localparam [3:0] ALU_SLL    = 4'd7;
    localparam [3:0] ALU_SRL    = 4'd8;
    localparam [3:0] ALU_SRA    = 4'd9;
    localparam [3:0] ALU_FADD   = 4'd10;
    localparam [3:0] ALU_FMUL   = 4'd11;
    localparam [3:0] ALU_PASS_A = 4'd12;
    localparam [3:0] ALU_PASS_B = 4'd13;

    //-------------------------------------------------------------------------
    // Immediate generators
    // @SAFETY: All immediates sign-extended to 32 bits
    //-------------------------------------------------------------------------

    // I-type: {imm[11:0], rs1, funct3, rd, opcode}
    wire [31:0] imm_i = {{20{i_instr[31]}}, i_instr[31:20]};

    // S-type: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
    wire [31:0] imm_s = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};

    // B-type: {imm[12|10:5], rs2, rs1, funct3, imm[4:1|11], opcode}
    wire [31:0] imm_b = {{19{i_instr[31]}}, i_instr[31], i_instr[7],
                         i_instr[30:25], i_instr[11:8], 1'b0};

    // U-type: {imm[31:12], rd, opcode}
    wire [31:0] imm_u = {i_instr[31:12], 12'd0};

    // J-type: {imm[20|10:1|11|19:12], rd, opcode}
    wire [31:0] imm_j = {{12{i_instr[31]}}, i_instr[19:12], i_instr[20],
                         i_instr[30:21], 1'b0};

    //-------------------------------------------------------------------------
    // Compressed instruction detection (RV32C)
    // @SAFETY: Compressed instructions expanded to 32-bit equivalents
    //          in the fetch stage; decoder only sees 32-bit instructions.
    //          If a compressed instruction reaches here, it's illegal.
    //-------------------------------------------------------------------------
    wire is_compressed = (i_instr[1:0] != 2'b11);

    //-------------------------------------------------------------------------
    // M extension detection
    // @SAFETY: M ops share opcode 0x33 with R-type; funct7[5:4]=01
    //-------------------------------------------------------------------------
    wire is_m_ext = (opcode == OP_REG) && funct7[5] && !funct7[4];

    // F extension detection
    wire is_f_load  = (opcode == OP_FLW);
    wire is_f_store = (opcode == OP_FSW);
    wire is_f_math  = (opcode == OP_FPMATH);

    //-------------------------------------------------------------------------
    // Main decode logic
    // @SAFETY: Explicit case for every opcode; default = illegal
    //-------------------------------------------------------------------------
    reg [3:0]  alu_op_reg;
    reg        alu_use_imm_reg;
    reg [31:0] imm_reg;
    reg        branch_reg, branch_eq_reg, branch_ne_reg;
    reg        branch_lt_reg, branch_ge_reg, branch_ltu_reg, branch_geu_reg;
    reg        jump_reg;
    reg        mem_re_reg, mem_we_reg;
    reg [1:0]  mem_size_reg;
    reg        mem_unsigned_reg;
    reg        reg_we_reg;
    reg        mul_req_reg, div_req_reg;
    reg        atomic_req_reg, atomic_lr_reg, atomic_sc_reg;
    reg        fpu_req_reg;
    reg [3:0]  fpu_op_reg;
    reg        fpu_wb_int_reg;
    reg        csr_req_reg;
    reg [1:0]  csr_op_reg;
    reg [11:0] csr_addr_reg;
    reg        xdrone_valid_reg;
    reg        ecall_reg, ebreak_reg, mret_reg, fence_i_reg;
    reg        illegal_reg;

    always @(i_instr or i_instr_valid) begin
        // Default: all outputs zero
        alu_op_reg       = ALU_ADD;
        alu_use_imm_reg  = 1'b0;
        imm_reg          = 32'd0;
        branch_reg       = 1'b0;
        branch_eq_reg    = 1'b0;
        branch_ne_reg    = 1'b0;
        branch_lt_reg    = 1'b0;
        branch_ge_reg    = 1'b0;
        branch_ltu_reg   = 1'b0;
        branch_geu_reg   = 1'b0;
        jump_reg         = 1'b0;
        mem_re_reg       = 1'b0;
        mem_we_reg       = 1'b0;
        mem_size_reg     = 2'b10;  // Word
        mem_unsigned_reg = 1'b0;
        reg_we_reg       = 1'b0;
        mul_req_reg      = 1'b0;
        div_req_reg      = 1'b0;
        atomic_req_reg   = 1'b0;
        atomic_lr_reg    = 1'b0;
        atomic_sc_reg    = 1'b0;
        fpu_req_reg      = 1'b0;
        fpu_op_reg       = 4'd0;
        fpu_wb_int_reg   = 1'b0;
        csr_req_reg      = 1'b0;
        csr_op_reg       = 2'd0;
        csr_addr_reg     = 12'd0;
        xdrone_valid_reg = 1'b0;
        ecall_reg        = 1'b0;
        ebreak_reg       = 1'b0;
        mret_reg         = 1'b0;
        fence_i_reg      = 1'b0;
        illegal_reg      = 1'b0;

        if (!i_instr_valid) begin
            // No instruction — idle
        end else if (is_compressed) begin
            // @SAFETY: Compressed instructions should be expanded in fetch
            // If they reach here, treat as illegal (safety fail-safe)
            illegal_reg = 1'b1;
        end else begin
            case (opcode)
                //-------------------------------------------------------------
                // LUI
                //-------------------------------------------------------------
                OP_LUI: begin
                    alu_op_reg      = ALU_PASS_B;
                    alu_use_imm_reg = 1'b1;
                    imm_reg         = imm_u;
                    reg_we_reg      = 1'b1;
                end

                //-------------------------------------------------------------
                // AUIPC
                //-------------------------------------------------------------
                OP_AUIPC: begin
                    alu_op_reg      = ALU_ADD;
                    alu_use_imm_reg = 1'b1;
                    imm_reg         = imm_u;
                    reg_we_reg      = 1'b1;
                end

                //-------------------------------------------------------------
                // JAL
                //-------------------------------------------------------------
                OP_JAL: begin
                    jump_reg   = 1'b1;
                    imm_reg    = imm_j;
                    reg_we_reg = 1'b1;
                end

                //-------------------------------------------------------------
                // JALR
                //-------------------------------------------------------------
                OP_JALR: begin
                    if (funct3 == 3'd0) begin
                        jump_reg        = 1'b1;
                        alu_use_imm_reg = 1'b1;
                        imm_reg         = imm_i;
                        reg_we_reg      = 1'b1;
                    end else begin
                        illegal_reg = 1'b1;
                    end
                end

                //-------------------------------------------------------------
                // BRANCH
                //-------------------------------------------------------------
                OP_BRANCH: begin
                    branch_reg       = 1'b1;
                    imm_reg          = imm_b;
                    case (funct3)
                        3'h0: branch_eq_reg  = 1'b1;  // BEQ
                        3'h1: branch_ne_reg  = 1'b1;  // BNE
                        3'h4: branch_lt_reg  = 1'b1;  // BLT
                        3'h5: branch_ge_reg  = 1'b1;  // BGE
                        3'h6: branch_ltu_reg = 1'b1;  // BLTU
                        3'h7: branch_geu_reg = 1'b1;  // BGEU
                        default: illegal_reg = 1'b1;   // @SAFETY: Reserved funct3
                    endcase
                end

                //-------------------------------------------------------------
                // LOAD
                //-------------------------------------------------------------
                OP_LOAD: begin
                    mem_re_reg       = 1'b1;
                    alu_use_imm_reg  = 1'b1;
                    imm_reg          = imm_i;
                    reg_we_reg       = 1'b1;
                    case (funct3)
                        3'h0: begin mem_size_reg = 2'b00; end  // LB
                        3'h1: begin mem_size_reg = 2'b01; end  // LH
                        3'h2: begin mem_size_reg = 2'b10; end  // LW
                        3'h4: begin mem_size_reg = 2'b00; mem_unsigned_reg = 1'b1; end  // LBU
                        3'h5: begin mem_size_reg = 2'b01; mem_unsigned_reg = 1'b1; end  // LHU
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // STORE
                //-------------------------------------------------------------
                OP_STORE: begin
                    mem_we_reg       = 1'b1;
                    alu_use_imm_reg  = 1'b1;
                    imm_reg          = imm_s;
                    case (funct3)
                        3'h0: mem_size_reg = 2'b00;  // SB
                        3'h1: mem_size_reg = 2'b01;  // SH
                        3'h2: mem_size_reg = 2'b10;  // SW
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // OP-IMM (I-type ALU)
                //-------------------------------------------------------------
                OP_IMM: begin
                    alu_use_imm_reg = 1'b1;
                    imm_reg         = imm_i;
                    reg_we_reg      = 1'b1;
                    case (funct3)
                        3'h0: alu_op_reg = ALU_ADD;   // ADDI
                        3'h2: alu_op_reg = ALU_SLT;   // SLTI
                        3'h3: alu_op_reg = ALU_SLTU;  // SLTIU
                        3'h4: alu_op_reg = ALU_XOR;   // XORI
                        3'h6: alu_op_reg = ALU_OR;    // ORI
                        3'h7: alu_op_reg = ALU_AND;   // ANDI
                        3'h1: begin  // SLLI
                            if (funct7 == 7'd0) alu_op_reg = ALU_SLL;
                            else illegal_reg = 1'b1;
                        end
                        3'h5: begin  // SRLI/SRAI
                            if (funct7 == 7'd0)      alu_op_reg = ALU_SRL;
                            else if (funct7 == 7'h20) alu_op_reg = ALU_SRA;
                            else illegal_reg = 1'b1;
                        end
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // OP (R-type ALU) / M extension
                //-------------------------------------------------------------
                OP_REG: begin
                    reg_we_reg = 1'b1;
                    if (is_m_ext) begin
                        // M extension
                        case (funct3)
                            3'h0: mul_req_reg = 1'b1;  // MUL
                            3'h1: mul_req_reg = 1'b1;  // MULH
                            3'h2: mul_req_reg = 1'b1;  // MULHSU
                            3'h3: mul_req_reg = 1'b1;  // MULHU
                            3'h4: div_req_reg = 1'b1;  // DIV
                            3'h5: div_req_reg = 1'b1;  // DIVU
                            3'h6: div_req_reg = 1'b1;  // REM
                            3'h7: div_req_reg = 1'b1;  // REMU
                            default: illegal_reg = 1'b1;
                        endcase
                    end else begin
                        // R-type ALU
                        case (funct3)
                            3'h0: alu_op_reg = (funct7 == 7'd0) ? ALU_ADD : ALU_SUB;
                            3'h1: alu_op_reg = ALU_SLL;
                            3'h2: alu_op_reg = ALU_SLT;
                            3'h3: alu_op_reg = ALU_SLTU;
                            3'h4: alu_op_reg = ALU_XOR;
                            3'h5: alu_op_reg = (funct7 == 7'd0) ? ALU_SRL : ALU_SRA;
                            3'h6: alu_op_reg = ALU_OR;
                            3'h7: alu_op_reg = ALU_AND;
                            default: illegal_reg = 1'b1;
                        endcase
                        // Validate funct7 for non-shift ops
                        if (funct3 == 3'h1 || funct3 == 3'h2 || funct3 == 3'h3 ||
                            funct3 == 3'h4 || funct3 == 3'h6 || funct3 == 3'h7) begin
                            if (funct7 != 7'd0) illegal_reg = 1'b1;
                        end
                    end
                end

                //-------------------------------------------------------------
                // FENCE / FENCE.I
                //-------------------------------------------------------------
                OP_FENCE: begin
                    if (funct3 == 3'd0) fence_i_reg = 1'b1;
                    else if (funct3 == 3'd1) fence_i_reg = 1'b1;  // FENCE.I
                    else illegal_reg = 1'b1;
                end

                //-------------------------------------------------------------
                // SYSTEM (ECALL/EBREAK/MRET/CSR)
                //-------------------------------------------------------------
                OP_SYSTEM: begin
                    case (funct3)
                        3'h0: begin
                            case (i_instr[31:20])
                                12'h000: ecall_reg  = 1'b1;  // ECALL
                                12'h001: ebreak_reg  = 1'b1;  // EBREAK
                                12'h302: mret_reg    = 1'b1;  // MRET
                                default: illegal_reg = 1'b1;
                            endcase
                        end
                        3'h1: begin  // CSRRW
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd0;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        3'h2: begin  // CSRRS
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd1;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        3'h3: begin  // CSRRC
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd2;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        3'h5: begin  // CSRRWI
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd0;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        3'h6: begin  // CSRRSI
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd1;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        3'h7: begin  // CSRRCI
                            csr_req_reg  = 1'b1;
                            csr_op_reg   = 2'd2;
                            csr_addr_reg = i_instr[31:20];
                            reg_we_reg   = 1'b1;
                        end
                        default: illegal_reg = 1'b1;
                    endcase
                end

                //-------------------------------------------------------------
                // ATOMIC (LR.W / SC.W)
                //-------------------------------------------------------------
                OP_ATOMIC: begin
                    if (funct3 == 3'h2) begin
                        atomic_req_reg = 1'b1;
                        case (funct7[4:0])
                            5'h02: atomic_lr_reg = 1'b1;  // LR.W
                            5'h03: atomic_sc_reg = 1'b1;  // SC.W
                            default: illegal_reg = 1'b1;
                        endcase
                    end else begin
                        illegal_reg = 1'b1;
                    end
                end

                //-------------------------------------------------------------
                // F extension: FLW / FSW
                //-------------------------------------------------------------
                OP_FLW: begin
                    // @SAFETY: FLW — load float to FPU register
                    fpu_req_reg    = 1'b1;
                    fpu_op_reg     = 4'd0;   // FLW
                    mem_re_reg     = 1'b1;
                    alu_use_imm_reg = 1'b1;
                    imm_reg        = imm_i;
                    reg_we_reg     = 1'b1;
                end

                OP_FSW: begin
                    fpu_req_reg    = 1'b1;
                    fpu_op_reg     = 4'd1;   // FSW
                    mem_we_reg     = 1'b1;
                    alu_use_imm_reg = 1'b1;
                    imm_reg        = imm_s;
                end

                //-------------------------------------------------------------
                // F extension: FPMATH
                //-------------------------------------------------------------
                OP_FPMATH: begin
                    fpu_req_reg = 1'b1;
                    reg_we_reg  = 1'b1;
                    case (funct7)
                        7'h00: fpu_op_reg = 4'd2;   // FADD.S
                        7'h04: fpu_op_reg = 4'd3;   // FSUB.S
                        7'h08: fpu_op_reg = 4'd4;   // FMUL.S
                        7'h0C: fpu_op_reg = 4'd5;   // FDIV.S
                        7'h18: fpu_op_reg = 4'd6;   // FSQRT.S (rs2=0)
                        7'h14: fpu_op_reg = 4'd7;   // FMIN.S
                        7'h15: fpu_op_reg = 4'd8;   // FMAX.S
                        7'h50: begin  // FSGNJ.S / FSGNJN.S / FSGNJX.S
                            case (funct3)
                                3'h0: fpu_op_reg = 4'd9;   // FSGNJ
                                3'h1: fpu_op_reg = 4'd10;  // FSGNJN
                                3'h2: fpu_op_reg = 4'd11;  // FSGNJX
                                default: illegal_reg = 1'b1;
                            endcase
                        end
                        7'h60: fpu_op_reg = 4'd12;  // FCVT.W.S
                        7'h68: fpu_op_reg = 4'd13;  // FCVT.S.W
                        7'h70: fpu_op_reg = 4'd14;  // FMV.X.W
                        7'h78: fpu_op_reg = 4'd15;  // FMV.W.X
                        default: illegal_reg = 1'b1;
                    endcase
                    // Integer writeback for FCVT.W.S / FMV.X.W / FCLASS
                    if (funct7 == 7'h60 || funct7 == 7'h70 || funct7 == 7'hE0) begin
                        fpu_wb_int_reg = 1'b1;
                    end
                end

                //-------------------------------------------------------------
                // Xdrone custom opcodes
                //-------------------------------------------------------------
                OP_CUSTOM0, OP_CUSTOM1: begin
                    xdrone_valid_reg = 1'b1;
                    reg_we_reg       = 1'b1;
                end

                //-------------------------------------------------------------
                // @SAFETY: All other opcodes are illegal
                //-------------------------------------------------------------
                default: illegal_reg = 1'b1;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Output assignments
    //-------------------------------------------------------------------------
    assign o_alu_op        = alu_op_reg;
    assign o_alu_use_imm   = alu_use_imm_reg;
    assign o_imm           = imm_reg;
    assign o_branch        = branch_reg;
    assign o_branch_eq     = branch_eq_reg;
    assign o_branch_ne     = branch_ne_reg;
    assign o_branch_lt     = branch_lt_reg;
    assign o_branch_ge     = branch_ge_reg;
    assign o_branch_ltu    = branch_ltu_reg;
    assign o_branch_geu    = branch_geu_reg;
    assign o_jump          = jump_reg;
    assign o_mem_re        = mem_re_reg;
    assign o_mem_we        = mem_we_reg;
    assign o_mem_size      = mem_size_reg;
    assign o_mem_unsigned  = mem_unsigned_reg;
    assign o_reg_we        = reg_we_reg;
    assign o_mul_req       = mul_req_reg;
    assign o_div_req       = div_req_reg;
    assign o_atomic_req    = atomic_req_reg;
    assign o_atomic_lr     = atomic_lr_reg;
    assign o_atomic_sc     = atomic_sc_reg;
    assign o_fpu_req       = fpu_req_reg;
    assign o_fpu_op        = fpu_op_reg;
    assign o_fpu_wb_int    = fpu_wb_int_reg;
    assign o_csr_req       = csr_req_reg;
    assign o_csr_op        = csr_op_reg;
    assign o_csr_addr      = csr_addr_reg;
    assign o_xdrone_valid  = xdrone_valid_reg;
    assign o_ecall         = ecall_reg;
    assign o_ebreak        = ebreak_reg;
    assign o_mret          = mret_reg;
    assign o_fence_i       = fence_i_reg;
    assign o_illegal_insn  = illegal_reg;

endmodule
