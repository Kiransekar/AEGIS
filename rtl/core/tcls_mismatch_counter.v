//===============================================================================
// Module: tcls_mismatch_counter
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/tcls_mismatch_counter.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Configurable threshold counter for TCLS mismatch filtering.
//   Prevents transient SEU from triggering quarantine.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-TCLS-004 — Mismatch counter (ISO 26262-5:2018 §8.4.3)
//   @SAFETY: Counter resets on match; saturates at threshold
//   @WCET: Increment = 1 cycle
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module tcls_mismatch_counter #(
    parameter THRESHOLD = 3'd3,       // Mismatch count threshold
    parameter WIDTH = 2               // Counter width (supports 0-3)
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_mismatch,     // Mismatch detected (single-cycle pulse)
    output wire [WIDTH-1:0] o_count,  // Current mismatch count
    output wire        o_threshold_reached // Threshold reached
);

    reg [WIDTH-1:0] count_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            count_reg <= {WIDTH{1'b0}};
        end else if (i_mismatch) begin
            // @SAFETY: Increment on mismatch, saturate at threshold
            if (count_reg < THRESHOLD[WIDTH-1:0]) begin
                count_reg <= count_reg + {{(WIDTH-1){1'b0}}, 1'b1};
            end
        end else begin
            // @SAFETY: Reset on match (no false accumulation)
            count_reg <= {WIDTH{1'b0}};
        end
    end

    assign o_count = count_reg;
    assign o_threshold_reached = (count_reg >= THRESHOLD[WIDTH-1:0]);

endmodule
