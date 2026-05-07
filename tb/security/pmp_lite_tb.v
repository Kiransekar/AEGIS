//===============================================================================
// Testbench: pmp_lite_tb
// Module Under Test: pmp_lite
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module pmp_lite_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk;
    reg         i_rst_n;
    reg  [31:0] i_access_addr;
    reg         i_access_we;
    reg         i_access_re;
    reg  [1:0]  i_access_priv;
    wire        o_access_ok;
    wire        o_access_violation;
    reg  [3:0]  i_csr_region_sel;
    reg  [31:0] i_csr_addr;
    reg  [31:0] i_csr_addr_mask;
    reg         i_csr_we;
    reg  [1:0]  i_csr_perm;

    pmp_lite dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_access_addr(i_access_addr),
        .i_access_we(i_access_we),
        .i_access_re(i_access_re),
        .i_access_priv(i_access_priv),
        .o_access_ok(o_access_ok),
        .o_access_violation(o_access_violation),
        .i_csr_region_sel(i_csr_region_sel),
        .i_csr_addr(i_csr_addr),
        .i_csr_addr_mask(i_csr_addr_mask),
        .i_csr_we(i_csr_we),
        .i_csr_perm(i_csr_perm)
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
        i_access_addr    = 32'd0;
        i_access_we      = 1'b0;
        i_access_re      = 1'b0;
        i_access_priv    = 2'b11;
        i_csr_region_sel = 4'd0;
        i_csr_addr       = 32'd0;
        i_csr_addr_mask  = 32'd0;
        i_csr_we         = 1'b0;
        i_csr_perm       = 2'd0;

        //--- Test 1: Deny-By-Default (no regions configured) ---
        $display("[TEST 1] Deny-By-Default (no regions configured)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_access_addr = 32'h0001_0000;
        i_access_re   = 1'b1;
        #10;
        if (o_access_ok == 1'b0) begin
            $display("[PASS] Access denied by default");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Access allowed without configuration: ok=%0b", o_access_ok);
        end

        //--- Test 2: Configure RW Region + Access Granted ---
        $display("[TEST 2] Configure RW Region + Access Granted");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Configure region 0: base=0x00010000, mask=0xFFFF0000, perm=RW(10)
        i_csr_region_sel = 4'd0;
        i_csr_addr       = 32'h0001_0000;
        i_csr_addr_mask  = 32'hFFFF_0000;
        i_csr_perm       = 2'd10;  // RW
        i_csr_we         = 1'b1;
        @(posedge i_clk);
        i_csr_we = 1'b0;
        @(posedge i_clk);
        // Read access
        i_access_addr = 32'h0001_0000;
        i_access_re   = 1'b1;
        i_access_we   = 1'b0;
        #10;
        if (o_access_ok == 1'b1) begin
            $display("[PASS] RW region read access granted");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RW region read access denied: ok=%0b", o_access_ok);
        end

        //--- Test 3: Write to Read-Only Region = Violation ---
        $display("[TEST 3] Write to Read-Only Region = Violation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Configure region 1: base=0x00020000, mask=0xFFFF0000, perm=RO(01)
        i_csr_region_sel = 4'd1;
        i_csr_addr       = 32'h0002_0000;
        i_csr_addr_mask  = 32'hFFFF_0000;
        i_csr_perm       = 2'd01;  // Read-only
        i_csr_we         = 1'b1;
        @(posedge i_clk);
        i_csr_we = 1'b0;
        @(posedge i_clk);
        // Write access to read-only region
        i_access_addr = 32'h0002_0000;
        i_access_re   = 1'b0;
        i_access_we   = 1'b1;
        #10;
        if (o_access_violation == 1'b1 && o_access_ok == 1'b0) begin
            $display("[PASS] Write to RO region correctly flagged as violation");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Write to RO region: ok=%0b, violation=%0b", o_access_ok, o_access_violation);
        end

        //--- Test 4: Unmapped Address Denied ---
        $display("[TEST 4] Unmapped Address Denied");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Configure region 0 only
        i_csr_region_sel = 4'd0;
        i_csr_addr       = 32'h0001_0000;
        i_csr_addr_mask  = 32'hFFFF_0000;
        i_csr_perm       = 2'd10;
        i_csr_we         = 1'b1;
        @(posedge i_clk);
        i_csr_we = 1'b0;
        @(posedge i_clk);
        // Access outside region
        i_access_addr = 32'h0003_0000;
        i_access_re   = 1'b1;
        i_access_we   = 1'b0;
        #10;
        if (o_access_ok == 1'b0) begin
            $display("[PASS] Unmapped address denied");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Unmapped address allowed: ok=%0b", o_access_ok);
        end

        //--- Test 5: NONE Permission Denies All ---
        $display("[TEST 5] NONE Permission (perm=00) Denies All");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_csr_region_sel = 4'd2;
        i_csr_addr       = 32'h0004_0000;
        i_csr_addr_mask  = 32'hFFFF_0000;
        i_csr_perm       = 2'd00;  // NONE
        i_csr_we         = 1'b1;
        @(posedge i_clk);
        i_csr_we = 1'b0;
        @(posedge i_clk);
        i_access_addr = 32'h0004_0000;
        i_access_re   = 1'b1;
        #10;
        if (o_access_ok == 1'b0) begin
            $display("[PASS] NONE permission denies access");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] NONE permission allowed access: ok=%0b", o_access_ok);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("PMP Lite Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/pmp_lite.vcd");
        $dumpvars(0, pmp_lite_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
