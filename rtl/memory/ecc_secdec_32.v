//===============================================================================
// Module: ecc_secdec_32
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/memory/ecc_secdec_32.v
// Version: 1.0
// Date: 2026-05-04
// Author: AEGIS-RV Build
//
// Description:
//   SECDED (Single Error Correction, Double Error Detection) encoder/decoder
//   for 32-bit data words using Hamming(39,32) code with overall parity.
//   Provides 7 check bits for single-bit correction and double-bit detection.
//
// Architecture Reference:
//   ARCHITECTURE.md §5 (Memory Subsystem) — ECC Protection
//
// Safety Annotations:
//   @CERT: AEGIS-MEM-ECC-001 — ARCHITECTURE.md §5 (ECC Protection)
//   @SAFETY: Single-bit errors corrected in 1 cycle; double-bit errors
//            flagged as uncorrectable (trigger SMU fault)
//   @WCET: Encode = combinational; Decode + Correct = 1 cycle
//
// Verification:
//   Testbench: tb/memory/ecc_secdec_32_tb.v
//   Formal: sby/memory/ecc_correction.sby
//   Coverage Target: 100% line, >90% branch, 100% safety-critical path
//
// Synthesis:
//   Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
//   Clock: 240 MHz (4.167 ns)
//   Area Target: <0.02 mm² (core only)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module ecc_secdec_32 #(
    parameter DATA_WIDTH = 32,           // Data word width
    parameter CHECK_BITS = 7,            // SECDED check bits (Hamming + overall parity)
    parameter TOTAL_WIDTH = 39           // DATA_WIDTH + CHECK_BITS
) (
    //--- Encoder Interface ---
    input  wire [DATA_WIDTH-1:0]  i_enc_data,      // Data to encode
    output wire [TOTAL_WIDTH-1:0] o_enc_word,      // Encoded word (data + check bits)

    //--- Decoder Interface ---
    input  wire [TOTAL_WIDTH-1:0] i_dec_word,      // Received word (data + check bits)
    output wire [DATA_WIDTH-1:0]  o_dec_data,      // Corrected data output
    output wire                  o_single_error,   // Single-bit error detected & corrected
    output wire                  o_double_error,   // Double-bit error detected (uncorrectable)
    output wire [CHECK_BITS-1:0] o_error_syndrome  // Error syndrome (bit position for single errors)
);

    //-------------------------------------------------------------------------
    // Hamming(38,32) + Overall Parity → SECDED(39,32)
    //
    // Check bit positions (1-indexed): 1, 2, 4, 8, 16, 32, 64
    // Overall parity bit at position 0 (MSB of check bits)
    //
    // Data bit mapping (1-indexed positions):
    //   Position 3,5,6,7,9,10,11,12,13,14,15,17,18,19,20,21,22,23,24,25,
    //            26,27,28,29,30,31,33,34,35,36,37,38
    //
    // @SAFETY: SECDED guarantees correction of single-bit errors and
    //          detection of double-bit errors (ISO 26262-5:2018 §8.4.3)
    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Encoder: Generate check bits from data
    // @WCET: Combinational logic — 0 cycles (same-cycle valid output)
    //-------------------------------------------------------------------------

    // Check bit 1 (covers positions with bit 0 set: 3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37)
    wire cb1 = i_enc_data[0]  ^ i_enc_data[1]  ^ i_enc_data[3]  ^ i_enc_data[4]  ^
               i_enc_data[6]  ^ i_enc_data[8]  ^ i_enc_data[10] ^ i_enc_data[11] ^
               i_enc_data[13] ^ i_enc_data[15] ^ i_enc_data[17] ^ i_enc_data[19] ^
               i_enc_data[21] ^ i_enc_data[23] ^ i_enc_data[25] ^ i_enc_data[26] ^
               i_enc_data[28] ^ i_enc_data[30];

    // Check bit 2 (covers positions with bit 1 set: 3,6,7,10,11,14,15,18,19,22,23,26,27,30,31,34,35,38)
    wire cb2 = i_enc_data[0]  ^ i_enc_data[2]  ^ i_enc_data[3]  ^ i_enc_data[5]  ^
               i_enc_data[6]  ^ i_enc_data[9]  ^ i_enc_data[10] ^ i_enc_data[12] ^
               i_enc_data[13] ^ i_enc_data[16] ^ i_enc_data[17] ^ i_enc_data[20] ^
               i_enc_data[21] ^ i_enc_data[24] ^ i_enc_data[25] ^ i_enc_data[27] ^
               i_enc_data[28] ^ i_enc_data[31];

    // Check bit 4 (covers positions with bit 2 set: 5,6,7,12,13,14,15,20,21,22,23,28,29,30,31,36,37,38)
    wire cb4 = i_enc_data[1]  ^ i_enc_data[2]  ^ i_enc_data[3]  ^ i_enc_data[7]  ^
               i_enc_data[8]  ^ i_enc_data[9]  ^ i_enc_data[10] ^ i_enc_data[14] ^
               i_enc_data[15] ^ i_enc_data[16] ^ i_enc_data[17] ^ i_enc_data[22] ^
               i_enc_data[23] ^ i_enc_data[24] ^ i_enc_data[25] ^ i_enc_data[29] ^
               i_enc_data[30] ^ i_enc_data[31];

    // Check bit 8 (covers positions with bit 3 set: 9-15, 24-31)
    wire cb8 = i_enc_data[4]  ^ i_enc_data[5]  ^ i_enc_data[6]  ^ i_enc_data[7]  ^
               i_enc_data[8]  ^ i_enc_data[9]  ^ i_enc_data[10] ^ i_enc_data[18] ^
               i_enc_data[19] ^ i_enc_data[20] ^ i_enc_data[21] ^ i_enc_data[22] ^
               i_enc_data[23] ^ i_enc_data[24] ^ i_enc_data[25];

    // Check bit 16 (covers positions with bit 4 set: 17-31)
    wire cb16 = i_enc_data[11] ^ i_enc_data[12] ^ i_enc_data[13] ^ i_enc_data[14] ^
                i_enc_data[15] ^ i_enc_data[16] ^ i_enc_data[17] ^ i_enc_data[18] ^
                i_enc_data[19] ^ i_enc_data[20] ^ i_enc_data[21] ^ i_enc_data[22] ^
                i_enc_data[23] ^ i_enc_data[24] ^ i_enc_data[25];

    // Check bit 32 (covers positions with bit 5 set: 33-38 → data[26]-data[31])
    wire cb32 = i_enc_data[26] ^ i_enc_data[27] ^ i_enc_data[28] ^ i_enc_data[29] ^
                i_enc_data[30] ^ i_enc_data[31];

    // Overall parity check bit (position 0) — XOR of all bits including Hamming checks
    wire cb_par = i_enc_data[0]  ^ i_enc_data[1]  ^ i_enc_data[2]  ^ i_enc_data[3]  ^
                  i_enc_data[4]  ^ i_enc_data[5]  ^ i_enc_data[6]  ^ i_enc_data[7]  ^
                  i_enc_data[8]  ^ i_enc_data[9]  ^ i_enc_data[10] ^ i_enc_data[11] ^
                  i_enc_data[12] ^ i_enc_data[13] ^ i_enc_data[14] ^ i_enc_data[15] ^
                  i_enc_data[16] ^ i_enc_data[17] ^ i_enc_data[18] ^ i_enc_data[19] ^
                  i_enc_data[20] ^ i_enc_data[21] ^ i_enc_data[22] ^ i_enc_data[23] ^
                  i_enc_data[24] ^ i_enc_data[25] ^ i_enc_data[26] ^ i_enc_data[27] ^
                  i_enc_data[28] ^ i_enc_data[29] ^ i_enc_data[30] ^ i_enc_data[31] ^
                  cb1 ^ cb2 ^ cb4 ^ cb8 ^ cb16 ^ cb32;

    // Encoded word: [38:7] = data, [6:0] = check bits
    assign o_enc_word = {i_enc_data, cb_par, cb32, cb16, cb8, cb4, cb2, cb1};

    //-------------------------------------------------------------------------
    // Decoder: Syndrome calculation + error detection/correction
    // @WCET: Combinational logic — 0 cycles (same-cycle valid output)
    // @SAFETY: Syndrome identifies exact error position for single-bit errors
    //-------------------------------------------------------------------------

    // Extract received data and check bits
    wire [DATA_WIDTH-1:0] rx_data = i_dec_word[TOTAL_WIDTH-1:CHECK_BITS];
    wire [CHECK_BITS-1:0] rx_check = i_dec_word[CHECK_BITS-1:0];

    // Recompute check bits from received data
    wire cb1_r  = rx_data[0]  ^ rx_data[1]  ^ rx_data[3]  ^ rx_data[4]  ^
                  rx_data[6]  ^ rx_data[8]  ^ rx_data[10] ^ rx_data[11] ^
                  rx_data[13] ^ rx_data[15] ^ rx_data[17] ^ rx_data[19] ^
                  rx_data[21] ^ rx_data[23] ^ rx_data[25] ^ rx_data[26] ^
                  rx_data[28] ^ rx_data[30];

    wire cb2_r  = rx_data[0]  ^ rx_data[2]  ^ rx_data[3]  ^ rx_data[5]  ^
                  rx_data[6]  ^ rx_data[9]  ^ rx_data[10] ^ rx_data[12] ^
                  rx_data[13] ^ rx_data[16] ^ rx_data[17] ^ rx_data[20] ^
                  rx_data[21] ^ rx_data[24] ^ rx_data[25] ^ rx_data[27] ^
                  rx_data[28] ^ rx_data[31];

    wire cb4_r  = rx_data[1]  ^ rx_data[2]  ^ rx_data[3]  ^ rx_data[7]  ^
                  rx_data[8]  ^ rx_data[9]  ^ rx_data[10] ^ rx_data[14] ^
                  rx_data[15] ^ rx_data[16] ^ rx_data[17] ^ rx_data[22] ^
                  rx_data[23] ^ rx_data[24] ^ rx_data[25] ^ rx_data[29] ^
                  rx_data[30] ^ rx_data[31];

    wire cb8_r  = rx_data[4]  ^ rx_data[5]  ^ rx_data[6]  ^ rx_data[7]  ^
                  rx_data[8]  ^ rx_data[9]  ^ rx_data[10] ^ rx_data[18] ^
                  rx_data[19] ^ rx_data[20] ^ rx_data[21] ^ rx_data[22] ^
                  rx_data[23] ^ rx_data[24] ^ rx_data[25];

    wire cb16_r = rx_data[11] ^ rx_data[12] ^ rx_data[13] ^ rx_data[14] ^
                  rx_data[15] ^ rx_data[16] ^ rx_data[17] ^ rx_data[18] ^
                  rx_data[19] ^ rx_data[20] ^ rx_data[21] ^ rx_data[22] ^
                  rx_data[23] ^ rx_data[24] ^ rx_data[25];

    wire cb32_r = rx_data[26] ^ rx_data[27] ^ rx_data[28] ^ rx_data[29] ^
                  rx_data[30] ^ rx_data[31];

    wire cb_par_r = rx_data[0]  ^ rx_data[1]  ^ rx_data[2]  ^ rx_data[3]  ^
                    rx_data[4]  ^ rx_data[5]  ^ rx_data[6]  ^ rx_data[7]  ^
                    rx_data[8]  ^ rx_data[9]  ^ rx_data[10] ^ rx_data[11] ^
                    rx_data[12] ^ rx_data[13] ^ rx_data[14] ^ rx_data[15] ^
                    rx_data[16] ^ rx_data[17] ^ rx_data[18] ^ rx_data[19] ^
                    rx_data[20] ^ rx_data[21] ^ rx_data[22] ^ rx_data[23] ^
                    rx_data[24] ^ rx_data[25] ^ rx_data[26] ^ rx_data[27] ^
                    rx_data[28] ^ rx_data[29] ^ rx_data[30] ^ rx_data[31] ^
                    cb1_r ^ cb2_r ^ cb4_r ^ cb8_r ^ cb16_r ^ cb32_r;

    // Syndrome = received check XOR recomputed check
    // @SAFETY: Non-zero syndrome indicates error; syndrome value = error position
    wire [CHECK_BITS-1:0] syndrome;
    assign syndrome = {cb_par_r ^ rx_check[6],
                       cb32_r ^ rx_check[5],
                       cb16_r ^ rx_check[4],
                       cb8_r  ^ rx_check[3],
                       cb4_r  ^ rx_check[2],
                       cb2_r  ^ rx_check[1],
                       cb1_r  ^ rx_check[0]};

    // Overall parity of received word
    wire overall_parity;
    assign overall_parity = ^i_dec_word;  // XOR of all 39 bits

    //-------------------------------------------------------------------------
    // Error Classification
    // @SAFETY: SECDED classification logic:
    //   syndrome=0, parity=0 → No error
    //   syndrome≠0, parity=1 → Single-bit error (correctable)
    //   syndrome≠0, parity=0 → Double-bit error (uncorrectable)
    //   syndrome=0, parity=1 → Error in overall parity bit only (correctable)
    // @CERT: AEGIS-MEM-ECC-002 — Error classification per ISO 26262-5:2018 §8.4.3
    //-------------------------------------------------------------------------
    assign o_single_error = (syndrome != 7'd0) && overall_parity;
    assign o_double_error = (syndrome != 7'd0) && !overall_parity;
    assign o_error_syndrome = syndrome;

    //-------------------------------------------------------------------------
    // Single-Bit Error Correction
    // @SAFETY: XOR the error bit position to flip the corrupted bit
    // @WCET: Combinational correction — 0 cycles
    //-------------------------------------------------------------------------
    // Map syndrome to data bit position and correct
    // Syndrome values 1-38 correspond to bit positions in the 39-bit word
    // Syndrome 0 = no error; Syndrome 1,2,4,8,16,32 = check bit errors

    reg [DATA_WIDTH-1:0] corrected_data;

    always @* begin
        corrected_data = rx_data;  // Default: no correction
        if (o_single_error) begin
            case (syndrome[5:0])
                // Syndrome[5:0] maps to Hamming position in 39-bit word
                // Positions 3,5,6,7,9,10,11,12,13,14,15,17,18,19,20,21,22,23,24,25,
                //          26,27,28,29,30,31,33,34,35,36,37,38 are data bits
                6'd3:  corrected_data[0]  = ~rx_data[0];
                6'd5:  corrected_data[1]  = ~rx_data[1];
                6'd6:  corrected_data[2]  = ~rx_data[2];
                6'd7:  corrected_data[3]  = ~rx_data[3];
                6'd9:  corrected_data[4]  = ~rx_data[4];
                6'd10: corrected_data[5]  = ~rx_data[5];
                6'd11: corrected_data[6]  = ~rx_data[6];
                6'd12: corrected_data[7]  = ~rx_data[7];
                6'd13: corrected_data[8]  = ~rx_data[8];
                6'd14: corrected_data[9]  = ~rx_data[9];
                6'd15: corrected_data[10] = ~rx_data[10];
                6'd17: corrected_data[11] = ~rx_data[11];
                6'd18: corrected_data[12] = ~rx_data[12];
                6'd19: corrected_data[13] = ~rx_data[13];
                6'd20: corrected_data[14] = ~rx_data[14];
                6'd21: corrected_data[15] = ~rx_data[15];
                6'd22: corrected_data[16] = ~rx_data[16];
                6'd23: corrected_data[17] = ~rx_data[17];
                6'd24: corrected_data[18] = ~rx_data[18];
                6'd25: corrected_data[19] = ~rx_data[19];
                6'd26: corrected_data[20] = ~rx_data[20];
                6'd27: corrected_data[21] = ~rx_data[21];
                6'd28: corrected_data[22] = ~rx_data[22];
                6'd29: corrected_data[23] = ~rx_data[23];
                6'd30: corrected_data[24] = ~rx_data[24];
                6'd31: corrected_data[25] = ~rx_data[25];
                6'd33: corrected_data[26] = ~rx_data[26];
                6'd34: corrected_data[27] = ~rx_data[27];
                6'd35: corrected_data[28] = ~rx_data[28];
                6'd36: corrected_data[29] = ~rx_data[29];
                6'd37: corrected_data[30] = ~rx_data[30];
                6'd38: corrected_data[31] = ~rx_data[31];
                // Syndromes 1,2,4,8,16,32 = check bit errors (no data correction needed)
                default: corrected_data = rx_data;  // @SAFETY: No data correction for check-bit errors
            endcase
        end
    end

    assign o_dec_data = corrected_data;

endmodule
