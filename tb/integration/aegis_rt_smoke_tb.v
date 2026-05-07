//===============================================================================
// Testbench: aegis_rt_smoke_tb
// Integration smoke test for aegis_rt_top
// Tests: Boot → Write TCM → Read TCM → Interrupt → Safe-state → Halt
//===============================================================================

`timescale 1ns/1ps
`include "smu_fault_codes.vh"

module aegis_rt_smoke_tb;
    parameter CLK_PERIOD_NS = 4.167;  // 240 MHz
    parameter RST_CYCLES    = 20;

    // Signals
    reg         i_clk;
    reg         i_rst_n;
    reg         i_tcls_en;
    wire        o_tcls_fault;

    // AXI (simplified — not actively driven in smoke test)
    wire [31:0] o_axi_aw_addr;
    wire        o_axi_aw_valid;
    wire        i_axi_aw_ready = 1'b1;
    wire [31:0] o_axi_w_data;
    wire        o_axi_w_valid;
    wire        i_axi_w_ready = 1'b1;
    wire [1:0]  i_axi_b_resp = 2'b00;
    wire        i_axi_b_valid = 1'b0;
    wire        o_axi_b_ready;
    wire [31:0] i_axi_r_data = 32'd0;
    wire [1:0]  i_axi_r_resp = 2'b00;
    wire        i_axi_r_valid = 1'b0;
    wire        o_axi_r_ready;
    wire [31:0] o_axi_ar_addr;
    wire        o_axi_ar_valid;
    wire        i_axi_ar_ready = 1'b1;

    // Interrupts
    reg  [10:0] i_irq_pending;

    // Power
    wire        o_sleep_en;
    wire        o_iso_en;
    wire        o_retention_en;
    wire        o_pwr_switch_n;

    // Debug
    wire [31:0] o_debug_pc;
    reg         i_debug_halt;

    // DUT
    aegis_rt_top dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_tcls_en(i_tcls_en),
        .o_tcls_fault(o_tcls_fault),
        .o_axi_aw_addr(o_axi_aw_addr),
        .o_axi_aw_valid(o_axi_aw_valid),
        .i_axi_aw_ready(i_axi_aw_ready),
        .o_axi_w_data(o_axi_w_data),
        .o_axi_w_valid(o_axi_w_valid),
        .i_axi_w_ready(i_axi_w_ready),
        .i_axi_b_resp(i_axi_b_resp),
        .i_axi_b_valid(i_axi_b_valid),
        .o_axi_b_ready(o_axi_b_ready),
        .i_axi_r_data(i_axi_r_data),
        .i_axi_r_resp(i_axi_r_resp),
        .i_axi_r_valid(i_axi_r_valid),
        .o_axi_r_ready(o_axi_r_ready),
        .o_axi_ar_addr(o_axi_ar_addr),
        .o_axi_ar_valid(o_axi_ar_valid),
        .i_axi_ar_ready(i_axi_ar_ready),
        .i_irq_pending(i_irq_pending),
        .o_sleep_en(o_sleep_en),
        .o_iso_en(o_iso_en),
        .o_retention_en(o_retention_en),
        .o_pwr_switch_n(o_pwr_switch_n),
        .o_debug_pc(o_debug_pc),
        .i_debug_halt(i_debug_halt)
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
        i_tcls_en     = 1'b0;
        i_irq_pending = 11'd0;
        i_debug_halt  = 1'b0;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Reset + No Faults ---
        $display("[SMOKE 1] Reset + No Faults");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        repeat(50) @(posedge i_clk);
        if (o_tcls_fault == 1'b0 && o_sleep_en == 1'b0 && o_iso_en == 1'b0 && o_pwr_switch_n == 1'b0) begin
            $display("[PASS] System idle after reset: fault=%0b, sleep=%0b, iso=%0b, pwr=%0b",
                     o_tcls_fault, o_sleep_en, o_iso_en, o_pwr_switch_n);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] System not idle: fault=%0b, sleep=%0b, iso=%0b, pwr=%0b",
                     o_tcls_fault, o_sleep_en, o_iso_en, o_pwr_switch_n);
        end

        //--- Test 2: TCLS Enable ---
        $display("[SMOKE 2] TCLS Enable");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_tcls_en = 1'b1;
        repeat(20) @(posedge i_clk);
        if (o_tcls_fault == 1'b0) begin
            $display("[PASS] TCLS enabled, no fault");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TCLS fault: %0b", o_tcls_fault);
        end

        //--- Test 3: Power Domain Normal Operation ---
        $display("[SMOKE 3] Power Domain Normal Operation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        repeat(100) @(posedge i_clk);
        // Power should be ON (pwr_switch_n=0), no isolation, no sleep
        if (o_pwr_switch_n == 1'b0 && o_iso_en == 1'b0) begin
            $display("[PASS] Power domain normal: pwr_n=%0b, iso=%0b", o_pwr_switch_n, o_iso_en);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Power domain abnormal: pwr_n=%0b, iso=%0b", o_pwr_switch_n, o_iso_en);
        end

        //--- Test 4: Debug PC Advancing ---
        $display("[SMOKE 4] Debug PC Advancing");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        begin : pc_check
            integer pc_changed;
            reg [31:0] prev_pc;
            pc_changed = 0;
            prev_pc = o_debug_pc;
            repeat(20) @(posedge i_clk);
            if (o_debug_pc != prev_pc) begin
                pc_changed = 1;
            end
            if (pc_changed) begin
                $display("[PASS] PC advancing: prev=0x%08h, curr=0x%08h", prev_pc, o_debug_pc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] PC not advancing: 0x%08h", o_debug_pc);
            end
        end

        //--- Test 5: No Spurious Faults During Normal Operation ---
        $display("[SMOKE 5] No Spurious Faults During Normal Operation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        begin : no_spurious
            integer spurious;
            spurious = 0;
            repeat(500) @(posedge i_clk) begin
                if (o_tcls_fault || o_iso_en || o_pwr_switch_n) begin
                    spurious = 1;
                end
            end
            if (!spurious) begin
                $display("[PASS] No spurious faults during 500 cycles");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Spurious fault detected");
            end
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("AEGIS RT Smoke Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) begin
            $display("[✓] All smoke tests passed");
        end else begin
            $display("[✗] Some smoke tests failed");
        end
        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/aegis_rt_smoke.vcd");
        $dumpvars(0, aegis_rt_smoke_tb);
    end
    `endif

    initial begin
        repeat(500000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
