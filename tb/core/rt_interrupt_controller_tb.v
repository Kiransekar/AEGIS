//===============================================================================
// Testbench: rt_interrupt_controller_tb
// Module Under Test: rt_interrupt_controller
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module rt_interrupt_controller_tb;
    parameter CLK_PERIOD_NS = 4.167;  // 240 MHz
    parameter RST_CYCLES    = 10;
    parameter NUM_IRQ       = 11;

    // Signals
    reg         i_clk = 1'b0;
    reg         i_rst_n = 1'b0;
    reg  [NUM_IRQ-1:0] i_irq_pending;
    reg         i_irq_ack;
    wire [NUM_IRQ-1:0] o_irq_vector;
    wire        o_irq_valid;
    wire [31:0] o_irq_pc_target;
    reg  [NUM_IRQ-1:0] i_irq_enable;
    reg  [NUM_IRQ-1:0] i_irq_priority;
    wire        o_irq_active;
    wire [3:0]  o_irq_entry_counter;

    // DUT
    rt_interrupt_controller dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_irq_pending(i_irq_pending),
        .i_irq_ack(i_irq_ack),
        .o_irq_vector(o_irq_vector),
        .o_irq_valid(o_irq_valid),
        .o_irq_pc_target(o_irq_pc_target),
        .i_irq_enable(i_irq_enable),
        .i_irq_priority(i_irq_priority),
        .o_irq_active(o_irq_active),
        .o_irq_entry_counter(o_irq_entry_counter)
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
        i_irq_pending  = {NUM_IRQ{1'b0}};
        i_irq_ack      = 1'b0;
        i_irq_enable   = {NUM_IRQ{1'b1}};  // All enabled
        i_irq_priority = {NUM_IRQ{1'b0}};
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: No Pending IRQs — Idle State ---
        $display("[TEST 1] No Pending IRQs — Idle State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #100;
        if (o_irq_valid == 1'b0 && o_irq_active == 1'b0) begin
            $display("[PASS] No IRQ pending: valid=%0b, active=%0b", o_irq_valid, o_irq_active);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Unexpected IRQ state: valid=%0b, active=%0b", o_irq_valid, o_irq_active);
        end

        //--- Test 2: Single IRQ — 12-Cycle Entry Latency ---
        $display("[TEST 2] Single IRQ — 12-Cycle Entry Latency");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_irq_pending = 11'b000_0000_0001;  // IRQ 0
        // Count cycles until irq_valid
        begin : latency_count
            integer cycle_count;
            cycle_count = 0;
            while (!o_irq_valid && cycle_count < 20) begin
                @(posedge i_clk);
                #1;
                cycle_count = cycle_count + 1;
            end
            if (o_irq_valid && cycle_count == 12) begin
                $display("[PASS] IRQ entry latency = %0d cycles (expected 12)", cycle_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] IRQ entry latency = %0d cycles (expected 12), valid=%0b",
                         cycle_count, o_irq_valid);
            end
        end
        // Acknowledge
        i_irq_ack = 1'b1;
        @(posedge i_clk); #1;
        i_irq_ack = 1'b0;
        i_irq_pending = {NUM_IRQ{1'b0}};
        repeat(3) @(posedge i_clk);

        //--- Test 3: Highest Priority IRQ Wins ---
        $display("[TEST 3] Highest Priority IRQ Wins (bit 10 > bit 0)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_irq_pending = 11'b100_0000_0001;  // IRQ 10 and IRQ 0
        repeat(13) @(posedge i_clk);
        if (o_irq_vector[10] == 1'b1) begin
            $display("[PASS] Highest priority IRQ (bit 10) selected");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Wrong IRQ selected: vector=0b%011b", o_irq_vector);
        end
        i_irq_ack = 1'b1;
        @(posedge i_clk); #1;
        i_irq_ack = 1'b0;
        i_irq_pending = {NUM_IRQ{1'b0}};
        repeat(3) @(posedge i_clk);

        //--- Test 4: Disabled IRQ Ignored ---
        $display("[TEST 4] Disabled IRQ Ignored");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_irq_enable = 11'b111_1111_1110;  // Disable IRQ 0
        i_irq_pending = 11'b000_0000_0001;  // Only IRQ 0 pending
        repeat(15) @(posedge i_clk);
        if (o_irq_valid == 1'b0 && o_irq_active == 1'b0) begin
            $display("[PASS] Disabled IRQ ignored");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Disabled IRQ triggered: valid=%0b, active=%0b", o_irq_valid, o_irq_active);
        end
        i_irq_enable = {NUM_IRQ{1'b1}};
        i_irq_pending = {NUM_IRQ{1'b0}};

        //--- Test 5: IRQ Active During Service ---
        $display("[TEST 5] IRQ Active During Service");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_irq_pending = 11'b000_0000_0100;  // IRQ 2
        repeat(13) @(posedge i_clk);
        if (o_irq_active == 1'b1) begin
            $display("[PASS] IRQ active during service");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] IRQ not active during service: active=%0b", o_irq_active);
        end
        // Acknowledge to complete
        i_irq_ack = 1'b1;
        @(posedge i_clk); #1;
        i_irq_ack = 1'b0;
        i_irq_pending = {NUM_IRQ{1'b0}};
        repeat(3) @(posedge i_clk);

        //--- Test 6: Vector Table Address ---
        $display("[TEST 6] Vector Table Address Calculation");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_irq_pending = 11'b000_0000_1000;  // IRQ 3
        repeat(13) @(posedge i_clk); #1;
        // Expected: VECTOR_TABLE_BASE + (IRQ# * 4) = 0x00000 + 3*4 = 0x0000_000C
        if (o_irq_pc_target == 32'h0000_000C) begin
            $display("[PASS] Vector table address correct: 0x%08h", o_irq_pc_target);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Vector table address incorrect: 0x%08h (expected 0x0000000C)", o_irq_pc_target);
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Interrupt Controller Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/rt_interrupt_controller.vcd");
        $dumpvars(0, rt_interrupt_controller_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
