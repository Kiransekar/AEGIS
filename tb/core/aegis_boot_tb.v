//===============================================================================
// Testbench: aegis_boot_tb — Phase 1 Boot Validation
// Gate: Log must contain "BOOT_OK" or "main_reached"
//===============================================================================

`timescale 1ns/1ps

module aegis_boot_tb;
    parameter CLK_PERIOD = 4.167;

    reg  i_clk = 0, i_rst_n = 0;
    reg  i_tcls_en = 0;
    wire o_tcls_fault;
    wire [31:0] o_axi_aw_addr, o_axi_w_data, o_axi_ar_addr;
    wire o_axi_aw_valid, o_axi_w_valid, o_axi_b_ready, o_axi_ar_valid, o_axi_r_ready;
    reg  [31:0] i_axi_r_data = 0; reg [1:0] i_axi_r_resp = 0; reg i_axi_r_valid = 0;
    reg  [1:0] i_axi_b_resp = 0; reg i_axi_b_valid = 0;
    reg  i_axi_aw_ready = 1, i_axi_w_ready = 1, i_axi_ar_ready = 1;
    reg  [10:0] i_irq_pending = 0;
    wire o_sleep_en, o_iso_en, o_retention_en, o_pwr_switch_n;
    wire [31:0] o_debug_pc; reg i_debug_halt = 0;

    // UART capture buffer
    reg  [7:0] uart_buf [0:511];
    integer    uart_idx;

    // Pattern match flags
    reg        found_main_reached;
    reg        found_boot_ok;

    initial begin
        uart_idx = 0;
        found_main_reached = 0;
        found_boot_ok = 0;
    end

    // Capture UART writes and scan for patterns
    // "main_reached" = 6D 61 69 6E 5F 72 65 61 63 68 65 64
    // "BOOT_OK"      = 42 4F 4F 54 5F 4F 4B
    always @(posedge i_clk) begin
        if (o_axi_w_valid && i_axi_w_ready && o_axi_aw_valid &&
            o_axi_aw_addr[31:16] == 16'h4000 && uart_idx < 511) begin
            uart_buf[uart_idx] = o_axi_w_data[7:0];
            uart_idx = uart_idx + 1;
        end

        // Check for "main_reached" (12 chars)
        if (uart_idx >= 12) begin
            if (uart_buf[uart_idx-12] == 8'h6D && uart_buf[uart_idx-11] == 8'h61 &&
                uart_buf[uart_idx-10] == 8'h69 && uart_buf[uart_idx-9]  == 8'h6E &&
                uart_buf[uart_idx-8]  == 8'h5F && uart_buf[uart_idx-7]  == 8'h72 &&
                uart_buf[uart_idx-6]  == 8'h65 && uart_buf[uart_idx-5]  == 8'h61 &&
                uart_buf[uart_idx-4]  == 8'h63 && uart_buf[uart_idx-3]  == 8'h68 &&
                uart_buf[uart_idx-2]  == 8'h65 && uart_buf[uart_idx-1]  == 8'h64)
                found_main_reached = 1;
        end

        // Check for "BOOT_OK" (7 chars)
        if (uart_idx >= 7) begin
            if (uart_buf[uart_idx-7] == 8'h42 && uart_buf[uart_idx-6] == 8'h4F &&
                uart_buf[uart_idx-5] == 8'h4F && uart_buf[uart_idx-4] == 8'h54 &&
                uart_buf[uart_idx-3] == 8'h5F && uart_buf[uart_idx-2] == 8'h4F &&
                uart_buf[uart_idx-1] == 8'h4B)
                found_boot_ok = 1;
        end
    end

    aegis_rt_top dut (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .i_tcls_en(i_tcls_en),
        .o_tcls_fault(o_tcls_fault),
        .o_axi_aw_addr(o_axi_aw_addr), .o_axi_aw_valid(o_axi_aw_valid), .i_axi_aw_ready(i_axi_aw_ready),
        .o_axi_w_data(o_axi_w_data), .o_axi_w_valid(o_axi_w_valid), .i_axi_w_ready(i_axi_w_ready),
        .i_axi_b_resp(i_axi_b_resp), .i_axi_b_valid(i_axi_b_valid), .o_axi_b_ready(o_axi_b_ready),
        .i_axi_r_data(i_axi_r_data), .i_axi_r_resp(i_axi_r_resp), .i_axi_r_valid(i_axi_r_valid),
        .o_axi_r_ready(o_axi_r_ready),
        .o_axi_ar_addr(o_axi_ar_addr), .o_axi_ar_valid(o_axi_ar_valid), .i_axi_ar_ready(i_axi_ar_ready),
        .i_irq_pending(i_irq_pending),
        .o_sleep_en(o_sleep_en), .o_iso_en(o_iso_en), .o_retention_en(o_retention_en), .o_pwr_switch_n(o_pwr_switch_n),
        .o_debug_pc(o_debug_pc), .i_debug_halt(i_debug_halt)
    );

    initial forever #(CLK_PERIOD/2) i_clk = ~i_clk;

    task apply_reset;
        input [31:0] n;
        begin
            i_rst_n = 0;
            repeat(n) @(posedge i_clk);
            i_rst_n = 1;
            @(posedge i_clk);
        end
    endtask

    integer pass_count, test_count;

    initial begin
        pass_count = 0;
        test_count = 0;

        $display("===============================================================================");
        $display("AEGIS-RV Phase 1: Boot Validation");
        $display("===============================================================================");

        // Test 1: Reset vector
        test_count = test_count + 1;
        $display("[BOOT 1] Reset Vector");
        apply_reset(20); #1;
        if (o_debug_pc <= 32'd4) begin
            $display("[PASS] PC=0x%08h", o_debug_pc);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] PC=0x%08h", o_debug_pc);
        end

        // Test 2: PC advancement
        test_count = test_count + 1;
        $display("[BOOT 2] PC Advancement");
        begin
            reg [31:0] pc0;
            integer moved;
            pc0 = o_debug_pc;
            moved = 0;
            repeat(50) @(posedge i_clk); #1;
            if (o_debug_pc != pc0) moved = 1;
            if (moved) begin
                $display("[PASS] 0x%08h -> 0x%08h", pc0, o_debug_pc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] PC stuck at 0x%08h", pc0);
            end
        end

        // Test 3: Run firmware
        test_count = test_count + 1;
        $display("[BOOT 3] Running firmware (5000 cycles)...");
        repeat(5000) @(posedge i_clk); #1;

        // Test 4: Check for BOOT_OK / main_reached
        test_count = test_count + 1;
        $display("[BOOT 4] UART Output Check");
        if (found_boot_ok || found_main_reached) begin
            $display("[PASS] BOOT_OK=%0b main_reached=%0b", found_boot_ok, found_main_reached);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] No BOOT_OK or main_reached in UART output");
            $display("[INFO] UART captured %0d chars", uart_idx);
        end

        // Test 5: No hang
        test_count = test_count + 1;
        $display("[BOOT 5] No Hang Check");
        if (o_debug_pc != 32'd0) begin
            $display("[PASS] PC=0x%08h (not stuck at 0)", o_debug_pc);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] PC stuck at 0x00000000");
        end

        // Summary
        $display("");
        $display("===============================================================================");
        $display("Boot Test Summary: %0d/%0d passed", pass_count, test_count);
        if (pass_count == test_count)
            $display("[OK] All tests passed");
        else
            $display("[FAIL] Some tests failed");
        $display("===============================================================================");

        // Phase 1 Gate
        if (found_boot_ok || found_main_reached)
            $display("PASS: Phase 1");
        else
            $display("FAIL: Phase 1");

        $finish;
    end

    // Timeout watchdog
    initial begin
        repeat(200000) @(posedge i_clk);
        $display("[FATAL] Simulation timeout");
        $finish;
    end

    `ifdef TRACE
    initial begin
        $dumpfile("sim/boot.vcd");
        $dumpvars(0, aegis_boot_tb);
    end
    `endif
endmodule
