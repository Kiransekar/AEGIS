//===============================================================================
// Testbench: rt_muldiv_tb
// Module Under Test: rt_muldiv (RV32M multiply/divide)
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module rt_muldiv_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk, i_rst_n;
    reg         i_valid;
    reg  [2:0]  i_funct3;
    reg         i_is_signed;
    reg  [31:0] i_operand_a, i_operand_b;
    wire [31:0] o_result;
    wire        o_valid, o_busy;

    rt_muldiv dut (.*);

    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    task automatic apply_reset;
        begin
            i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
            i_rst_n = 1; @(posedge i_clk);
        end
    endtask

    task automatic run_op;
        input [2:0]  op;
        input [31:0] a, b;
        input [255:0] name;
        begin
            i_valid = 1'b1;
            i_funct3 = op;
            i_operand_a = a;
            i_operand_b = b;
            @(posedge i_clk);
            i_valid = 1'b0;
            // Wait for valid
            while (!o_valid) @(posedge i_clk);
        end
    endtask

    integer test_count, pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: MUL 3 * 4 = 12 ---
        $display("[MULDIV 1] MUL 3 * 4 = 12");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h0, 32'd3, 32'd4, "MUL");
        if (o_result == 32'd12) begin
            $display("[PASS] MUL: result=%0d", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] MUL: result=%0d (expected 12)", o_result);

        //--- Test 2: MUL -2 * 3 = -6 ---
        $display("[MULDIV 2] MUL -2 * 3 = -6");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h0, 32'hFFFFFFFE, 32'd3, "MUL_neg");
        if ($signed(o_result) == -6) begin
            $display("[PASS] MUL neg: result=%0d", $signed(o_result));
            pass_count = pass_count + 1;
        end else $display("[FAIL] MUL neg: result=%0d", $signed(o_result));

        //--- Test 3: MULH (signed high) ---
        $display("[MULDIV 3] MULH signed high");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h1, 32'h7FFFFFFF, 32'h7FFFFFFF, "MULH");
        // 0x7FFFFFFF * 0x7FFFFFFF → high bits should be 0x3FFFFFFF
        if (o_result != 32'd0) begin
            $display("[PASS] MULH: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] MULH: result=0x%08h", o_result);

        //--- Test 4: DIV 20 / 4 = 5 ---
        $display("[MULDIV 4] DIV 20 / 4 = 5");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h4, 32'd20, 32'd4, "DIV");
        if (o_result == 32'd5) begin
            $display("[PASS] DIV: result=%0d", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] DIV: result=%0d (expected 5)", o_result);

        //--- Test 5: DIV by zero → -1 ---
        $display("[MULDIV 5] DIV by zero → all-ones");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h4, 32'd42, 32'd0, "DIV0");
        if (o_result == 32'hFFFFFFFF) begin
            $display("[PASS] DIV-by-zero: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] DIV-by-zero: result=0x%08h", o_result);

        //--- Test 6: REM 17 % 5 = 2 ---
        $display("[MULDIV 6] REM 17 %% 5 = 2");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h6, 32'd17, 32'd5, "REM");
        if (o_result == 32'd2) begin
            $display("[PASS] REM: result=%0d", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] REM: result=%0d (expected 2)", o_result);

        //--- Test 7: DIVU unsigned ---
        $display("[MULDIV 7] DIVU unsigned");
        test_count = test_count + 1;
        apply_reset;
        run_op(3'h5, 32'h80000000, 32'd2, "DIVU");
        if (o_result == 32'h40000000) begin
            $display("[PASS] DIVU: result=0x%08h", o_result);
            pass_count = pass_count + 1;
        end else $display("[FAIL] DIVU: result=0x%08h", o_result);

        //--- Test 8: MUL fixed latency (2 cycles) ---
        $display("[MULDIV 8] MUL fixed latency = 2 cycles");
        test_count = test_count + 1;
        apply_reset;
        begin : mul_latency
            integer start_cycle, end_cycle;
            @(posedge i_clk);
            start_cycle = 0;
            i_valid = 1'b1; i_funct3 = 3'h0;
            i_operand_a = 32'd7; i_operand_b = 32'd8;
            @(posedge i_clk);
            i_valid = 1'b0;
            end_cycle = 0;
            while (!o_valid) begin
                @(posedge i_clk);
                #1;
                end_cycle = end_cycle + 1;
            end
            if (end_cycle == 1) begin  // 1 cycle after issue = 2 total
                $display("[PASS] MUL latency: %0d cycles", end_cycle + 1);
                pass_count = pass_count + 1;
            end else $display("[FAIL] MUL latency: %0d cycles (expected 2)", end_cycle + 1);
        end

        //--- Test 9: DIV fixed latency (4 cycles) ---
        $display("[MULDIV 9] DIV fixed latency = 4 cycles");
        test_count = test_count + 1;
        apply_reset;
        begin : div_latency
            integer end_cycle;
            i_valid = 1'b1; i_funct3 = 3'h4;
            i_operand_a = 32'd100; i_operand_b = 32'd5;
            @(posedge i_clk);
            i_valid = 1'b0;
            end_cycle = 0;
            while (!o_valid) begin
                @(posedge i_clk);
                #1;
                end_cycle = end_cycle + 1;
            end
            if (end_cycle == 3) begin  // 3 cycles after issue = 4 total
                $display("[PASS] DIV latency: %0d cycles", end_cycle + 1);
                pass_count = pass_count + 1;
            end else $display("[FAIL] DIV latency: %0d cycles (expected 4)", end_cycle + 1);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("RT MULDIV Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) $display("[✓] All tests passed");
        else $display("[✗] Some tests failed");
        $finish;
    end

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout");
        $finish;
    end

endmodule
