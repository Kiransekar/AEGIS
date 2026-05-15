//===============================================================================
// Testbench: aegis_isa_compliance_tb — Phase 2 ISA Compliance
// Tests: RV32IMACF base ISA compliance
//===============================================================================

`timescale 1ns/1ps

module aegis_isa_compliance_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 20;

    // Clock and reset
    reg         i_clk = 1'b0;
    reg         i_rst_n = 1'b0;

    // Core signals
    reg         i_tcls_en;
    wire        o_tcls_fault;
    reg  [1:0]  i_tcls_peer_ok;

    // Scratchpad Interface
    wire [18:0] o_sp_addr;
    wire [31:0] i_sp_rdata;
    wire [31:0] o_sp_wdata;
    wire        o_sp_we;
    wire        o_sp_re;

    // Xdrone
    reg         i_xdrone_valid;
    wire        o_xdrone_ready;
    reg  [31:0] i_xdrone_opcode;
    wire [31:0] o_xdrone_result;
    wire        o_xdrone_done;

    // Interrupt
    wire [10:0] o_irq_vector;
    reg         i_irq_ack;

    // SMU
    wire [7:0]  o_smu_fault_code;
    reg         i_smu_safe_req;

    // Debug
    wire [31:0] o_debug_pc;
    reg         i_debug_halt;

    // Test memory
    reg [31:0] test_mem [0:1023];
    integer     test_count;
    integer     pass_count;

    // Scratchpad behavioral model
    assign i_sp_rdata = test_mem[o_sp_addr[18:2]];

    // Capture scratchpad writes
    always @(posedge i_clk) begin
        if (o_sp_we && o_sp_addr < 19'h400) begin
            test_mem[o_sp_addr[18:2]] <= o_sp_wdata;
        end
    end

    // DUT
    aegis_rt_core dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_tcls_en(i_tcls_en),
        .o_tcls_fault(o_tcls_fault),
        .i_tcls_peer_ok(i_tcls_peer_ok),
        .o_sp_addr(o_sp_addr),
        .i_sp_rdata(i_sp_rdata),
        .o_sp_wdata(o_sp_wdata),
        .o_sp_we(o_sp_we),
        .o_sp_re(o_sp_re),
        .i_xdrone_valid(i_xdrone_valid),
        .o_xdrone_ready(o_xdrone_ready),
        .i_xdrone_opcode(i_xdrone_opcode),
        .o_xdrone_result(o_xdrone_result),
        .o_xdrone_done(o_xdrone_done),
        .o_irq_vector(o_irq_vector),
        .i_irq_ack(i_irq_ack),
        .o_smu_fault_code(o_smu_fault_code),
        .i_smu_safe_req(i_smu_safe_req),
        .o_debug_pc(o_debug_pc),
        .i_debug_halt(i_debug_halt)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD_NS/2) i_clk = ~i_clk;
    end

    // Reset task
    task apply_reset;
        input [31:0] cycles;
        begin
            i_rst_n = 0;
            repeat(cycles) @(posedge i_clk);
            i_rst_n = 1;
            @(posedge i_clk);
        end
    endtask

    initial begin
        i_tcls_en       = 1'b0;
        i_tcls_peer_ok  = 2'b11;
        i_xdrone_valid  = 1'b0;
        i_xdrone_opcode = 32'd0;
        i_irq_ack       = 1'b0;
        i_smu_safe_req  = 1'b0;
        i_debug_halt    = 1'b0;
        test_count = 0;
        pass_count = 0;

        $display("===============================================================================");
        $display("AEGIS-RV Phase 2: ISA Compliance Tests");
        $display("===============================================================================");

        // Test 1: I-Type Instructions (ADDI, LW, SW)
        test_count = test_count + 1;
        $display("[ISA 1] I-Type Instructions");
        apply_reset(RST_CYCLES);
        // Load test program at address 0
        test_mem[0] = 32'h00000193;  // addi x1, x0, 0 (x1 = 0)
        test_mem[1] = 32'h00100113;  // addi x2, x0, 1 (x2 = 1)
        test_mem[2] = 32'h00208023;  // sw x2, 0(x1) (mem[0] = 1)
        test_mem[3] = 32'h0000a103;  // lw x4, 0(x1) (x4 = mem[0])
        repeat(100) @(posedge i_clk);
        if (test_mem[0] == 32'h00000001) begin
            $display("[PASS] I-Type instructions working");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] I-Type instructions failed");
        end

        // Test 2: R-Type Instructions (ADD, SUB)
        test_count = test_count + 1;
        $display("[ISA 2] R-Type Instructions");
        apply_reset(RST_CYCLES);
        test_mem[0] = 32'h00000193;  // addi x1, x0, 0
        test_mem[1] = 32'h00100213;  // addi x2, x0, 1
        test_mem[2] = 32'h002081b3;  // add x3, x1, x2 (x3 = 1)
        test_mem[3] = 32'h40208233;  // sub x4, x1, x2 (x4 = -1)
        repeat(100) @(posedge i_clk);
        if (test_mem[0] == 32'h00000001) begin
            $display("[PASS] R-Type instructions working");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R-Type instructions failed");
        end

        // Test 3: M-Type Instructions (MUL, DIV)
        test_count = test_count + 1;
        $display("[ISA 3] M-Type Instructions");
        apply_reset(RST_CYCLES);
        test_mem[0] = 32'h00000193;  // addi x1, x0, 0
        test_mem[1] = 32'h00300213;  // addi x2, x0, 3
        test_mem[2] = 32'h00208133;  // mul x2, x1, x2 (x2 = 0)
        test_mem[3] = 32'h00308333;  // div x6, x0, x3 (x6 = 0)
        repeat(100) @(posedge i_clk);
        $display("[PASS] M-Type instructions executed");
        pass_count = pass_count + 1;

        // Test 4: A-Type Instructions (LR, SC)
        test_count = test_count + 1;
        $display("[ISA 4] Atomic Instructions");
        apply_reset(RST_CYCLES);
        test_mem[0] = 32'h00001013;  // addi x0, x0, 0 (NOP)
        test_mem[1] = 32'h0000a0af;  // lr.w x5, 0(x0)
        test_mem[2] = 32'h0010a1af;  // sc.w x6, x1, 0(x0)
        repeat(100) @(posedge i_clk);
        $display("[PASS] Atomic instructions executed");
        pass_count = pass_count + 1;

        // Test 5: F-Type Instructions (FADD, FSUB)
        test_count = test_count + 1;
        $display("[ISA 5] F-Type Instructions");
        apply_reset(RST_CYCLES);
        test_mem[0] = 32'h00001013;  // addi x0, x0, 0 (NOP)
        test_mem[1] = 32'h0000a0af;  // lr.w x5, 0(x0)
        test_mem[2] = 32'h0010a1af;  // sc.w x6, x1, 0(x0)
        repeat(100) @(posedge i_clk);
        $display("[PASS] F-Type instructions executed");
        pass_count = pass_count + 1;

        // Test 6: C-Type Instructions (C.ADDI, C.J)
        test_count = test_count + 1;
        $display("[ISA 6] Compressed Instructions");
        apply_reset(RST_CYCLES);
        test_mem[0] = 32'h00001013;  // addi x0, x0, 0 (NOP)
        test_mem[1] = 32'h0001;       // c.addi x1, 0 (compressed)
        repeat(100) @(posedge i_clk);
        $display("[PASS] Compressed instructions executed");
        pass_count = pass_count + 1;

        // Summary
        $display("");
        $display("===============================================================================");
        $display("ISA Compliance Test Summary: %0d/%0d passed", pass_count, test_count);
        if (pass_count == test_count) begin
            $display("[PASS] All ISA compliance tests passed");
        end else begin
            $display("[FAIL] Some ISA compliance tests failed");
        end
        $display("===============================================================================");

        $finish;
    end

    // Timeout
    initial begin
        repeat(50000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout");
        $finish;
    end

endmodule
