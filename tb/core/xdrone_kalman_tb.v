//===============================================================================
// Testbench: xdrone_kalman_tb
// Module Under Test: xdrone_kalman (Kalman filter step)
//===============================================================================

`timescale 1ns/1ps

module xdrone_kalman_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk, i_rst_n;
    reg         i_valid;
    reg  [31:0] i_state_01, i_state_23, i_state_45;
    reg  [31:0] i_accel_01, i_accel_2;
    reg  [15:0] i_dt;
    wire [31:0] o_state_01, o_state_23, o_state_45;
    wire        o_valid, o_busy;

    xdrone_kalman dut (.*);

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

        //--- Test 1: Zero state + zero accel → unchanged ---
        $display("[KALMAN 1] Zero state + zero accel");
        test_count = test_count + 1;
        apply_reset;
        i_valid = 1'b1;
        i_state_01 = {16'd0, 16'd0};  // px=0, py=0
        i_state_23 = {16'd0, 16'd0};  // pz=0, vx=0
        i_state_45 = {16'd0, 16'd0};  // vy=0, vz=0
        i_accel_01 = {16'd0, 16'd0};
        i_accel_2  = {16'd0, 16'd0};
        i_dt       = 16'h0100;        // dt=1.0 (Q8.8)
        @(posedge i_clk);
        i_valid = 1'b0;
        while (!o_valid) @(posedge i_clk);
        if (o_state_01 == 32'd0 && o_state_23 == 32'd0 && o_state_45 == 32'd0) begin
            $display("[PASS] Zero state unchanged");
            pass_count = pass_count + 1;
        end else $display("[FAIL] Zero state changed: 0x%08h 0x%08h 0x%08h",
                          o_state_01, o_state_23, o_state_45);

        //--- Test 2: 4-cycle latency ---
        $display("[KALMAN 2] Fixed 4-cycle latency");
        test_count = test_count + 1;
        apply_reset;
        begin : kalman_latency
            integer end_cycle;
            i_valid = 1'b1;
            i_state_01 = {16'h0100, 16'h0200};  // px=1.0, py=2.0
            i_state_23 = {16'h0300, 16'h0080};  // pz=3.0, vx=0.5
            i_state_45 = {16'h0040, 16'h0020};  // vy=0.25, vz=0.125
            i_accel_01 = {16'h0010, 16'h0010};
            i_accel_2  = {16'd0, 16'h0010};
            i_dt       = 16'h0100;
            @(posedge i_clk);
            i_valid = 1'b0;
            end_cycle = 0;
            while (!o_valid) begin
                @(posedge i_clk);
                end_cycle = end_cycle + 1;
            end
            if (end_cycle == 3) begin  // 3 cycles after issue = 4 total
                $display("[PASS] Kalman latency: %0d cycles", end_cycle + 1);
                pass_count = pass_count + 1;
            end else $display("[FAIL] Kalman latency: %0d cycles (expected 4)", end_cycle + 1);
        end

        //--- Test 3: Busy flag during execution ---
        $display("[KALMAN 3] Busy flag during execution");
        test_count = test_count + 1;
        apply_reset;
        i_valid = 1'b1;
        i_state_01 = {16'h0100, 16'h0200};
        i_state_23 = {16'h0300, 16'h0080};
        i_state_45 = {16'h0040, 16'h0020};
        i_accel_01 = {16'h0010, 16'h0010};
        i_accel_2  = {16'd0, 16'h0010};
        i_dt       = 16'h0100;
        @(posedge i_clk);
        if (o_busy) begin
            $display("[PASS] Busy flag asserted during execution");
            pass_count = pass_count + 1;
        end else $display("[FAIL] Busy flag not asserted");
        i_valid = 1'b0;
        while (!o_valid) @(posedge i_clk);

        //--- Test 4: Non-zero state produces non-zero output ---
        $display("[KALMAN 4] Non-zero state produces non-zero output");
        test_count = test_count + 1;
        // Continue from Test 3 — result should be non-zero
        if (o_state_01 != 32'd0 || o_state_23 != 32'd0) begin
            $display("[PASS] Non-zero output: 0x%08h 0x%08h 0x%08h",
                     o_state_01, o_state_23, o_state_45);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Output all zeros with non-zero input");

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Xdrone Kalman Test Summary: %0d/%0d passed", pass_count, test_count);
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
