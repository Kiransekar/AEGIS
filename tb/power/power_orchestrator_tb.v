//===============================================================================
// Testbench: power_orchestrator_tb
// Module Under Test: power_orchestrator
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module power_orchestrator_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    // Signals
    reg         i_clk;
    reg         i_rst_n;
    reg         i_smu_safe_req;
    reg  [7:0]  i_smu_fault_code;
    reg         i_sleep_req;
    reg         i_wake_req;
    reg  [3:0]  i_tile_state_req;
    wire        o_sleep_en;
    wire        o_iso_en;
    wire        o_retention_en;
    wire        o_pwr_switch_n;
    wire [3:0]  o_tile_state;
    wire        o_safe_state_active;
    wire        o_wake_in_progress;
    wire        o_wake_start;
    reg         i_wake_done;

    // DUT
    power_orchestrator dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_smu_safe_req(i_smu_safe_req),
        .i_smu_fault_code(i_smu_fault_code),
        .i_sleep_req(i_sleep_req),
        .i_wake_req(i_wake_req),
        .i_tile_state_req(i_tile_state_req),
        .o_sleep_en(o_sleep_en),
        .o_iso_en(o_iso_en),
        .o_retention_en(o_retention_en),
        .o_pwr_switch_n(o_pwr_switch_n),
        .o_tile_state(o_tile_state),
        .o_safe_state_active(o_safe_state_active),
        .o_wake_in_progress(o_wake_in_progress),
        .o_wake_start(o_wake_start),
        .i_wake_done(i_wake_done)
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

    // Initialize
    initial begin
        i_smu_safe_req    = 1'b0;
        i_smu_fault_code  = 8'd0;
        i_sleep_req       = 1'b0;
        i_wake_req        = 1'b0;
        i_tile_state_req  = 4'd0;
        i_wake_done       = 1'b0;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: Reset → RUN State ---
        $display("[TEST 1] Reset → RUN State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #100;
        if (o_tile_state == 4'b0001 && o_safe_state_active == 1'b0 && o_pwr_switch_n == 1'b0) begin
            $display("[PASS] Power state = RUN after reset");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Power state != RUN: state=0x%01h, safe=%0b, pwr_n=%0b",
                     o_tile_state, o_safe_state_active, o_pwr_switch_n);
        end

        //--- Test 2: Software Sleep Request ---
        $display("[TEST 2] Software Sleep Request (RUN→SLEEP_PREP→SLEEP)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_sleep_req = 1'b1;
        @(posedge i_clk);
        i_sleep_req = 1'b0;
        // Wait for SLEEP_PREP (1 cycle) then SLEEP (1 cycle)
        repeat(3) @(posedge i_clk);
        if (o_sleep_en == 1'b1 && o_retention_en == 1'b1 && o_tile_state == 4'b0100) begin
            $display("[PASS] Sleep transition completed");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Sleep transition failed: sleep_en=%0b, ret_en=%0b, state=0x%01h",
                     o_sleep_en, o_retention_en, o_tile_state);
        end

        //--- Test 3: Wake from Sleep ---
        $display("[TEST 3] Wake from Sleep (SLEEP→RUN)");
        test_count = test_count + 1;
        // Continue from Test 2 (in SLEEP state)
        i_wake_req = 1'b1;
        @(posedge i_clk);
        i_wake_req = 1'b0;
        repeat(3) @(posedge i_clk);
        if (o_tile_state == 4'b0001 && o_sleep_en == 1'b0) begin
            $display("[PASS] Wake transition completed");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Wake transition failed: state=0x%01h, sleep_en=%0b",
                     o_tile_state, o_sleep_en);
        end

        //--- Test 4: SMU Safe-State from RUN ---
        $display("[TEST 4] SMU Safe-State from RUN (RUN→SAFE_STATE)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_smu_safe_req = 1'b1;
        @(posedge i_clk);
        i_smu_safe_req = 1'b0;
        repeat(2) @(posedge i_clk);
        if (o_safe_state_active == 1'b1 && o_iso_en == 1'b1 && o_pwr_switch_n == 1'b1) begin
            $display("[PASS] Safe-state transition completed");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state transition failed: safe=%0b, iso=%0b, pwr_n=%0b",
                     o_safe_state_active, o_iso_en, o_pwr_switch_n);
        end

        //--- Test 5: Safe-State is Irreversible (no exit without reset) ---
        $display("[TEST 5] Safe-State Irreversibility");
        test_count = test_count + 1;
        // Continue from Test 4 (in SAFE_STATE)
        i_wake_req = 1'b1;
        repeat(5) @(posedge i_clk);
        i_wake_req = 1'b0;
        if (o_safe_state_active == 1'b1) begin
            $display("[PASS] Safe-state remains active (irreversible)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state exited without reset");
        end

        //--- Test 6: SMU Safe-State from SLEEP ---
        $display("[TEST 6] SMU Safe-State from SLEEP (SLEEP→SAFE_STATE)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Go to sleep first
        i_sleep_req = 1'b1;
        @(posedge i_clk);
        i_sleep_req = 1'b0;
        repeat(3) @(posedge i_clk);
        // Trigger safe-state from sleep
        i_smu_safe_req = 1'b1;
        @(posedge i_clk);
        i_smu_safe_req = 1'b0;
        repeat(2) @(posedge i_clk);
        if (o_safe_state_active == 1'b1 && o_iso_en == 1'b1) begin
            $display("[PASS] Safe-state from sleep completed");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Safe-state from sleep failed");
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Power Orchestrator Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/power_orchestrator.vcd");
        $dumpvars(0, power_orchestrator_tb);
    end
    `endif

    initial begin
        repeat(100000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
