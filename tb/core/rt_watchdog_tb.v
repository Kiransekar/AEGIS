//===============================================================================
// Testbench: rt_watchdog_tb
// Module Under Test: rt_watchdog
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module rt_watchdog_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk = 1'b0, i_rst_n = 1'b0;
    reg         i_enable;
    reg  [31:0] i_timeout;
    reg         i_kick;
    wire        o_timeout;
    wire [31:0] o_counter;
    wire        o_enabled;

    rt_watchdog dut (.*);

    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    integer test_count, pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;
        i_enable = 1'b0;
        i_timeout = 32'd100;
        i_kick = 1'b0;

        //--- Test 1: Disabled After Reset ---
        $display("[WDG 1] Disabled After Reset");
        test_count = test_count + 1;
        i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
        i_rst_n = 1; @(posedge i_clk);
        if (!o_enabled && !o_timeout && o_counter == 32'd0) begin
            $display("[PASS] Watchdog disabled after reset");
            pass_count = pass_count + 1;
        end else $display("[FAIL] enabled=%0b, timeout=%0b, counter=%0d", o_enabled, o_timeout, o_counter);

        //--- Test 2: Enable + Countdown ---
        $display("[WDG 2] Enable + Countdown");
        test_count = test_count + 1;
        i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
        i_rst_n = 1; @(posedge i_clk);
        i_enable = 1'b1;
        i_timeout = 32'd10;
        repeat(5) @(posedge i_clk); #1;
        if (o_enabled && o_counter < 32'd10 && o_counter > 32'd0) begin
            $display("[PASS] Watchdog counting: counter=%0d", o_counter);
            pass_count = pass_count + 1;
        end else $display("[FAIL] counter=%0d, enabled=%0b", o_counter, o_enabled);

        //--- Test 3: Kick Resets Counter ---
        $display("[WDG 3] Kick Resets Counter");
        test_count = test_count + 1;
        i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
        i_rst_n = 1; @(posedge i_clk);
        i_enable = 1'b1;
        i_timeout = 32'd10;
        repeat(8) @(posedge i_clk);
        i_kick = 1'b1;
        @(posedge i_clk);
        i_kick = 1'b0;
        if (o_counter == 32'd10) begin
            $display("[PASS] Kick reset counter to %0d", o_counter);
            pass_count = pass_count + 1;
        end else $display("[FAIL] counter=%0d (expected 10)", o_counter);

        //--- Test 4: Timeout Occurs ---
        $display("[WDG 4] Timeout Occurs");
        test_count = test_count + 1;
        i_enable = 1'b0;
        i_timeout = 32'd5;
        i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
        i_rst_n = 1; @(posedge i_clk);
        i_enable = 1'b1;
        #1;
        // Wait for timeout without kicking
        repeat(8) @(posedge i_clk); #1;
        if (o_timeout) begin
            $display("[PASS] Watchdog timeout detected");
            pass_count = pass_count + 1;
        end else $display("[FAIL] timeout=%0b, counter=%0d", o_timeout, o_counter);

        //--- Test 5: Timeout Latching (requires reset) ---
        $display("[WDG 5] Timeout Latching");
        test_count = test_count + 1;
        // Continue from Test 4 — timeout should still be set
        repeat(5) @(posedge i_clk); #1;
        if (o_timeout) begin
            $display("[PASS] Timeout latched (requires reset)");
            pass_count = pass_count + 1;
        end else $display("[FAIL] Timeout not latched");

        //--- Test 6: Disable Stops Watchdog ---
        $display("[WDG 6] Disable Stops Watchdog");
        test_count = test_count + 1;
        i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
        i_rst_n = 1; @(posedge i_clk);
        i_enable = 1'b1;
        i_timeout = 32'd100;
        repeat(10) @(posedge i_clk); #1;
        i_enable = 1'b0;
        repeat(5) @(posedge i_clk); #1;
        if (!o_enabled && !o_timeout) begin
            $display("[PASS] Watchdog disabled, no timeout");
            pass_count = pass_count + 1;
        end else $display("[FAIL] enabled=%0b, timeout=%0b", o_enabled, o_timeout);

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("RT Watchdog Test Summary: %0d/%0d passed", pass_count, test_count);
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
