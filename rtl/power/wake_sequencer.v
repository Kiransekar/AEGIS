//===============================================================================
// Module: wake_sequencer
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/power/wake_sequencer.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Power-up sequencing controller with stabilization timer.
//   Ensures power domain is stable before releasing reset.
//
// Safety Annotations:
//   @CERT: AEGIS-PWR-WAKE-001 — Wake sequencing (ISO 26262-5:2018 §8.4.3)
//   @SAFETY: Power domain must stabilize before logic is enabled;
//            premature wake can cause metastability
//   @WCET: Wake sequence = WAKE_STABILIZE_CYCLES (default 1 µs @ 240 MHz)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module wake_sequencer #(
    parameter STABILIZE_CYCLES = 32'd240  // 1 µs @ 240 MHz
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_wake_start,      // Start wake sequence
    output wire        o_wake_done,       // Wake sequence complete
    output wire        o_in_progress      // Wake in progress
);

    reg [31:0] stabilize_counter;
    reg        wake_active;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            stabilize_counter <= 32'd0;
            wake_active       <= 1'b0;
        end else if (i_wake_start && !wake_active) begin
            // @SAFETY: Start stabilization counter on wake request
            stabilize_counter <= 32'd0;
            wake_active       <= 1'b1;
        end else if (wake_active) begin
            if (stabilize_counter >= STABILIZE_CYCLES) begin
                // @SAFETY: Stabilization period complete
                wake_active <= 1'b0;
            end else begin
                stabilize_counter <= stabilize_counter + 32'd1;
            end
        end
    end

    assign o_wake_done    = wake_active && (stabilize_counter >= STABILIZE_CYCLES);
    assign o_in_progress  = wake_active;

endmodule
