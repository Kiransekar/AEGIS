//===============================================================================
// Testbench: rt_exception_handler_tb
// Module Under Test: rt_exception_handler (ECALL/EBREAK/MRET/Illegal)
//===============================================================================

`timescale 1ns/1ps

module rt_exception_handler_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk, i_rst_n;
    reg         i_ecall, i_ebreak, i_mret, i_illegal;
    reg  [31:0] i_current_pc;

    wire        o_trap_valid;
    wire [31:0] o_trap_pc, o_trap_mepc, o_mret_pc;
    wire [3:0]  o_trap_cause;
    wire        o_mret_valid, o_shadow_swap_req;

    rt_exception_handler dut (.*);

    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    task automatic apply_reset;
        begin
            i_rst_n = 0; repeat(RST_CYCLES) @(posedge i_clk);
            i_rst_n = 1; @(posedge i_clk);
        end
    endtask

    integer test_count, pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;
        i_ecall = 0; i_ebreak = 0; i_mret = 0; i_illegal = 0;
        i_current_pc = 32'h00000100;

        //--- Test 1: ECALL triggers trap ---
        $display("[EXC 1] ECALL triggers trap");
        test_count = test_count + 1;
        apply_reset;
        i_ecall = 1;
        @(posedge i_clk);
        if (o_trap_valid && o_trap_cause == 4'd8 && o_shadow_swap_req) begin
            $display("[PASS] ECALL: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
            pass_count = pass_count + 1;
        end else $display("[FAIL] ECALL: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
        i_ecall = 0;

        //--- Test 2: EBREAK triggers trap ---
        $display("[EXC 2] EBREAK triggers trap");
        test_count = test_count + 1;
        apply_reset;
        i_ebreak = 1;
        @(posedge i_clk);
        if (o_trap_valid && o_trap_cause == 4'd3 && o_shadow_swap_req) begin
            $display("[PASS] EBREAK: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
            pass_count = pass_count + 1;
        end else $display("[FAIL] EBREAK: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
        i_ebreak = 0;

        //--- Test 3: Illegal instruction triggers trap ---
        $display("[EXC 3] Illegal instruction triggers trap");
        test_count = test_count + 1;
        apply_reset;
        i_illegal = 1;
        @(posedge i_clk);
        if (o_trap_valid && o_trap_cause == 4'd2 && !o_shadow_swap_req) begin
            $display("[PASS] Illegal: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Illegal: trap=%b, cause=%0d, shadow=%b", o_trap_valid, o_trap_cause, o_shadow_swap_req);
        i_illegal = 0;

        //--- Test 4: MRET returns (no trap) ---
        $display("[EXC 4] MRET returns — no trap");
        test_count = test_count + 1;
        apply_reset;
        i_mret = 1;
        @(posedge i_clk);
        if (o_mret_valid && !o_trap_valid && !o_shadow_swap_req) begin
            $display("[PASS] MRET: mret=%b, trap=%b, shadow=%b", o_mret_valid, o_trap_valid, o_shadow_swap_req);
            pass_count = pass_count + 1;
        end else $display("[FAIL] MRET: mret=%b, trap=%b, shadow=%b", o_mret_valid, o_trap_valid, o_shadow_swap_req);
        i_mret = 0;

        //--- Test 5: No exception — no trap, no MRET ---
        $display("[EXC 5] No exception — idle");
        test_count = test_count + 1;
        apply_reset;
        @(posedge i_clk);
        if (!o_trap_valid && !o_mret_valid) begin
            $display("[PASS] Idle: trap=%b, mret=%b", o_trap_valid, o_mret_valid);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Idle: trap=%b, mret=%b", o_trap_valid, o_mret_valid);

        //--- Test 6: Trap PC is correct vector ---
        $display("[EXC 6] Trap PC = machine-mode vector");
        test_count = test_count + 1;
        apply_reset;
        i_ecall = 1;
        @(posedge i_clk);
        if (o_trap_pc == 32'h00000200) begin
            $display("[PASS] Trap PC: 0x%08h", o_trap_pc);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Trap PC: 0x%08h (expected 0x00000200)", o_trap_pc);
        i_ecall = 0;

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Exception Handler Test Summary: %0d/%0d passed", pass_count, test_count);
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
