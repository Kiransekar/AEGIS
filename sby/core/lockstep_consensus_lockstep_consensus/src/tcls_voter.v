//===============================================================================
// Module: tcls_voter
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/tcls_voter.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Triple lockstep comparator with 2oo3 voting and quarantine FSM.
//   Cycle-by-cycle comparison of three RT core outputs.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-TCLS-001 — ARCHITECTURE.md §5 (Lockstep)
//   @SAFETY: 2oo3 voting ensures correct output even with single core fault;
//            quarantine within 5 cycles of threshold breach
//   @WCET: Voting = combinational; quarantine ≤5 cycles
//
// Verification:
//   Testbench: tb/core/tcls_voter_tb.v
//   Formal: sby/core/tcls_properties.sby
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module tcls_voter #(
    parameter MISMATCH_THRESHOLD = 3'd3,  // Consecutive mismatches before quarantine
    parameter QUARANTINE_MAX_CYCLES = 5    // Max cycles from threshold to quarantine
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Core outputs (3 identical cores)
    input  wire [31:0] i_core_a_out,
    input  wire [31:0] i_core_b_out,
    input  wire [31:0] i_core_c_out,
    input  wire        i_core_a_valid,
    input  wire        i_core_b_valid,
    input  wire        i_core_c_valid,

    // Voter outputs
    output wire [31:0] o_voter_output,    // Majority vote result
    output wire        o_voter_valid,     // Output valid
    output wire        o_mismatch,        // Mismatch detected (single-cycle pulse)

    // Quarantine control
    output wire [1:0]  o_mismatch_cnt,    // Consecutive mismatch count
    output wire        o_quarantine_req,  // Quarantine requested
    input  wire        i_quarantine_ack,  // Quarantine acknowledged

    // Hot-spare control
    input  wire        i_spare_core_en,   // Enable spare core promotion
    output wire        o_spare_core_active // Spare core now active
);

    //-------------------------------------------------------------------------
    // 2oo3 Majority Voting
    // @SAFETY: Output is majority of 3 inputs; handles single core fault
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    reg [31:0] voter_output_reg;

    always @* begin
        if (i_core_a_out == i_core_b_out) begin
            // A and B agree — use A (or B)
            voter_output_reg = i_core_a_out;
        end else if (i_core_a_out == i_core_c_out) begin
            // A and C agree — use A
            voter_output_reg = i_core_a_out;
        end else begin
            // B and C agree (A is faulty) — use B
            voter_output_reg = i_core_b_out;
        end
    end

    assign o_voter_output = voter_output_reg;
    assign o_voter_valid = i_core_a_valid && i_core_b_valid && i_core_c_valid;

    //-------------------------------------------------------------------------
    // Mismatch Detection
    // @SAFETY: Any pairwise mismatch is flagged as a single-cycle pulse
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    wire mismatch_ab = (i_core_a_out != i_core_b_out) && i_core_a_valid && i_core_b_valid;
    wire mismatch_ac = (i_core_a_out != i_core_c_out) && i_core_a_valid && i_core_c_valid;
    wire mismatch_bc = (i_core_b_out != i_core_c_out) && i_core_b_valid && i_core_c_valid;

    assign o_mismatch = mismatch_ab || mismatch_ac || mismatch_bc;

    //-------------------------------------------------------------------------
    // Mismatch Counter (consecutive mismatches)
    // @SAFETY: Counter resets on match; accumulates on mismatch
    // @WCET: Increment = 1 cycle; threshold comparison = combinational
    // @CERT: AEGIS-RT-TCLS-002 — Mismatch counter (ISO 26262-5:2018 §8.4.3)
    //-------------------------------------------------------------------------
    reg [1:0] mismatch_cnt_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            mismatch_cnt_reg <= 2'd0;
        end else if (o_mismatch) begin
            // @SAFETY: Increment counter on mismatch (saturate at threshold)
            if (mismatch_cnt_reg < MISMATCH_THRESHOLD[1:0]) begin
                mismatch_cnt_reg <= mismatch_cnt_reg + 2'd1;
            end
        end else begin
            // @SAFETY: Reset on match (prevents transient noise accumulation)
            mismatch_cnt_reg <= 2'd0;
        end
    end

    assign o_mismatch_cnt = mismatch_cnt_reg;

    //-------------------------------------------------------------------------
    // Quarantine FSM
    // @SAFETY: Quarantine triggered when mismatch count reaches threshold
    // @WCET: Threshold → quarantine_req ≤5 cycles
    // @CERT: AEGIS-RT-TCLS-003 — Quarantine timing (ISO 26262-5:2018 §8.4.3)
    //-------------------------------------------------------------------------
    reg quarantine_req_reg;
    reg spare_core_active_reg;
    reg [2:0] quarantine_counter;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            quarantine_req_reg   <= 1'b0;
            spare_core_active_reg <= 1'b0;
            quarantine_counter   <= 3'd0;
        end else if (i_quarantine_ack && quarantine_req_reg) begin
            // @SAFETY: Quarantine acknowledged — promote spare core
            if (i_spare_core_en) begin
                spare_core_active_reg <= 1'b1;
            end
        end else if (mismatch_cnt_reg >= MISMATCH_THRESHOLD[1:0]) begin
            // @SAFETY: Threshold reached — initiate quarantine
            if (quarantine_counter < QUARANTINE_MAX_CYCLES[2:0]) begin
                quarantine_counter <= quarantine_counter + 3'd1;
            end else begin
                quarantine_req_reg <= 1'b1;
            end
        end
    end

    assign o_quarantine_req    = quarantine_req_reg;
    assign o_spare_core_active = spare_core_active_reg;

endmodule
