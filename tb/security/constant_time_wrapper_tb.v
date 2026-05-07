//===============================================================================
// Testbench: constant_time_wrapper_tb
// Module Under Test: constant_time_wrapper
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module constant_time_wrapper_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk;
    reg         i_rst_n;
    reg         i_start;
    reg  [31:0] i_operand_a;
    reg  [31:0] i_operand_b;
    wire [31:0] o_result;
    wire        o_done;
    wire        o_busy;

    constant_time_wrapper dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .i_operand_a(i_operand_a),
        .i_operand_b(i_operand_b),
        .o_result(o_result),
        .o_done(o_done),
        .o_busy(o_busy)
    );

    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    task automatic apply_reset;
        input [31:0] cycles;
        begin
            i_rst_n = 0;
            repeat(cycles) @(posedge i_clk);
            i_rst_n = 1;
            @(posedge i_clk);
        end
    endtask

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;
        i_start = 1'b0;
        i_operand_a = 32'd0;
        i_operand_b = 32'd0;

        //--- Test 1: Fixed 64-Cycle Execution ---
        $display("[TEST 1] Fixed 64-Cycle Execution");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        begin : latency_test
            integer cycle_count;
            i_operand_a = 32'h0000_0005;
            i_operand_b = 32'h0000_0003;
            i_start = 1'b1;
            @(posedge i_clk);
            i_start = 1'b0;
            cycle_count = 0;
            while (!o_done && cycle_count < 100) begin
                @(posedge i_clk);
                cycle_count = cycle_count + 1;
            end
            if (o_done && cycle_count == 64) begin
                $display("[PASS] Execution completed in exactly %0d cycles", cycle_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Execution latency = %0d cycles (expected 64), done=%0b",
                         cycle_count, o_done);
            end
        end

        //--- Test 2: Busy Flag During Execution ---
        $display("[TEST 2] Busy Flag During Execution");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_operand_a = 32'hAAAA_5555;
        i_operand_b = 32'h5555_AAAA;
        i_start = 1'b1;
        @(posedge i_clk);
        i_start = 1'b0;
        @(posedge i_clk);
        if (o_busy == 1'b1) begin
            $display("[PASS] Busy flag asserted during execution");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Busy flag not asserted: busy=%0b", o_busy);
        end
        // Wait for completion
        while (!o_done) @(posedge i_clk);

        //--- Test 3: Constant Timing Regardless of Operands ---
        $display("[TEST 3] Constant Timing (all-zero operands)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        begin : zero_latency
            integer cycle_count;
            i_operand_a = 32'd0;
            i_operand_b = 32'd0;
            i_start = 1'b1;
            @(posedge i_clk);
            i_start = 1'b0;
            cycle_count = 0;
            while (!o_done && cycle_count < 100) begin
                @(posedge i_clk);
                cycle_count = cycle_count + 1;
            end
            if (o_done && cycle_count == 64) begin
                $display("[PASS] Zero-operand latency = %0d cycles (constant)", cycle_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Zero-operand latency = %0d cycles (expected 64)", cycle_count);
            end
        end

        //--- Test 4: Result Available After Completion ---
        $display("[TEST 4] Result Available After Completion");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_operand_a = 32'h0000_0007;
        i_operand_b = 32'h0000_0003;
        i_start = 1'b1;
        @(posedge i_clk);
        i_start = 1'b0;
        while (!o_done) @(posedge i_clk);
        // Stub result = a + b = 10
        if (o_result == 32'h0000_000A) begin
            $display("[PASS] Result correct: 0x%08h", o_result);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Result incorrect: 0x%08h (expected 0x0000000A)", o_result);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Constant-Time Wrapper Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) begin
            $display("[✓] All tests passed");
        end else begin
            $display("[✗] Some tests failed");
        end
        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/constant_time_wrapper.vcd");
        $dumpvars(0, constant_time_wrapper_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
