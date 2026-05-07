//===============================================================================
// Testbench: smu_tb
// Module Under Test: smu
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps
`include "smu_fault_codes.vh"

module smu_tb;
    // Parameters
    parameter CLK_PERIOD_NS = 4.167;  // 240 MHz
    parameter RST_CYCLES    = 10;

    // Signals
    reg         i_clk = 1'b0;
    reg         i_rst_n = 1'b0;
    reg  [7:0]  i_fault_code;
    reg         i_fault_valid;
    wire [7:0]  o_active_fault;
    wire [1:0]  o_fault_severity;
    wire        o_safe_state_req;
    reg         i_fault_ack;
    reg         i_safe_state_req;
    wire [31:0] o_fault_history;
    wire        o_fault_latched;

    // DUT Instantiation
    smu dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_fault_code(i_fault_code),
        .i_fault_valid(i_fault_valid),
        .o_active_fault(o_active_fault),
        .o_fault_severity(o_fault_severity),
        .o_safe_state_req(o_safe_state_req),
        .i_fault_ack(i_fault_ack),
        .i_safe_state_req(i_safe_state_req),
        .o_fault_history(o_fault_history),
        .o_fault_latched(o_fault_latched)
    );

    // Clock Generation
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    // Reset Task
    task automatic apply_reset;
        input [31:0] cycles;
        begin
            i_rst_n = 0;
            repeat(cycles) @(posedge i_clk);
            i_rst_n = 1;
            @(posedge i_clk);
        end
    endtask

    // Initialize signals
    initial begin
        i_fault_code    = 8'd0;
        i_fault_valid   = 1'b0;
        i_fault_ack     = 1'b0;
        i_safe_state_req = 1'b0;
    end

    // Test Counter
    integer test_count;
    integer pass_count;

    // Test Sequences
    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Reset + Idle ---
        $display("[TEST 1] Reset + Idle State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #100;
        if (o_active_fault == 8'd0 && o_fault_latched == 1'b0 && o_safe_state_req == 1'b0) begin
            $display("[PASS] SMU idle after reset");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] SMU not idle after reset");
        end

        //--- Test 2: Single SPF Fault Latch ---
        $display("[TEST 2] Single SPF Fault Latch (TCLS_MISMATCH)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_fault_code  = `FC_TCLS_MISMATCH;
        i_fault_valid = 1'b1;
        @(posedge i_clk); #1;
        i_fault_valid = 1'b0;
        @(posedge i_clk); #1;
        if (o_active_fault == `FC_TCLS_MISMATCH && o_fault_latched == 1'b1) begin
            $display("[PASS] SPF fault latched correctly");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] SPF fault not latched: active_fault=0x%02h, latched=%0b", o_active_fault, o_fault_latched);
        end

        //--- Test 3: SPF Triggers Safe-State ---
        $display("[TEST 3] SPF Triggers Safe-State (threshold=1)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        i_fault_code  = `FC_WATCHDOG_TIMEOUT;
        i_fault_valid = 1'b1;
        #1;
        @(posedge i_clk); #1;
        i_fault_valid = 1'b0;
        // Wait for FSM: IDLE→EVALUATE→TRIGGER (2 cycles)
        repeat(3) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] Safe-state triggered by SPF");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state not triggered: safe_state_req=%0b", o_safe_state_req);
        end

        //--- Test 4: LF Accumulation ---
        $display("[TEST 4] LF Accumulation (3 LFs trigger safe-state)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Inject 3 latent faults
        repeat(3) begin
            i_fault_code  = `FC_ECC_DOUBLE_BIT;
            i_fault_valid = 1'b1;
            @(posedge i_clk); #1;
            i_fault_valid = 1'b0;
            @(posedge i_clk); #1;
        end
        // Wait for FSM evaluation + trigger
        repeat(3) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] Safe-state triggered by LF accumulation");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state not triggered by LF accumulation");
        end

        //--- Test 5: MPF Triggers Safe-State ---
        $display("[TEST 5] MPF Triggers Safe-State (threshold=1)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        i_fault_code  = `FC_PMP_VIOLATION;
        i_fault_valid = 1'b1;
        #1;
        @(posedge i_clk); #1;
        i_fault_valid = 1'b0;
        repeat(3) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] Safe-state triggered by MPF");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state not triggered by MPF");
        end

        //--- Test 6: Fault Acknowledge Clears Latch ---
        $display("[TEST 6] Fault Acknowledge Clears Latch");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_fault_code  = `FC_TCLS_MISMATCH;
        i_fault_valid = 1'b1;
        @(posedge i_clk); #1;
        i_fault_valid = 1'b0;
        @(posedge i_clk); #1;
        // Acknowledge
        i_fault_ack = 1'b1;
        @(posedge i_clk); #1;
        i_fault_ack = 1'b0;
        @(posedge i_clk); #1;
        if (o_fault_latched == 1'b0 && o_active_fault == 8'd0) begin
            $display("[PASS] Fault latch cleared on acknowledge");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Fault latch not cleared: latched=%0b, fault=0x%02h", o_fault_latched, o_active_fault);
        end

        //--- Test 7: Software Safe-State Request ---
        $display("[TEST 7] Software Safe-State Request");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_safe_state_req = 1'b1;
        repeat(3) @(posedge i_clk);
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] Software safe-state request triggered");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Software safe-state request not triggered");
        end
        i_safe_state_req = 1'b0;

        //--- Test 8: Fault History Register ---
        $display("[TEST 8] Fault History Register");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Inject TCLS_MISMATCH (code 1) → bit 1 should be set
        i_fault_code  = `FC_TCLS_MISMATCH;
        i_fault_valid = 1'b1;
        @(posedge i_clk);
        i_fault_valid = 1'b0;
        @(posedge i_clk);
        // Inject WATCHDOG_TIMEOUT (code 4) → bit 4 should be set
        i_fault_code  = `FC_WATCHDOG_TIMEOUT;
        i_fault_valid = 1'b1;
        @(posedge i_clk);
        i_fault_valid = 1'b0;
        @(posedge i_clk);
        if (o_fault_history[1] == 1'b1 && o_fault_history[4] == 1'b1) begin
            $display("[PASS] Fault history register correct");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Fault history incorrect: 0x%08h", o_fault_history);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("SMU Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) begin
            $display("[✓] All tests passed");
        end else begin
            $display("[✗] Some tests failed");
        end
        $finish;
    end

    // Waveform Dump
    `ifdef TRACE
    initial begin
        $dumpfile("sim/smu.vcd");
        $dumpvars(0, smu_tb);
    end
    `endif

    // Timeout Guard
    initial begin
        repeat(100000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
