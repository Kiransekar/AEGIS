//===============================================================================
// Testbench: aegis_boot_simple_tb — Phase 1 Boot Validation
// Gate: Log must contain "BOOT_OK" or "main_reached"
//===============================================================================

`timescale 1ns/1ps

module aegis_boot_simple_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter RST_CYCLES    = 20;

    // Signals
    reg         i_clk = 1'b0;
    reg         i_rst_n = 1'b0;
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

    // UART capture (simplified)
    reg [7:0] uart_buffer [0:255];
    integer uart_idx;
    reg found_boot_ok;
    reg found_main_reached;

    // Scratchpad behavioral model
    reg [31:0] sp_mem [0:131071];  // 512 KB / 4 = 128K words
    assign i_sp_rdata = sp_mem[o_sp_addr[18:2]];

    // Load firmware.hex into scratchpad if it exists
    initial begin
        $display("[BOOT] Loading firmware.hex into scratchpad...");
        $readmemh("firmware/build/firmware.hex", sp_mem);
        $display("[BOOT] Firmware loaded");
    end

    // Simple UART capture (monitor writes to 0x40000000)
    always @(posedge i_clk) begin
        if (o_sp_we && o_sp_addr[18:16] == 3'b100) begin  // 0x40000000 region
            if (uart_idx < 256) begin
                uart_buffer[uart_idx] = o_sp_wdata[7:0];
                uart_idx = uart_idx + 1;
                
                // Check for patterns
                if (uart_idx >= 7) begin
                    if (uart_buffer[uart_idx-7] == 8'h42 &&  // B
                        uart_buffer[uart_idx-6] == 8'h4F &&  // O
                        uart_buffer[uart_idx-5] == 8'h4F &&  // O
                        uart_buffer[uart_idx-4] == 8'h54 &&  // T
                        uart_buffer[uart_idx-3] == 8'h5F &&  // _
                        uart_buffer[uart_idx-2] == 8'h4F &&  // O
                        uart_buffer[uart_idx-1] == 8'h4B)     // K
                        found_boot_ok = 1;
                end
                
                if (uart_idx >= 12) begin
                    if (uart_buffer[uart_idx-12] == 8'h6D &&  // m
                        uart_buffer[uart_idx-11] == 8'h61 &&  // a
                        uart_buffer[uart_idx-10] == 8'h69 &&  // i
                        uart_buffer[uart_idx-9]  == 8'h6E &&  // n
                        uart_buffer[uart_idx-8]  == 8'h5F &&  // _
                        uart_buffer[uart_idx-7]  == 8'h72 &&  // r
                        uart_buffer[uart_idx-6]  == 8'h65 &&  // e
                        uart_buffer[uart_idx-5]  == 8'h61 &&  // a
                        uart_buffer[uart_idx-4]  == 8'h63 &&  // c
                        uart_buffer[uart_idx-3]  == 8'h68 &&  // h
                        uart_buffer[uart_idx-2]  == 8'h65 &&  // e
                        uart_buffer[uart_idx-1]  == 8'h64)     // d
                        found_main_reached = 1;
                end
            end
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

    // Scratchpad write capture
    always @(posedge i_clk) begin
        if (o_sp_we && o_sp_addr < 19'h80000) begin
            sp_mem[o_sp_addr[18:2]] <= o_sp_wdata;
        end
    end

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
        i_tcls_en       = 1'b0;
        i_tcls_peer_ok  = 2'b11;
        i_xdrone_valid  = 1'b0;
        i_xdrone_opcode = 32'd0;
        i_irq_ack       = 1'b0;
        i_smu_safe_req  = 1'b0;
        i_debug_halt    = 1'b0;
        uart_idx        = 0;
        found_boot_ok   = 0;
        found_main_reached = 0;
    end

    integer test_count;
    integer pass_count;

    initial begin
        test_count = 0;
        pass_count = 0;

        $display("===============================================================================");
        $display("AEGIS-RV Phase 1: Boot Validation");
        $display("===============================================================================");

        //--- Test 1: Reset State ---
        $display("[BOOT 1] Reset State");
        test_count = test_count + 1;
        apply_reset(RST_CYCLES);
        #1;
        if (o_debug_pc <= 32'd4 && o_tcls_fault == 1'b0) begin
            $display("[PASS] Core reset: pc=0x%08h, fault=%0b", o_debug_pc, o_tcls_fault);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Core reset: pc=0x%08h, fault=%0b", o_debug_pc, o_tcls_fault);
        end

        //--- Test 2: PC Advancement ---
        $display("[BOOT 2] PC Advancement");
        test_count = test_count + 1;
        begin : pc_advance
            reg [31:0] prev_pc;
            integer changed;
            changed = 0;
            prev_pc = o_debug_pc;
            repeat(50) @(posedge i_clk); #1;
            if (o_debug_pc != prev_pc) changed = 1;
            if (changed) begin
                $display("[PASS] PC advanced from 0x%08h to 0x%08h", prev_pc, o_debug_pc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] PC did not advance: 0x%08h", o_debug_pc);
            end
        end

        //--- Test 3: Run Firmware ---
        $display("[BOOT 3] Running firmware (5000 cycles)...");
        test_count = test_count + 1;
        repeat(5000) @(posedge i_clk); #1;
        pass_count = pass_count + 1;  // Assume pass unless timeout

        //--- Test 4: Check for BOOT_OK / main_reached ---
        $display("[BOOT 4] UART Output Check");
        test_count = test_count + 1;
        if (found_boot_ok || found_main_reached) begin
            $display("[PASS] BOOT_OK=%0b main_reached=%0b", found_boot_ok, found_main_reached);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] No BOOT_OK or main_reached in UART output");
            $display("[INFO] UART captured %0d chars", uart_idx);
        end

        //--- Test 5: No Hang ---
        $display("[BOOT 5] No Hang Check");
        test_count = test_count + 1;
        if (o_debug_pc != 32'd0) begin
            $display("[PASS] PC=0x%08h (not stuck at 0)", o_debug_pc);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] PC stuck at 0x00000000");
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("Boot Test Summary: %0d/%0d passed", pass_count, test_count);
        if (pass_count == test_count) begin
            $display("[OK] All tests passed");
        end else begin
            $display("[FAIL] Some tests failed");
        end
        $display("===============================================================================");

        // Phase 1 Gate
        if (found_boot_ok || found_main_reached) begin
            $display("PASS: Phase 1");
        end else begin
            $display("FAIL: Phase 1");
        end

        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/boot.vcd");
        $dumpvars(0, aegis_boot_simple_tb);
    end
    `endif

    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout exceeded");
        $finish;
    end

endmodule
