//===============================================================================
// Module: crypto_accel_if
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/security/crypto_accel_if.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Interface to external crypto accelerator. Phase 1 stub.
//
// Safety Annotations:
//   @CERT: AEGIS-SEC-CRYPTO-001 — ARCHITECTURE.md §4 (Crypto)
//   @SAFETY: All crypto ops go through constant_time_wrapper
//
// License: Proprietary (Xdrone extensions)
//===============================================================================

module crypto_accel_if (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_req_valid,
    input  wire [7:0]  i_req_opcode,
    input  wire [31:0] i_req_data,
    output wire        o_req_ready,
    output wire [31:0] o_resp_data,
    output wire        o_resp_valid,
    output wire        o_resp_error
);

    // Phase 1 stub — pass-through
    assign o_req_ready  = 1'b1;
    assign o_resp_data  = i_req_data;
    assign o_resp_valid = i_req_valid;
    assign o_resp_error = 1'b0;

endmodule
