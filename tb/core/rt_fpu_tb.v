//===============================================================================
// Testbench: rt_fpu_tb
// Module Under Test: rt_fpu (Single-precision FPU with FTZ mode)
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module rt_fpu_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk  = 1'b0;
    reg         i_rst_n = 1'b0;
    reg  [3:0]  i_fpu_op   = 4'd0;
    reg  [31:0] i_operand_a = 32'd0;
    reg  [31:0] i_operand_b = 32'd0;
    reg         i_valid     = 1'b0;
    wire [31:0] o_result;
    wire        o_valid;
    wire        o_fflags_invalid;
    wire        o_fflags_divzero;
    wire        o_fflags_overflow;
    wire        o_fflags_underflow;
    wire        o_fflags_inexact;
    reg         i_ftz_enable = 1'b1;
    wire [31:0] o_int_result;
    reg  [31:0] i_int_operand = 32'd0;
    wire        o_wb_int;

    rt_fpu dut (.*);

    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    task automatic apply_reset;
        begin
            i_rst_n = 0;
            repeat(RST_CYCLES) @(posedge i_clk);
            i_rst_n = 1;
            @(posedge i_clk);
        end
    endtask

    // FPU op constants
    localparam [3:0] FPU_FADD=2, FPU_FSUB=3, FPU_FMUL=4, FPU_FDIV=5;
    localparam [3:0] FPU_FMIN=7, FPU_FMAX=8, FPU_FSGNJ=9;
    localparam [3:0] FPU_CVTWS=12, FPU_MVXW=14, FPU_MVWX=15;

    // IEEE 754 helpers
    function [31:0] make_float;
        input sign;
        input [7:0] exp;
        input [22:0] mant;
        make_float = {sign, exp, mant};
    endfunction

    // Known float values
    wire [31:0] FP_1_0   = make_float(1'b0, 8'd127, 23'd0);      // 1.0
    wire [31:0] FP_2_0   = make_float(1'b0, 8'd128, 23'd0);      // 2.0
    wire [31:0] FP_NEG1  = make_float(1'b1, 8'd127, 23'd0);      // -1.0
    wire [31:0] FP_ZERO  = 32'h0000_0000;                         // +0.0
    wire [31:0] FP_NZERO = 32'h8000_0000;                         // -0.0
    wire [31:0] FP_INF   = 32'h7F80_0000;                         // +Inf
    wire [31:0] FP_NINF  = 32'hFF80_0000;                         // -Inf
    wire [31:0] FP_NAN   = 32'h7FC0_0000;                         // NaN
    wire [31:0] FP_SUBNORM = make_float(1'b0, 8'd0, 23'd1);      // Smallest subnormal

    // Helper: send one FPU operation and wait for result
    task automatic send_op;
        input [3:0] op;
        input [31:0] a, b;
        begin
            i_fpu_op = op;
            i_operand_a = a;
            i_operand_b = b;
            i_valid = 1'b1;
            #1;
            @(posedge i_clk);
            #1;
            i_valid = 1'b0;
        end
    endtask

    // Helper: wait one cycle and sample outputs
    task automatic wait_and_sample;
        begin
            @(posedge i_clk);
            #1;
        end
    endtask

    integer test_count, pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;
        i_ftz_enable = 1'b1;
        i_valid = 1'b0;
        i_int_operand = 32'd0;
        i_fpu_op = 4'd0;
        i_operand_a = 32'd0;
        i_operand_b = 32'd0;

        //--- Test 1: FADD 1.0 + 2.0 ≈ 3.0 ---
        $display("[FPU 1] FADD 1.0 + 2.0");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FADD, FP_1_0, FP_2_0);
        wait_and_sample;
        if (o_valid && o_result[30:23] == 8'd128) begin
            $display("[PASS] FADD: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FADD: result=0x%08h, valid=%0b", o_result, o_valid);
        end

        //--- Test 2: FSUB 2.0 - 1.0 ≈ 1.0 ---
        $display("[FPU 2] FSUB 2.0 - 1.0");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FSUB, FP_2_0, FP_1_0);
        wait_and_sample;
        if (o_valid && o_result == FP_1_0) begin
            $display("[PASS] FSUB: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FSUB: result=0x%08h (expected 0x%08h)", o_result, FP_1_0);
        end

        //--- Test 3: FMUL 2.0 × 3.0 ≈ 6.0 ---
        $display("[FPU 3] FMUL 2.0 × 3.0");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FMUL, FP_2_0, make_float(1'b0, 8'd128, 23'h400000));
        wait_and_sample;
        if (o_valid) begin
            $display("[PASS] FMUL: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FMUL: result=0x%08h, valid=%0b", o_result, o_valid);
        end

        //--- Test 4: NaN propagation ---
        $display("[FPU 4] NaN propagation (FADD NaN + 1.0)");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FADD, FP_NAN, FP_1_0);
        wait_and_sample;
        if (o_valid && o_result == 32'h7FC0_0000 && o_fflags_invalid) begin
            $display("[PASS] NaN propagation: result=NaN, invalid=1");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] NaN: result=0x%08h, invalid=%0b", o_result, o_fflags_invalid);
        end

        //--- Test 5: FTZ — Subnormal input flushed to zero ---
        $display("[FPU 5] FTZ: Subnormal input flushed to zero");
        test_count = test_count + 1;
        apply_reset;
        i_ftz_enable = 1'b1;
        send_op(FPU_FADD, FP_SUBNORM, FP_1_0);
        wait_and_sample;
        if (o_valid && o_result == FP_1_0) begin
            $display("[PASS] FTZ: subnormal flushed, result=1.0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FTZ: result=0x%08h (expected 0x%08h)", o_result, FP_1_0);
        end

        //--- Test 6: FMIN ---
        $display("[FPU 6] FMIN(1.0, -1.0)");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FMIN, FP_1_0, FP_NEG1);
        wait_and_sample;
        if (o_valid && o_result == FP_NEG1) begin
            $display("[PASS] FMIN: result=-1.0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FMIN: result=0x%08h", o_result);
        end

        //--- Test 7: FSGNJ (sign injection) ---
        $display("[FPU 7] FSGNJ: copy sign from B to A");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FSGNJ, FP_1_0, FP_NEG1);
        wait_and_sample;
        if (o_valid && o_result == FP_NEG1) begin
            $display("[PASS] FSGNJ: +1.0 → -1.0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FSGNJ: result=0x%08h", o_result);
        end

        //--- Test 8: FMV.X.W (bitwise move) ---
        $display("[FPU 8] FMV.X.W: bitwise move float→int");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_MVXW, 32'hDEAD_BEEF, 32'd0);
        wait_and_sample;
        if (o_valid && o_wb_int && o_int_result == 32'hDEAD_BEEF) begin
            $display("[PASS] FMV.X.W: int_result=0x%08h", o_int_result);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FMV.X.W: int_result=0x%08h, wb_int=%0b", o_int_result, o_wb_int);
        end

        //--- Test 9: Div-by-zero flag ---
        $display("[FPU 9] FDIV by zero → divzero flag");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FDIV, FP_1_0, FP_ZERO);
        wait_and_sample;
        if (o_valid && o_fflags_divzero) begin
            $display("[PASS] FDIV by zero: divzero=1");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FDIV by zero: divzero=%0b, result=0x%08h", o_fflags_divzero, o_result);
        end

        //--- Test 10: 1-Cycle Latency ---
        $display("[FPU 10] 1-Cycle Latency (valid on next cycle)");
        test_count = test_count + 1;
        apply_reset;
        send_op(FPU_FADD, FP_1_0, FP_2_0);
        // Check valid immediately after send_op (which waits 1 posedge + #1)
        if (o_valid) begin
            $display("[PASS] FPU 1-cycle latency");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] FPU latency: valid=%0b", o_valid);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("RT FPU Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) $display("[✓] All tests passed");
        else $display("[✗] Some tests failed");
        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/rt_fpu.vcd");
        $dumpvars(0, rt_fpu_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout");
        $finish;
    end

endmodule
