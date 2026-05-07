//===============================================================================
// Testbench: tcls_voter_tb
// Module Under Test: tcls_voter
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module tcls_voter_tb;
    parameter CLK_PERIOD_NS = 4.167;  // 240 MHz
    parameter RST_CYCLES    = 10;

    // Signals
    reg         i_clk;
    reg         i_rst_n;
    reg  [31:0] i_core_a_out;
    reg  [31:0] i_core_b_out;
    reg  [31:0] i_core_c_out;
    reg         i_core_a_valid;
    reg         i_core_b_valid;
    reg         i_core_c_valid;
    wire [31:0] o_voter_output;
    wire        o_voter_valid;
    wire        o_mismatch;
    wire [1:0]  o_mismatch_cnt;
    wire        o_quarantine_req;
    reg         i_quarantine_ack;
    reg         i_spare_core_en;
    wire        o_spare_core_active;

    // DUT
    tcls_voter dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_core_a_out(i_core_a_out),
        .i_core_b_out(i_core_b_out),
        .i_core_c_out(i_core_c_out),
        .i_core_a_valid(i_core_a_valid),
        .i_core_b_valid(i_core_b_valid),
        .i_core_c_valid(i_core_c_valid),
        .o_voter_output(o_voter_output),
        .o_voter_valid(o_voter_valid),
        .o_mismatch(o_mismatch),
        .o_mismatch_cnt(o_mismatch_cnt),
        .o_quarantine_req(o_quarantine_req),
        .i_quarantine_ack(i_quarantine_ack),
        .i_spare_core_en(i_spare_core_en),
        .o_spare_core_active(o_spare_core_active)
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
        i_core_a_out   = 32'h0000_0001;
        i_core_b_out   = 32'h0000_0001;
        i_core_c_out   = 32'h0000_0001;
        i_core_a_valid = 1'b1;
        i_core_b_valid = 1'b1;
        i_core_c_valid = 1'b1;
        i_quarantine_ack = 1'b0;
        i_spare_core_en  = 1'b0;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: All Cores Agree — No Mismatch ---
        $display("[TEST 1] All Cores Agree — No Mismatch");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_core_a_out = 32'hDEAD_BEEF;
        i_core_b_out = 32'hDEAD_BEEF;
        i_core_c_out = 32'hDEAD_BEEF;
        repeat(3) @(posedge i_clk);
        if (o_voter_output == 32'hDEAD_BEEF && o_mismatch == 1'b0 && o_mismatch_cnt == 2'd0) begin
            $display("[PASS] All cores agree: voter_output=0x%08h, mismatch=%0b, cnt=%0d",
                     o_voter_output, o_mismatch, o_mismatch_cnt);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] All cores agree: voter_output=0x%08h, mismatch=%0b, cnt=%0d",
                     o_voter_output, o_mismatch, o_mismatch_cnt);
        end

        //--- Test 2: Single Core Fault (A disagrees) — 2oo3 Voting ---
        $display("[TEST 2] Single Core Fault (A disagrees) — 2oo3 Voting");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_core_a_out = 32'h0000_0000;  // Faulty
        i_core_b_out = 32'hCAFE_F00D;  // Correct
        i_core_c_out = 32'hCAFE_F00D;  // Correct
        repeat(3) @(posedge i_clk);
        if (o_voter_output == 32'hCAFE_F00D && o_mismatch == 1'b1) begin
            $display("[PASS] 2oo3 voting correct: output=0x%08h (B=C majority)", o_voter_output);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 2oo3 voting incorrect: output=0x%08h, mismatch=%0b", o_voter_output, o_mismatch);
        end

        //--- Test 3: Single Core Fault (B disagrees) — A=C majority ---
        $display("[TEST 3] Single Core Fault (B disagrees) — A=C majority");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        i_core_a_out = 32'h1234_5678;  // Correct
        i_core_b_out = 32'hFFFF_FFFF;  // Faulty
        i_core_c_out = 32'h1234_5678;  // Correct
        repeat(3) @(posedge i_clk);
        if (o_voter_output == 32'h1234_5678) begin
            $display("[PASS] A=C majority voting correct");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] A=C majority voting incorrect: output=0x%08h", o_voter_output);
        end

        //--- Test 4: Mismatch Counter Accumulation ---
        $display("[TEST 4] Mismatch Counter Accumulation (3 consecutive mismatches)");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Inject 3 consecutive mismatches
        i_core_a_out = 32'h0000_0001;
        i_core_b_out = 32'h0000_0002;
        i_core_c_out = 32'h0000_0001;
        repeat(3) @(posedge i_clk);
        // Check counter reached threshold
        if (o_mismatch_cnt >= 2'd3) begin
            $display("[PASS] Mismatch counter reached threshold: cnt=%0d", o_mismatch_cnt);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Mismatch counter: cnt=%0d (expected >=3)", o_mismatch_cnt);
        end

        //--- Test 5: Quarantine After Threshold ---
        $display("[TEST 5] Quarantine After Mismatch Threshold");
        test_count = test_count + 1;
        // Continue from Test 4 — wait for quarantine
        repeat(6) @(posedge i_clk);
        if (o_quarantine_req == 1'b1) begin
            $display("[PASS] Quarantine requested after threshold");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Quarantine not requested: quarantine_req=%0b", o_quarantine_req);
        end

        //--- Test 6: Counter Resets on Match ---
        $display("[TEST 6] Mismatch Counter Resets on Match");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Inject 1 mismatch
        i_core_a_out = 32'hAAAA_5555;
        i_core_b_out = 32'hAAAA_5556;  // 1-bit diff
        i_core_c_out = 32'hAAAA_5555;
        @(posedge i_clk); #1;
        // Now match
        i_core_b_out = 32'hAAAA_5555;
        @(posedge i_clk); #1;
        if (o_mismatch_cnt == 2'd0) begin
            $display("[PASS] Counter reset on match");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Counter not reset: cnt=%0d", o_mismatch_cnt);
        end

        //--- Test 7: Hot-Spare Promotion ---
        $display("[TEST 7] Hot-Spare Promotion After Quarantine Acknowledge");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        // Force quarantine
        i_core_a_out = 32'h0000_0001;
        i_core_b_out = 32'h0000_0002;
        i_core_c_out = 32'h0000_0003;
        repeat(10) @(posedge i_clk); #1;
        if (o_quarantine_req) begin
            i_spare_core_en = 1'b1;
            i_quarantine_ack = 1'b1;
            repeat(12) @(posedge i_clk); #1;
            i_quarantine_ack = 1'b0;
            if (o_spare_core_active == 1'b1) begin
                $display("[PASS] Spare core promoted");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Spare core not promoted: spare_active=%0b", o_spare_core_active);
            end
        end else begin
            $display("[FAIL] Quarantine not reached for spare test");
        end
        i_spare_core_en = 1'b0;

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("TCLS Voter Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/tcls_voter.vcd");
        $dumpvars(0, tcls_voter_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
