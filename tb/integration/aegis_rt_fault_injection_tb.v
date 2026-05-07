//===============================================================================
// Testbench: aegis_rt_fault_injection_tb
// Fault injection testbench for safety mechanism verification
// Tests: SEU in TCM, TCLS mismatch, ECC double-bit, watchdog timeout
//===============================================================================

`timescale 1ns/1ps
`include "smu_fault_codes.vh"

module aegis_rt_fault_injection_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 20;

    // SMU DUT signals
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

    // Power Orchestrator DUT signals
    wire        po_sleep_en;
    wire        po_iso_en;
    wire        po_retention_en;
    wire        po_pwr_switch_n;
    wire [3:0]  po_tile_state;
    wire        po_safe_state_active;
    wire        po_wake_in_progress;
    wire        po_wake_start;

    // SMU DUT
    smu u_smu (
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

    // Power Orchestrator DUT
    power_orchestrator u_power (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_smu_safe_req(o_safe_state_req),
        .i_smu_fault_code(o_active_fault),
        .i_sleep_req(1'b0),
        .i_wake_req(1'b0),
        .i_tile_state_req(4'd0),
        .o_sleep_en(po_sleep_en),
        .o_iso_en(po_iso_en),
        .o_retention_en(po_retention_en),
        .o_pwr_switch_n(po_pwr_switch_n),
        .o_tile_state(po_tile_state),
        .o_safe_state_active(po_safe_state_active),
        .o_wake_in_progress(po_wake_in_progress),
        .o_wake_start(po_wake_start),
        .i_wake_done(1'b0)
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

    // Fault injection helper
    task automatic inject_fault;
        input [7:0] code;
        begin
            i_fault_code  = code;
            i_fault_valid = 1'b1;
            #1;
            @(posedge i_clk); #1;
            i_fault_valid = 1'b0;
        end
    endtask

    initial begin
        i_fault_code    = 8'd0;
        i_fault_valid   = 1'b0;
        i_fault_ack     = 1'b0;
        i_safe_state_req = 1'b0;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Fault Injection 1: TCLS Mismatch → Safe-State ---
        $display("[FAULT 1] TCLS Mismatch → SMU → Power Safe-State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_TCLS_MISMATCH);
        // Wait for SMU aggregation + safe-state
        repeat(5) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1 && po_safe_state_active == 1'b1 && po_iso_en == 1'b1) begin
            $display("[PASS] TCLS mismatch → safe-state chain: smu_req=%0b, safe=%0b, iso=%0b",
                     o_safe_state_req, po_safe_state_active, po_iso_en);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TCLS mismatch chain: smu_req=%0b, safe=%0b, iso=%0b",
                     o_safe_state_req, po_safe_state_active, po_iso_en);
        end

        //--- Fault Injection 2: ECC Double-Bit → SMU Fault ---
        $display("[FAULT 2] ECC Double-Bit → SMU Fault Latch");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_ECC_DOUBLE_BIT);
        @(posedge i_clk); #1;
        if (o_fault_latched == 1'b1 && o_active_fault == `FC_ECC_DOUBLE_BIT) begin
            $display("[PASS] ECC double-bit fault latched: code=0x%02h", o_active_fault);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] ECC double-bit fault: latched=%0b, code=0x%02h", o_fault_latched, o_active_fault);
        end

        //--- Fault Injection 3: Watchdog Timeout → Safe-State ---
        $display("[FAULT 3] Watchdog Timeout → Safe-State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_WATCHDOG_TIMEOUT);
        repeat(5) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] Watchdog timeout → safe-state");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Watchdog timeout: safe_req=%0b", o_safe_state_req);
        end

        //--- Fault Injection 4: PMP Violation → SMU Fault ---
        $display("[FAULT 4] PMP Violation → SMU Fault (MPF)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_PMP_VIOLATION);
        // Check severity while fault is still latched (not from i_fault_valid)
        if (o_fault_latched && o_active_fault == `FC_PMP_VIOLATION) begin
            $display("[PASS] PMP violation: latched, code=0x%02h", o_active_fault);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] PMP violation: latched=%0b, code=0x%02h", o_fault_latched, o_active_fault);
        end

        //--- Fault Injection 5: Multiple Latent Faults → Safe-State ---
        $display("[FAULT 5] 3 Latent Faults → Safe-State (LF accumulation)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_POWER_GLITCH);
        @(posedge i_clk); #1;
        inject_fault(`FC_CLOCK_MONITOR_TRIP);
        @(posedge i_clk); #1;
        inject_fault(`FC_RETENTION_RESTORE_FAIL);
        @(posedge i_clk); #1;
        repeat(5) @(posedge i_clk); #1;
        if (o_safe_state_req == 1'b1) begin
            $display("[PASS] LF accumulation → safe-state");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] LF accumulation: safe_req=%0b", o_safe_state_req);
        end

        //--- Fault Injection 6: Safe-State Irreversibility ---
        $display("[FAULT 6] Safe-State Irreversibility (no exit without reset)");
        test_count = test_count + 1;
        // Continue from Fault 5 (already in safe-state)
        repeat(20) @(posedge i_clk); #1;
        if (po_safe_state_active == 1'b1) begin
            $display("[PASS] Safe-state remains active (irreversible)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state exited without reset");
        end

        //--- Fault Injection 7: Fault History Accumulation ---
        $display("[FAULT 7] Fault History Accumulation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        inject_fault(`FC_TCLS_MISMATCH);      // Bit 1
        @(posedge i_clk); #1;
        i_fault_ack = 1'b1; @(posedge i_clk); #1; i_fault_ack = 1'b0;
        @(posedge i_clk); #1;
        inject_fault(`FC_WATCHDOG_TIMEOUT);   // Bit 4
        @(posedge i_clk); #1;
        i_fault_ack = 1'b1; @(posedge i_clk); #1; i_fault_ack = 1'b0;
        @(posedge i_clk); #1;
        inject_fault(`FC_ECC_DOUBLE_BIT);     // Bit 16
        @(posedge i_clk); #1;
        if (o_fault_history[1] == 1'b1 && o_fault_history[4] == 1'b1 && o_fault_history[16] == 1'b1) begin
            $display("[PASS] Fault history correct: 0x%08h", o_fault_history);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Fault history: 0x%08h", o_fault_history);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Fault Injection Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("===============================================================================");
        if (pass_count == test_count) begin
            $display("[✓] All fault injection tests passed");
        end else begin
            $display("[✗] Some fault injection tests failed");
        end
        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/aegis_rt_fault_injection.vcd");
        $dumpvars(0, aegis_rt_fault_injection_tb);
    end
    `endif

    initial begin
        repeat(500000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
