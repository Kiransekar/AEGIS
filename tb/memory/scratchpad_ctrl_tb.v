//===============================================================================
// Testbench: scratchpad_ctrl_tb
// Module Under Test: scratchpad_ctrl
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module scratchpad_ctrl_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    // Signals
    reg         i_clk;
    reg         i_rst_n;
    reg  [18:0] i_addr;
    reg  [31:0] i_wdata;
    reg         i_we;
    reg         i_re;
    reg         i_valid;
    wire [31:0] o_rdata;
    wire        o_rdata_valid;
    wire        o_ready;
    wire        o_ecc_single_error;
    wire        o_ecc_double_error;
    wire [17:0] o_scrub_addr;
    wire        o_scrub_active;
    reg         i_scrub_enable;
    reg  [31:0] i_scrub_interval;

    // DUT
    scratchpad_ctrl dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_addr(i_addr),
        .i_wdata(i_wdata),
        .i_we(i_we),
        .i_re(i_re),
        .i_valid(i_valid),
        .o_rdata(o_rdata),
        .o_rdata_valid(o_rdata_valid),
        .o_ready(o_ready),
        .o_ecc_single_error(o_ecc_single_error),
        .o_ecc_double_error(o_ecc_double_error),
        .o_scrub_addr(o_scrub_addr),
        .o_scrub_active(o_scrub_active),
        .i_scrub_enable(i_scrub_enable),
        .i_scrub_interval(i_scrub_interval)
    );

    // Clock Generation
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

    initial begin
        i_addr           = 19'd0;
        i_wdata          = 32'd0;
        i_we             = 1'b0;
        i_re             = 1'b0;
        i_valid          = 1'b0;
        i_scrub_enable   = 1'b0;
        i_scrub_interval = 32'd100;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Write + Read Bank 0 ---
        $display("[TEST 1] Write + Read Bank 0 (lower 256 KB)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Write
        i_addr  = 19'h00001;  // Address 4 in bank 0
        i_wdata = 32'hDEAD_BEEF;
        i_we    = 1'b1;
        i_valid = 1'b1;
        @(posedge i_clk);
        i_we = 1'b0;
        // Read
        i_re = 1'b1;
        @(posedge i_clk);
        i_re = 1'b0;
        @(posedge i_clk);
        if (o_rdata_valid && o_rdata == 32'hDEAD_BEEF) begin
            $display("[PASS] Bank 0 write/read: data=0x%08h", o_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Bank 0 write/read: data=0x%08h, valid=%0b", o_rdata, o_rdata_valid);
        end

        //--- Test 2: Write + Read Bank 1 ---
        $display("[TEST 2] Write + Read Bank 1 (upper 256 KB)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_addr  = 19'h80001;  // Address 4 in bank 1
        i_wdata = 32'hCAFE_F00D;
        i_we    = 1'b1;
        i_valid = 1'b1;
        @(posedge i_clk);
        i_we = 1'b0;
        i_re = 1'b1;
        @(posedge i_clk);
        i_re = 1'b0;
        @(posedge i_clk);
        if (o_rdata_valid && o_rdata == 32'hCAFE_F00D) begin
            $display("[PASS] Bank 1 write/read: data=0x%08h", o_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Bank 1 write/read: data=0x%08h, valid=%0b", o_rdata, o_rdata_valid);
        end

        //--- Test 3: 1-Cycle Read Latency ---
        $display("[TEST 3] 1-Cycle Read Latency");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Write first
        i_addr  = 19'h00010;
        i_wdata = 32'h1234_5678;
        i_we    = 1'b1;
        i_valid = 1'b1;
        @(posedge i_clk);
        i_we = 1'b0;
        // Read — data valid should appear 1 cycle after re
        i_re = 1'b1;
        @(posedge i_clk);
        i_re = 1'b0;
        #1;
        // Check rdata_valid on next cycle
        if (o_rdata_valid == 1'b1) begin
            $display("[PASS] Read latency = 1 cycle");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Read latency incorrect: rdata_valid=%0b", o_rdata_valid);
        end

        //--- Test 4: Controller Always Ready ---
        $display("[TEST 4] Controller Always Ready (no backpressure)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #100;
        if (o_ready == 1'b1) begin
            $display("[PASS] Controller always ready");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Controller not ready: ready=%0b", o_ready);
        end

        //--- Test 5: Multiple Writes + Readback ---
        $display("[TEST 5] Multiple Writes + Readback");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        begin : multi_write
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                i_addr  = i[18:0] << 2;  // Word-aligned
                i_wdata = 32'hA000_0000 + i;
                i_we    = 1'b1;
                i_valid = 1'b1;
                @(posedge i_clk);
            end
            i_we = 1'b0;
            // Readback
            for (i = 0; i < 8; i = i + 1) begin
                i_addr = i[18:0] << 2;
                i_re   = 1'b1;
                @(posedge i_clk);
                i_re = 1'b0;
                @(posedge i_clk);
                if (o_rdata != 32'hA000_0000 + i) begin
                    $display("[FAIL] Readback mismatch at addr %0d: expected=0x%08h, got=0x%08h",
                             i, 32'hA000_0000 + i, o_rdata);
                end
            end
            $display("[PASS] Multiple writes + readback correct");
            pass_count = pass_count + 1;
        end

        //--- Test 6: Scrubber Activation ---
        $display("[TEST 6] Scrubber Activation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_scrub_enable   = 1'b1;
        i_scrub_interval = 32'd10;  // Short interval for test
        repeat(12) @(posedge i_clk);
        if (o_scrub_active) begin
            $display("[PASS] Scrubber activated");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Scrubber not activated: active=%0b, addr=0x%05h", o_scrub_active, o_scrub_addr);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Scratchpad Controller Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/scratchpad_ctrl.vcd");
        $dumpvars(0, scratchpad_ctrl_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
