//===============================================================================
// Testbench: ecc_secdec_32_tb
// Module Under Test: ecc_secdec_32
// Coverage Targets: 100% line, >90% branch, 100% safety-critical path
//===============================================================================

`timescale 1ns/1ps

module ecc_secdec_32_tb;
    parameter CLK_PERIOD_NS = 4.167;
    parameter DATA_WIDTH = 32;
    parameter CHECK_BITS = 7;
    parameter TOTAL_WIDTH = 39;

    // Signals
    reg  [DATA_WIDTH-1:0]  i_enc_data;
    wire [TOTAL_WIDTH-1:0] o_enc_word;
    reg  [TOTAL_WIDTH-1:0] i_dec_word;
    wire [DATA_WIDTH-1:0]  o_dec_data;
    wire                  o_single_error;
    wire                  o_double_error;
    wire [CHECK_BITS-1:0] o_error_syndrome;

    // DUT
    ecc_secdec_32 dut (
        .i_enc_data(i_enc_data),
        .o_enc_word(o_enc_word),
        .i_dec_word(i_dec_word),
        .o_dec_data(o_dec_data),
        .o_single_error(o_single_error),
        .o_double_error(o_double_error),
        .o_error_syndrome(o_error_syndrome)
    );

    integer test_count;
    integer pass_count;

    // Test data patterns
    reg [DATA_WIDTH-1:0] test_data;
    reg [TOTAL_WIDTH-1:0] corrupted_word;
    integer bit_pos;

    initial begin
        test_count = 0;
        pass_count = 0;

        //--- Test 1: No Error ---
        $display("[TEST 1] No Error — Data passes through unchanged");
        test_count = test_count + 1;
        test_data = 32'hDEAD_BEEF;
        i_enc_data = test_data;
        #10;
        i_dec_word = o_enc_word;  // No corruption
        #10;
        if (o_dec_data == test_data && o_single_error == 1'b0 && o_double_error == 1'b0) begin
            $display("[PASS] No-error case: data=0x%08h, decoded=0x%08h", test_data, o_dec_data);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] No-error case: expected=0x%08h, got=0x%08h, se=%0b, de=%0b",
                     test_data, o_dec_data, o_single_error, o_double_error);
        end

        //--- Test 2: Single-Bit Error in Each Data Bit ---
        $display("[TEST 2] Single-Bit Error Correction (all 32 data bits)");
        test_count = test_count + 1;
        begin : single_bit_test
            integer single_pass;
            single_pass = 1;
            test_data = 32'h1234_5678;
            i_enc_data = test_data;
            #10;
            for (bit_pos = 0; bit_pos < DATA_WIDTH; bit_pos = bit_pos + 1) begin
                // Corrupt one data bit
                corrupted_word = o_enc_word ^ (39'd1 << (bit_pos + CHECK_BITS));
                i_dec_word = corrupted_word;
                #10;
                if (o_dec_data != test_data || o_single_error != 1'b1 || o_double_error != 1'b0) begin
                    $display("[FAIL] Single-bit correction failed at bit %0d: expected=0x%08h, got=0x%08h, se=%0b, de=%0b, synd=0x%02h",
                             bit_pos, test_data, o_dec_data, o_single_error, o_double_error, o_error_syndrome);
                    single_pass = 0;
                end
            end
            if (single_pass) begin
                $display("[PASS] All 32 data bit single-error corrections successful");
                pass_count = pass_count + 1;
            end
        end

        //--- Test 3: Single-Bit Error in Check Bits ---
        $display("[TEST 3] Single-Bit Error in Check Bits (7 check bits)");
        test_count = test_count + 1;
        begin : check_bit_test
            integer check_pass;
            check_pass = 1;
            test_data = 32'hCAFE_F00D;
            i_enc_data = test_data;
            #10;
            for (bit_pos = 0; bit_pos < CHECK_BITS; bit_pos = bit_pos + 1) begin
                corrupted_word = o_enc_word ^ (39'd1 << bit_pos);
                i_dec_word = corrupted_word;
                #10;
                if (o_dec_data != test_data || o_single_error != 1'b1 || o_double_error != 1'b0) begin
                    $display("[FAIL] Check-bit correction failed at bit %0d: data=0x%08h, se=%0b, de=%0b",
                             bit_pos, o_dec_data, o_single_error, o_double_error);
                    check_pass = 0;
                end
            end
            if (check_pass) begin
                $display("[PASS] All 7 check bit single-error corrections successful");
                pass_count = pass_count + 1;
            end
        end

        //--- Test 4: Double-Bit Error Detection ---
        $display("[TEST 4] Double-Bit Error Detection");
        test_count = test_count + 1;
        begin : double_bit_test
            integer dbl_pass;
            dbl_pass = 1;
            test_data = 32'hAAAA_5555;
            i_enc_data = test_data;
            #10;
            // Corrupt two data bits
            corrupted_word = o_enc_word ^ (39'd1 << (CHECK_BITS + 0)) ^ (39'd1 << (CHECK_BITS + 7));
            i_dec_word = corrupted_word;
            #10;
            if (o_double_error == 1'b1) begin
                $display("[PASS] Double-bit error detected: de=%0b, synd=0x%02h", o_double_error, o_error_syndrome);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Double-bit error not detected: de=%0b, se=%0b, synd=0x%02h",
                         o_double_error, o_single_error, o_error_syndrome);
            end
        end

        //--- Test 5: All-Zeros Data ---
        $display("[TEST 5] All-Zeros Data");
        test_count = test_count + 1;
        test_data = 32'h0000_0000;
        i_enc_data = test_data;
        #10;
        i_dec_word = o_enc_word;
        #10;
        if (o_dec_data == test_data && o_single_error == 1'b0 && o_double_error == 1'b0) begin
            $display("[PASS] All-zeros data passes through");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] All-zeros data failed");
        end

        //--- Test 6: All-Ones Data ---
        $display("[TEST 6] All-Ones Data");
        test_count = test_count + 1;
        test_data = 32'hFFFF_FFFF;
        i_enc_data = test_data;
        #10;
        i_dec_word = o_enc_word;
        #10;
        if (o_dec_data == test_data && o_single_error == 1'b0 && o_double_error == 1'b0) begin
            $display("[PASS] All-ones data passes through");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] All-ones data failed");
        end

        //--- Summary ---
        $display("");
        $display("===============================================================================");
        $display("ECC SECDED-32 Test Summary: %0d/%0d passed", pass_count, test_count);
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
        $dumpfile("sim/ecc_secdec_32.vcd");
        $dumpvars(0, ecc_secdec_32_tb);
    end
    `endif

endmodule
