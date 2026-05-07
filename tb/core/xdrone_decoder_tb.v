//===============================================================================
// Testbench: xdrone_decoder_tb
// Module Under Test: xdrone_decoder
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module xdrone_decoder_tb;
    parameter CLK_PERIOD_NS = 4.167;

    // Signals
    reg  [31:0] i_instr;
    reg         i_valid;
    wire        o_xdrone_valid;
    wire [7:0]  o_xdrone_opcode;
    wire [4:0]  o_rd_addr;
    wire [4:0]  o_rs1_addr;
    wire [4:0]  o_rs2_addr;
    wire [31:0] o_imm;
    wire [3:0]  o_precision;
    wire [3:0]  o_max_depth;

    // DUT
    xdrone_decoder dut (
        .i_instr(i_instr),
        .i_valid(i_valid),
        .o_xdrone_valid(o_xdrone_valid),
        .o_xdrone_opcode(o_xdrone_opcode),
        .o_rd_addr(o_rd_addr),
        .o_rs1_addr(o_rs1_addr),
        .o_rs2_addr(o_rs2_addr),
        .o_imm(o_imm),
        .o_precision(o_precision),
        .o_max_depth(o_max_depth)
    );

    integer test_count;
    integer pass_count;

    // Helper: Build R-type instruction with given opcode, rd, rs1, rs2, funct7
    function [31:0] build_rtype;
        input [6:0] opcode;
        input [4:0] rd;
        input [2:0] funct3;
        input [4:0] rs1;
        input [4:0] rs2;
        input [6:0] funct7;
        begin
            build_rtype = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Non-Xdrone Instruction — Not Detected ---
        $display("[TEST 1] Non-Xdrone Instruction (ADD) — Not Detected");
        test_count = test_count + 1;
        i_instr = 32'h0001_00B3;  // ADD instruction (opcode=0x33)
        i_valid = 1'b1;
        #10;
        if (o_xdrone_valid == 1'b0) begin
            $display("[PASS] Non-Xdrone instruction correctly ignored");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Non-Xdrone incorrectly flagged: xdrone_valid=%0b", o_xdrone_valid);
        end

        //--- Test 2: Custom-0 Instruction (opcode=0x0B) ---
        $display("[TEST 2] Custom-0 Instruction Detected");
        test_count = test_count + 1;
        i_instr = build_rtype(7'h0B, 5'd5, 3'd0, 5'd10, 5'd15, 7'h01);
        i_valid = 1'b1;
        #10;
        if (o_xdrone_valid == 1'b1 && o_rd_addr == 5'd5 && o_rs1_addr == 5'd10 && o_rs2_addr == 5'd15) begin
            $display("[PASS] Custom-0 decoded: valid=%0b, rd=%0d, rs1=%0d, rs2=%0d",
                     o_xdrone_valid, o_rd_addr, o_rs1_addr, o_rs2_addr);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Custom-0 decode: valid=%0b, rd=%0d, rs1=%0d, rs2=%0d",
                     o_xdrone_valid, o_rd_addr, o_rs1_addr, o_rs2_addr);
        end

        //--- Test 3: Custom-1 Instruction (opcode=0x2B) ---
        $display("[TEST 3] Custom-1 Instruction Detected");
        test_count = test_count + 1;
        i_instr = build_rtype(7'h2B, 5'd7, 3'd0, 5'd12, 5'd17, 7'h02);
        i_valid = 1'b1;
        #10;
        if (o_xdrone_valid == 1'b1 && o_xdrone_opcode[7] == 1'b1) begin
            $display("[PASS] Custom-1 decoded with correct opcode MSB");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Custom-1 decode: valid=%0b, opcode=0x%02h", o_xdrone_valid, o_xdrone_opcode);
        end

        //--- Test 4: Instruction Invalid — Not Detected ---
        $display("[TEST 4] Instruction Invalid — Not Detected");
        test_count = test_count + 1;
        i_instr = build_rtype(7'h0B, 5'd5, 3'd0, 5'd10, 5'd15, 7'h01);
        i_valid = 1'b0;
        #10;
        if (o_xdrone_valid == 1'b0) begin
            $display("[PASS] Invalid instruction correctly ignored");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Invalid instruction flagged: xdrone_valid=%0b", o_xdrone_valid);
        end

        //--- Test 5: Field Extraction Accuracy ---
        $display("[TEST 5] Field Extraction Accuracy");
        test_count = test_count + 1;
        i_instr = {7'h05, 5'd20, 5'd3, 3'd2, 5'd8, 7'h0B};  // custom-0 with specific fields
        i_valid = 1'b1;
        #10;
        if (o_rd_addr == 5'd8 && o_rs1_addr == 5'd3 && o_rs2_addr == 5'd20) begin
            $display("[PASS] Field extraction correct: rd=%0d, rs1=%0d, rs2=%0d",
                     o_rd_addr, o_rs1_addr, o_rs2_addr);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Field extraction: rd=%0d, rs1=%0d, rs2=%0d",
                     o_rd_addr, o_rs1_addr, o_rs2_addr);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Xdrone Decoder Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) begin
            $display("[✓] All tests passed");
        end else begin
            $display("[✗] Some tests failed");
        end
        $finish;
    end

endmodule
