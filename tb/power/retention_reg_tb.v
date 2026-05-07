//===============================================================================
// Testbench: retention_reg_32_tb
// Module Under Test: retention_reg_32
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module retention_reg_32_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk = 1'b0;
    reg         i_rst_n = 1'b0;
    reg  [31:0] i_din;
    wire [31:0] o_dout;
    reg         i_retention_en;
    reg         i_restore;
    wire        o_restore_fail;

    retention_reg_32 dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_din(i_din),
        .o_dout(o_dout),
        .i_retention_en(i_retention_en),
        .i_restore(i_restore),
        .o_restore_fail(o_restore_fail)
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
        i_din          = 32'd0;
        i_retention_en = 1'b0;
        i_restore      = 1'b0;

        //--- Test 1: Normal Register Write/Read ---
        $display("[TEST 1] Normal Register Write/Read");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_din = 32'hDEAD_BEEF;
        @(posedge i_clk); #1;
        if (o_dout == 32'hDEAD_BEEF) begin
            $display("[PASS] Register write/read: 0x%08h", o_dout);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register write/read: 0x%08h (expected 0xDEADBEEF)", o_dout);
        end

        //--- Test 2: Retention Save ---
        $display("[TEST 2] Retention Save (shadow captures main register)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_din = 32'h1234_5678;
        @(posedge i_clk); #1;
        // Enable retention — shadow should capture current value
        i_retention_en = 1'b1;
        @(posedge i_clk); #1;
        // Change main register value (retention still enabled)
        i_din = 32'hAAAA_5555;
        @(posedge i_clk); #1;
        // Shadow should still hold 0x12345678
        i_retention_en = 1'b0;
        @(posedge i_clk); #1;
        // Restore from shadow
        i_restore = 1'b1;
        @(posedge i_clk); #1;
        if (o_dout == 32'h1234_5678) begin
            $display("[PASS] Retention save/restore: 0x%08h", o_dout);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Retention save/restore: 0x%08h (expected 0x12345678)", o_dout);
        end
        i_restore = 1'b0;

        //--- Test 3: Restore Mismatch Detection ---
        $display("[TEST 3] Restore Mismatch Detection");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_din = 32'h0000_0001;
        @(posedge i_clk); #1;
        // Save to shadow
        i_retention_en = 1'b1;
        @(posedge i_clk); #1;
        // Overwrite main register while shadow is different
        i_din = 32'h0000_0002;
        i_retention_en = 1'b0;
        @(posedge i_clk); #1;
        // Restore — main != shadow → mismatch
        i_restore = 1'b1;
        #1;
        if (o_restore_fail == 1'b1) begin
            $display("[PASS] Restore mismatch detected");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Restore mismatch not detected: fail=%0b", o_restore_fail);
        end
        i_restore = 1'b0;

        //--- Test 4: Reset Clears Register ---
        $display("[TEST 4] Reset Clears Register");
        test_count = test_count + 1;
        i_din = 32'hFFFF_FFFF;
        apply_reset(RST_CYCLES);
        i_din = 32'd0;
        #1;
        if (o_dout == 32'd0) begin
            $display("[PASS] Register cleared on reset");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register not cleared: 0x%08h", o_dout);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Retention Register Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/retention_reg_32.vcd");
        $dumpvars(0, retention_reg_32_tb);
    end
    `endif

    initial begin
        repeat(100000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
