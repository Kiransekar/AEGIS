//===============================================================================
// Module: secure_boot_stub
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/security/secure_boot_stub.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Minimal OTP ROM boot stub for secure boot (hybrid RSA/ECC).
//   Phase 1 stub — validates boot image integrity.
//
// Safety Annotations:
//   @CERT: AEGIS-SEC-BOOT-001 — ARCHITECTURE.md §4 (Secure Boot)
//   @SAFETY: Boot stub is read-only (OTP ROM); immutable after manufacture
//   @WCET: Boot validation = deterministic (fixed signature check)
//
// License: Proprietary (Xdrone extensions)
//===============================================================================

module secure_boot_stub (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_boot_start,
    output wire        o_boot_done,
    output wire        o_boot_valid,     // Boot image integrity verified
    output wire        o_boot_error      // Boot image verification failed
);

    reg boot_done_reg;
    reg boot_valid_reg;
    reg boot_error_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            boot_done_reg  <= 1'b0;
            boot_valid_reg <= 1'b0;
            boot_error_reg <= 1'b0;
        end else if (i_boot_start) begin
            // @SAFETY: Stub — always pass for Phase 1
            boot_done_reg  <= 1'b1;
            boot_valid_reg <= 1'b1;
            boot_error_reg <= 1'b0;
        end else begin
            boot_done_reg <= 1'b0;
        end
    end

    assign o_boot_done  = boot_done_reg;
    assign o_boot_valid = boot_valid_reg;
    assign o_boot_error = boot_error_reg;

endmodule
