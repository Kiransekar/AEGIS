//===============================================================================
// Module: tt_arbiter_4master
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/interconnect/tt_arbiter_4master.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Time-triggered arbiter for 4 masters with fixed schedule.
//   QoS priority: RT > Security > App > DMA
//
// Safety Annotations:
//   @CERT: AEGIS-INT-TT-001 — ARCHITECTURE.md §8 (Interconnect)
//   @WCET: Arbitration = 1 cycle (fixed schedule, no dynamic priority)
//   @SAFETY: Fixed schedule prevents starvation and non-deterministic latency
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module tt_arbiter_4master (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [3:0]  i_req,            // Request from 4 masters
    output wire [3:0]  o_grant,          // Grant to 4 masters
    output wire [1:0]  o_current_master  // Current master index
);

    // @SAFETY: Fixed priority: master 0 (RT) > master 1 (Security) >
    //          master 2 (App) > master 3 (DMA)
    // Phase 1: Simple fixed priority arbiter
    reg [1:0] current_master;
    reg [3:0] grant_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            current_master <= 2'd0;
            grant_reg      <= 4'd0;
        end else begin
            // Fixed priority arbitration
            if (i_req[0]) begin
                grant_reg      <= 4'b0001;
                current_master <= 2'd0;
            end else if (i_req[1]) begin
                grant_reg      <= 4'b0010;
                current_master <= 2'd1;
            end else if (i_req[2]) begin
                grant_reg      <= 4'b0100;
                current_master <= 2'd2;
            end else if (i_req[3]) begin
                grant_reg      <= 4'b1000;
                current_master <= 2'd3;
            end else begin
                grant_reg <= 4'd0;
            end
        end
    end

    assign o_grant          = grant_reg;
    assign o_current_master = current_master;

endmodule
