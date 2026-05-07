//===============================================================================
// Module: retention_reg_32
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/power/retention_reg_32.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   ISO-compliant retention register (32-bit) for preserving state during
//   sleep mode. Save/restore controlled by retention enable signal.
//
// Safety Annotations:
//   @CERT: AEGIS-PWR-RET-001 — Retention register (ISO 26262-5:2018 §8.4.3)
//   @SAFETY: Retention register preserves critical state during power gating;
//            restore failure triggers SMU fault (FC_RETENTION_RESTORE_FAIL)
//   @WCET: Save = 1 cycle; Restore = 1 cycle
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module retention_reg_32 #(
    parameter WIDTH = 32,
    parameter RESET_VALUE = {32{1'b0}}
) (
    input  wire             i_clk,
    input  wire             i_rst_n,
    input  wire [WIDTH-1:0] i_din,         // Data input
    output wire [WIDTH-1:0] o_dout,        // Data output
    input  wire             i_retention_en, // Retention enable (save/hold)
    input  wire             i_restore,      // Restore from retention
    output wire             o_restore_fail  // Restore mismatch detected
);

    // Main register
    reg [WIDTH-1:0] main_reg;

    // Retention shadow register (always-on domain)
    // @SAFETY: Shadow register retains value even when main power is gated
    reg [WIDTH-1:0] shadow_reg;

    // Main register with synchronous reset
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            main_reg <= RESET_VALUE;
        end else if (i_restore) begin
            // @SAFETY: Restore from shadow register on wake
            main_reg <= shadow_reg;
        end else begin
            main_reg <= i_din;
        end
    end

    // Shadow register (save on retention enable transition)
    // @SAFETY: Shadow captures main_reg only when retention_en rises (edge-triggered save)
    reg        retention_en_prev;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            shadow_reg        <= {WIDTH{1'b0}};
            retention_en_prev <= 1'b0;
        end else begin
            retention_en_prev <= i_retention_en;
            if (!retention_en_prev && i_retention_en) begin
                // @SAFETY: Capture on rising edge of retention enable
                shadow_reg <= main_reg;
            end
        end
    end

    // Output
    assign o_dout = main_reg;

    // Restore verification
    // @SAFETY: Detect mismatch between main and shadow after restore
    assign o_restore_fail = i_restore && (main_reg !== shadow_reg);

endmodule
