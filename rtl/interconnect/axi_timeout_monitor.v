//===============================================================================
// Module: axi_timeout_monitor
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/interconnect/axi_timeout_monitor.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Bus timeout detector to prevent AXI deadlock.
//   Triggers SMU fault (FC_AXI_TIMEOUT) on timeout.
//
// Safety Annotations:
//   @CERT: AEGIS-INT-AXI-002 — ARCHITECTURE.md §8 (Timeout)
//   @SAFETY: Prevents deadlock from unresponsive slaves
//   @WCET: Timeout detection = 1 cycle after threshold
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module axi_timeout_monitor #(
    parameter TIMEOUT_CYCLES = 32'd1000  // ~4.17 µs @ 240 MHz
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_axi_valid,      // AXI request valid
    input  wire        i_axi_ready,      // AXI response ready
    output wire        o_timeout,        // Timeout detected
    output wire [31:0] o_timeout_count   // Current counter value
);

    reg [31:0] counter;
    reg        timeout_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            counter     <= 32'd0;
            timeout_reg <= 1'b0;
        end else if (i_axi_ready) begin
            counter     <= 32'd0;
            timeout_reg <= 1'b0;
        end else if (i_axi_valid) begin
            if (counter >= TIMEOUT_CYCLES) begin
                // @SAFETY: Timeout — trigger SMU fault
                timeout_reg <= 1'b1;
            end else begin
                counter <= counter + 32'd1;
            end
        end else begin
            counter     <= 32'd0;
            timeout_reg <= 1'b0;
        end
    end

    assign o_timeout       = timeout_reg;
    assign o_timeout_count = counter;

endmodule
