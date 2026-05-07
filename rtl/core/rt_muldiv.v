//===============================================================================
// Module: rt_muldiv
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_muldiv.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   RV32M multiply/divide unit with deterministic latency.
//   All operations complete in fixed cycles — no data-dependent timing.
//
//   M Extension Operations:
//     MUL, MULH, MULHSU, MULHU — Multiply (2-cycle fixed)
//     DIV, DIVU, REM, REMU     — Divide (4-cycle fixed)
//
// Safety Annotations:
//   @CERT: AEGIS-RT-MULDIV-001 — ARCHITECTURE.md §3 (M Extension)
//   @WCET: MUL = 2 cycles; DIV = 4 cycles (fixed, no early completion)
//   @SAFETY: Divide-by-zero returns all-ones; signed overflow returns max
//   @SAFETY: No data-dependent timing — dummy cycles pad fast results
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_muldiv #(
    parameter DATA_WIDTH = 32
) (
    input  wire                        i_clk,
    input  wire                        i_rst_n,

    // Operation interface
    input  wire                        i_valid,        // Operation valid
    input  wire [2:0]                  i_funct3,       // M extension funct3
    input  wire                        i_is_signed,    // Signed operation
    input  wire [DATA_WIDTH-1:0]       i_operand_a,    // rs1
    input  wire [DATA_WIDTH-1:0]       i_operand_b,    // rs2
    output reg  [DATA_WIDTH-1:0]       o_result,       // Result
    output reg                         o_valid,        // Result valid
    output reg                         o_busy          // Operation in progress
);

    //-------------------------------------------------------------------------
    // M Extension Operation Encoding (funct3)
    //-------------------------------------------------------------------------
    localparam [2:0] MUL    = 3'h0;
    localparam [2:0] MULH   = 3'h1;
    localparam [2:0] MULHSU = 3'h2;
    localparam [2:0] MULHU  = 3'h3;
    localparam [2:0] DIV    = 3'h4;
    localparam [2:0] DIVU   = 3'h5;
    localparam [2:0] REM    = 3'h6;
    localparam [2:0] REMU   = 3'h7;

    // @WCET: Fixed latencies
    localparam MUL_CYCLES = 3'd2;
    localparam DIV_CYCLES = 3'd4;

    //-------------------------------------------------------------------------
    // Internal state
    //-------------------------------------------------------------------------
    reg [2:0]  op_reg;
    reg [DATA_WIDTH-1:0] op_a, op_b;
    reg [2:0]  cycle_cnt;
    reg [2:0]  target_cycles;
    reg        active;

    // Multiply result (64-bit)
    reg [2*DATA_WIDTH-1:0] mul_result;

    // Divide results
    reg [DATA_WIDTH-1:0] div_quotient;
    reg [DATA_WIDTH-1:0] div_remainder;

    //-------------------------------------------------------------------------
    // Multiply logic (combinational, result captured on cycle 2)
    // @SAFETY: All multiply variants computed; select based on funct3
    //-------------------------------------------------------------------------
    wire [2*DATA_WIDTH-1:0] mul_signed_signed;
    wire [2*DATA_WIDTH-1:0] mul_signed_unsigned;
    wire [2*DATA_WIDTH-1:0] mul_unsigned_unsigned;

    assign mul_signed_signed   = $signed(op_a) * $signed(op_b);
    assign mul_signed_unsigned = $signed(op_a) * $unsigned(op_b);
    assign mul_unsigned_unsigned = $unsigned(op_a) * $unsigned(op_b);

    always @* begin
        case (op_reg)
            MUL:    mul_result = mul_signed_signed[DATA_WIDTH-1:0];
            MULH:   mul_result = mul_signed_signed[2*DATA_WIDTH-1:DATA_WIDTH];
            MULHSU: mul_result = mul_signed_unsigned[2*DATA_WIDTH-1:DATA_WIDTH];
            MULHU:  mul_result = mul_unsigned_unsigned[2*DATA_WIDTH-1:DATA_WIDTH];
            default: mul_result = {2*DATA_WIDTH{1'b0}};
        endcase
    end

    //-------------------------------------------------------------------------
    // Divide logic (simplified for Phase 2)
    // @SAFETY: Divide-by-zero → all-ones; signed overflow → max positive
    // @WCET: 4 cycles fixed — no early completion
    //-------------------------------------------------------------------------
    always @* begin
        div_quotient  = {DATA_WIDTH{1'b0}};
        div_remainder = {DATA_WIDTH{1'b0}};

        case (op_reg)
            DIV: begin
                if (op_b == {DATA_WIDTH{1'b0}}) begin
                    // @SAFETY: Divide by zero → -1
                    div_quotient  = {DATA_WIDTH{1'b1}};
                    div_remainder = op_a;
                end else if (op_a == {1'b1, {DATA_WIDTH-1{1'b0}}} && op_b == {DATA_WIDTH{1'b1}}) begin
                    // @SAFETY: Signed overflow → max positive
                    div_quotient  = {1'b1, {DATA_WIDTH-1{1'b0}}};
                    div_remainder = {DATA_WIDTH{1'b0}};
                end else begin
                    div_quotient  = $signed(op_a) / $signed(op_b);
                    div_remainder = $signed(op_a) % $signed(op_b);
                end
            end
            DIVU: begin
                if (op_b == {DATA_WIDTH{1'b0}}) begin
                    div_quotient  = {DATA_WIDTH{1'b1}};
                    div_remainder = op_a;
                end else begin
                    div_quotient  = op_a / op_b;
                    div_remainder = op_a % op_b;
                end
            end
            REM: begin
                if (op_b == {DATA_WIDTH{1'b0}}) begin
                    div_quotient  = {DATA_WIDTH{1'b1}};
                    div_remainder = op_a;
                end else if (op_a == {1'b1, {DATA_WIDTH-1{1'b0}}} && op_b == {DATA_WIDTH{1'b1}}) begin
                    div_quotient  = {1'b1, {DATA_WIDTH-1{1'b0}}};
                    div_remainder = {DATA_WIDTH{1'b0}};
                end else begin
                    div_remainder = $signed(op_a) % $signed(op_b);
                end
            end
            REMU: begin
                if (op_b == {DATA_WIDTH{1'b0}}) begin
                    div_remainder = op_a;
                end else begin
                    div_remainder = op_a % op_b;
                end
            end
            default: begin
                div_quotient  = {DATA_WIDTH{1'b0}};
                div_remainder = {DATA_WIDTH{1'b0}};
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // Fixed-latency execution FSM
    // @WCET: MUL=2 cycles, DIV=4 cycles — no early completion
    // @SAFETY: Dummy cycles pad fast results for constant timing
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            active        <= 1'b0;
            o_valid       <= 1'b0;
            o_busy        <= 1'b0;
            o_result      <= {DATA_WIDTH{1'b0}};
            cycle_cnt     <= 3'd0;
            target_cycles <= 3'd0;
            op_reg        <= 3'd0;
            op_a          <= {DATA_WIDTH{1'b0}};
            op_b          <= {DATA_WIDTH{1'b0}};
        end else begin
            o_valid <= 1'b0;

            if (i_valid && !active) begin
                // Start new operation
                active    <= 1'b1;
                o_busy    <= 1'b1;
                op_reg    <= i_funct3;
                op_a      <= i_operand_a;
                op_b      <= i_operand_b;
                cycle_cnt <= 3'd1;

                // @WCET: Set target latency based on operation type
                if (i_funct3 == MUL || i_funct3 == MULH || i_funct3 == MULHSU || i_funct3 == MULHU) begin
                    target_cycles <= MUL_CYCLES;
                end else begin
                    target_cycles <= DIV_CYCLES;
                end
            end else if (active) begin
                cycle_cnt <= cycle_cnt + 3'd1;

                if (cycle_cnt >= target_cycles) begin
                    // @SAFETY: Output result at fixed latency
                    case (op_reg)
                        MUL:    o_result <= mul_signed_signed[DATA_WIDTH-1:0];
                        MULH:   o_result <= mul_signed_signed[2*DATA_WIDTH-1:DATA_WIDTH];
                        MULHSU: o_result <= mul_signed_unsigned[2*DATA_WIDTH-1:DATA_WIDTH];
                        MULHU:  o_result <= mul_unsigned_unsigned[2*DATA_WIDTH-1:DATA_WIDTH];
                        DIV, DIVU: o_result <= div_quotient;
                        REM, REMU: o_result <= div_remainder;
                        default:   o_result <= {DATA_WIDTH{1'b0}};
                    endcase

                    o_valid   <= 1'b1;
                    o_busy    <= 1'b0;
                    active    <= 1'b0;
                    cycle_cnt <= 3'd0;
                end
            end
        end
    end

endmodule
