//===============================================================================
// Testbench: xdrone_qmul_tb
// Module Under Test: xdrone_qmul (quaternion multiply)
//===============================================================================

`timescale 1ns/1ps

module xdrone_qmul_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk, i_rst_n;
    reg         i_valid;
    reg  [31:0] i_operand_a, i_operand_b, i_operand_c, i_operand_d;
    wire [31:0] o_result_wx, o_result_yz;
    wire        o_valid, o_busy;

    xdrone_qmul dut (.*);

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

    integer test_count, pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Identity multiply q * [1,0,0,0] = q ---
        $display("[QMUL 1] Identity multiply");
        test_count = test_count + 1;
        apply_reset;
        i_valid = 1'b1;
        // q0 = [w=1.0, x=0.0] = {16'h0100, 16'h0000}
        // q1 = [w=1.0, x=0.0] = {16'h0100, 16'h0000}
        i_operand_a = {16'h0100, 16'h0000};  // w0=1.0, x0=0
        i_operand_b = {16'h0100, 16'h0000};  // w1=1.0, x1=0
        i_operand_c = {16'h0000, 16'h0000};  // y0=0, z0=0
        i_operand_d = {16'h0000, 16'h0000};  // y1=0, z1=0
        @(posedge i_clk);
        i_valid = 1'b0;
        while (!o_valid) @(posedge i_clk);
        // w = 1*1 - 0 - 0 - 0 = 1.0 → 0x0100
        if (o_result_wx[31:16] == 16'h0100) begin
            $display("[PASS] Identity qmul: w=0x%04h", o_result_wx[31:16]);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Identity qmul: w=0x%04h (expected 0x0100)", o_result_wx[31:16]);

        //--- Test 2: 2-cycle latency ---
        $display("[QMUL 2] Fixed 2-cycle latency");
        test_count = test_count + 1;
        apply_reset;
        begin : qmul_latency
            integer end_cycle;
            i_valid = 1'b1;
            i_operand_a = {16'h0100, 16'h0000};
            i_operand_b = {16'h0100, 16'h0000};
            i_operand_c = {16'h0000, 16'h0000};
            i_operand_d = {16'h0000, 16'h0000};
            @(posedge i_clk);
            i_valid = 1'b0;
            end_cycle = 0;
            while (!o_valid) begin
                @(posedge i_clk);
                end_cycle = end_cycle + 1;
            end
            if (end_cycle == 1) begin  // 1 cycle after issue = 2 total
                $display("[PASS] QMUL latency: %0d cycles", end_cycle + 1);
                pass_count = pass_count + 1;
            end else $display("[FAIL] QMUL latency: %0d cycles (expected 2)", end_cycle + 1);
        end

        //--- Test 3: Busy flag during execution ---
        $display("[QMUL 3] Busy flag during execution");
        test_count = test_count + 1;
        apply_reset;
        i_valid = 1'b1;
        i_operand_a = {16'h0100, 16'h0080};
        i_operand_b = {16'h0100, 16'h0040};
        i_operand_c = {16'h0020, 16'h0010};
        i_operand_d = {16'h0080, 16'h0040};
        @(posedge i_clk);
        if (o_busy) begin
            $display("[PASS] Busy flag asserted during execution");
            pass_count = pass_count + 1;
        end else $display("[FAIL] Busy flag not asserted");
        i_valid = 1'b0;
        while (!o_valid) @(posedge i_clk);

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Xdrone QMUL Test Summary: %0d/%0d passed", pass_count, test_count);
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
