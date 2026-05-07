//===============================================================================
// Testbench: rt_pipeline_tb
// Module Under Test: rt_pipeline_controller (hazard + forwarding integration)
//===============================================================================

`timescale 1ns/1ps

module rt_pipeline_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 10;

    reg         i_clk, i_rst_n;

    // Decode stage
    reg  [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    reg         id_reg_we, id_mem_re, id_mem_we;

    // Execute stage
    reg  [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    reg         ex_reg_we, ex_mem_re, ex_mem_we;
    reg         ex_fpu_req, ex_muldiv_req, ex_muldiv_busy;
    reg         ex_xdrone_valid, ex_xdrone_done;

    // Writeback stage
    reg  [4:0]  wb_rd_addr;
    reg         wb_reg_we;

    // Outputs
    wire        o_stall_fetch, o_stall_decode, o_flush_decode, o_flush_execute;
    wire [1:0]  o_fwd_rs1_sel, o_fwd_rs2_sel;

    rt_pipeline_controller dut (.*);

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

        //--- Initialize all inputs ---
        id_rs1_addr = 5'd0; id_rs2_addr = 5'd0; id_rd_addr = 5'd0;
        id_reg_we = 0; id_mem_re = 0; id_mem_we = 0;
        ex_rs1_addr = 5'd0; ex_rs2_addr = 5'd0; ex_rd_addr = 5'd0;
        ex_reg_we = 0; ex_mem_re = 0; ex_mem_we = 0;
        ex_fpu_req = 0; ex_muldiv_req = 0; ex_muldiv_busy = 0;
        ex_xdrone_valid = 0; ex_xdrone_done = 0;
        wb_rd_addr = 5'd0; wb_reg_we = 0;

        //--- Test 1: No hazard → no stall, no forward ---
        $display("[PIPE 1] No hazard — no stall, no forward");
        test_count = test_count + 1;
        apply_reset;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd2;
        ex_rd_addr = 5'd3; ex_reg_we = 1;
        wb_rd_addr = 5'd4; wb_reg_we = 1;
        @(posedge i_clk);
        if (!o_stall_fetch && !o_stall_decode && o_fwd_rs1_sel == 2'd0 && o_fwd_rs2_sel == 2'd0) begin
            $display("[PASS] No hazard: stall=%b, fwd_rs1=%0d, fwd_rs2=%0d",
                     o_stall_decode, o_fwd_rs1_sel, o_fwd_rs2_sel);
            pass_count = pass_count + 1;
        end else $display("[FAIL] No hazard: stall=%b, fwd_rs1=%0d, fwd_rs2=%0d",
                          o_stall_decode, o_fwd_rs1_sel, o_fwd_rs2_sel);

        //--- Test 2: EX RAW hazard on rs1 → forward from EX ---
        $display("[PIPE 2] EX RAW hazard on rs1 — forward");
        test_count = test_count + 1;
        apply_reset;
        id_rs1_addr = 5'd5; id_rs2_addr = 5'd2;
        ex_rd_addr = 5'd5; ex_reg_we = 1; ex_mem_re = 0;
        wb_rd_addr = 5'd0; wb_reg_we = 0;
        @(posedge i_clk);
        if (o_fwd_rs1_sel == 2'd2 && !o_stall_decode) begin
            $display("[PASS] EX RAW rs1: fwd_rs1=%0d (expected 2)", o_fwd_rs1_sel);
            pass_count = pass_count + 1;
        end else $display("[FAIL] EX RAW rs1: fwd_rs1=%0d, stall=%b", o_fwd_rs1_sel, o_stall_decode);

        //--- Test 3: Load-use hazard → stall ---
        $display("[PIPE 3] Load-use hazard — stall");
        test_count = test_count + 1;
        apply_reset;
        id_rs1_addr = 5'd5; id_rs2_addr = 5'd2;
        ex_rd_addr = 5'd5; ex_reg_we = 1; ex_mem_re = 1;  // Load in EX
        wb_rd_addr = 5'd0; wb_reg_we = 0;
        @(posedge i_clk);
        if (o_stall_fetch && o_stall_decode) begin
            $display("[PASS] Load-use: stall_fetch=%b, stall_decode=%b", o_stall_fetch, o_stall_decode);
            pass_count = pass_count + 1;
        end else $display("[FAIL] Load-use: stall_fetch=%b, stall_decode=%b", o_stall_fetch, o_stall_decode);

        //--- Test 4: WB RAW hazard on rs2 → forward from WB ---
        $display("[PIPE 4] WB RAW hazard on rs2 — forward");
        test_count = test_count + 1;
        apply_reset;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd6;
        ex_rd_addr = 5'd0; ex_reg_we = 0;
        wb_rd_addr = 5'd6; wb_reg_we = 1;
        @(posedge i_clk);
        if (o_fwd_rs2_sel == 2'd3 && !o_stall_decode) begin
            $display("[PASS] WB RAW rs2: fwd_rs2=%0d (expected 3)", o_fwd_rs2_sel);
            pass_count = pass_count + 1;
        end else $display("[FAIL] WB RAW rs2: fwd_rs2=%0d, stall=%b", o_fwd_rs2_sel, o_stall_decode);

        //--- Test 5: MULDIV busy → structural stall ---
        $display("[PIPE 5] MULDIV busy — structural stall");
        test_count = test_count + 1;
        apply_reset;
        ex_muldiv_busy = 1;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd2;
        ex_rd_addr = 5'd0; ex_reg_we = 0;
        wb_rd_addr = 5'd0; wb_reg_we = 0;
        @(posedge i_clk);
        if (o_stall_fetch && o_stall_decode) begin
            $display("[PASS] MULDIV busy: stall asserted");
            pass_count = pass_count + 1;
        end else $display("[FAIL] MULDIV busy: stall_fetch=%b, stall_decode=%b", o_stall_fetch, o_stall_decode);

        //--- Test 6: x0 hardwired — no hazard on register 0 ---
        $display("[PIPE 6] x0 hardwired — no hazard");
        test_count = test_count + 1;
        apply_reset;
        ex_muldiv_busy = 0;  // Clear structural hazard from previous test
        id_rs1_addr = 5'd0;  // Reading x0
        ex_rd_addr = 5'd0; ex_reg_we = 1;  // Writing x0 (should be ignored)
        wb_rd_addr = 5'd0; wb_reg_we = 0;
        @(posedge i_clk);
        if (o_fwd_rs1_sel == 2'd0 && !o_stall_decode) begin
            $display("[PASS] x0 no hazard: fwd_rs1=%0d", o_fwd_rs1_sel);
            pass_count = pass_count + 1;
        end else $display("[FAIL] x0 no hazard: fwd_rs1=%0d, stall=%b", o_fwd_rs1_sel, o_stall_decode);

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Pipeline Controller Test Summary: %0d/%0d passed", pass_count, test_count);
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
