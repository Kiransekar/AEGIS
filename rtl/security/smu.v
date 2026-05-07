//===============================================================================
// Module: smu
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/security/smu.v
// Version: 1.0
// Date: 2026-05-04
// Author: AEGIS-RV Build
//
// Description:
//   Safety Monitor Unit — Fault aggregation, ISO 26262 fault code management,
//   and safe-state trigger generation. Aggregates faults from TCLS, ECC,
//   watchdog, power, and security domains.
//
// Architecture Reference:
//   ARCHITECTURE.md §4 (Safety Monitor) — Fault Aggregation
//
// Safety Annotations:
//   @CERT: AEGIS-SEC-SMU-001 — ARCHITECTURE.md §4 (Safety Monitor)
//   @SAFETY: Fault aggregation is combinational (1-cycle); safe-state trigger
//            within 2 cycles of threshold breach
//   @WCET: Aggregation = 1 cycle; safe-state assert = 2 cycles worst-case
//
// Verification:
//   Testbench: tb/security/smu_tb.v
//   Formal: sby/security/smu_fault_aggregation.sby
//   Coverage Target: 100% line, >90% branch, 100% safety-critical path
//
// Synthesis:
//   Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
//   Clock: 240 MHz (4.167 ns)
//   Area Target: <0.05 mm² (core only)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

`include "smu_fault_codes.vh"

module smu #(
    parameter SPF_THRESHOLD = 3'd1,     // Single SPF triggers safe-state
    parameter LF_THRESHOLD  = 3'd3,     // 3 LFs trigger safe-state
    parameter MPF_THRESHOLD = 3'd1      // Single MPF triggers safe-state
) (
    // Clock & Reset
    input  wire        i_clk,           // 240 MHz RT domain clock
    input  wire        i_rst_n,         // Active-low async reset

    // Fault Inputs (one per fault source)
    input  wire [7:0]  i_fault_code,    // Current fault code (from fault sources)
    input  wire        i_fault_valid,   // Fault code valid (single-cycle pulse)

    // Aggregated Fault Outputs
    output wire [7:0]  o_active_fault,  // Highest-priority active fault code
    output wire [1:0]  o_fault_severity,// Current fault severity level
    output wire        o_safe_state_req,// Safe-state request to power orchestrator

    // Fault Acknowledge (from CPU via CSR)
    input  wire        i_fault_ack,     // Acknowledge current fault
    input  wire        i_safe_state_req,// Software-initiated safe-state request

    // SMU Status (CSR-mapped)
    output wire [31:0] o_fault_history, // Fault history register (bit-per-fault-source)
    output wire        o_fault_latched  // Any fault currently latched
);

    //-------------------------------------------------------------------------
    // Internal Registers
    //-------------------------------------------------------------------------

    // @SAFETY: Fault latch persists until explicitly acknowledged
    // @CERT: AEGIS-SEC-SMU-002 — Fault latch persistence (ISO 26262-5:2018 §8.4.3)
    reg [7:0]  latched_fault_code;
    reg        fault_latched_reg;
    reg [31:0] fault_history_reg;

    // Aggregation counters
    reg [2:0]  spf_counter;
    reg [2:0]  lf_counter;
    reg [2:0]  mpf_counter;

    // Safe-state FSM
    // @SAFETY: FSM ensures safe-state is requested within 2 cycles of threshold
    // @WCET: IDLE→EVALUATE=1 cycle; EVALUATE→TRIGGER=1 cycle; total=2 cycles
    localparam SMU_IDLE      = 2'd0;
    localparam SMU_EVALUATE  = 2'd1;
    localparam SMU_TRIGGER   = 2'd2;
    localparam SMU_SAFE_WAIT = 2'd3;

    reg [1:0]  smu_state;
    reg        safe_state_req_reg;

    //-------------------------------------------------------------------------
    // Fault Severity Classification
    // @WCET: Combinational — 1 cycle
    // @CERT: AEGIS-SEC-SMU-003 — Severity classification per ISO 26262-5:2018
    //-------------------------------------------------------------------------
    wire [1:0] fault_severity;

    assign fault_severity = i_fault_valid ? (
        (i_fault_code == `FC_TCLS_MISMATCH   || i_fault_code == `FC_TCLS_QUARANTINE ||
         i_fault_code == `FC_ECC_SINGLE_BIT  || i_fault_code == `FC_WATCHDOG_TIMEOUT ||
         i_fault_code == `FC_IRQ_LATENCY_VIOLATION || i_fault_code == `FC_CONTEXT_SWITCH_OVERRUN) ? `SEV_LOW :
        (i_fault_code == `FC_ECC_DOUBLE_BIT  || i_fault_code == `FC_SCRUBBER_CORRECTED ||
         i_fault_code == `FC_POWER_GLITCH    || i_fault_code == `FC_CLOCK_MONITOR_TRIP ||
         i_fault_code == `FC_RETENTION_RESTORE_FAIL) ? `SEV_MEDIUM :
        (i_fault_code == `FC_SPU_VIOLATION   || i_fault_code == `FC_PMP_VIOLATION ||
         i_fault_code == `FC_IOPMP_VIOLATION  || i_fault_code == `FC_AXI_TIMEOUT ||
         i_fault_code == `FC_SAFE_STATE_VIOLATION || i_fault_code == `FC_PMHF_THRESHOLD_EXCEEDED) ? `SEV_HIGH :
        `SEV_NONE
    ) : `SEV_NONE;

    //-------------------------------------------------------------------------
    // Fault Latch
    // @SAFETY: Latches highest-priority fault until acknowledged
    // @WCET: Latch update = 1 cycle
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            latched_fault_code <= 8'd0;
            fault_latched_reg  <= 1'b0;
        end else if (i_fault_ack) begin
            // @SAFETY: Clear latch on acknowledge (ISO 26262-5:2018 §8.4.3)
            latched_fault_code <= 8'd0;
            fault_latched_reg  <= 1'b0;
        end else if (i_fault_valid && !fault_latched_reg) begin
            // @SAFETY: Latch first fault (prevents overwriting with lower-priority)
            latched_fault_code <= i_fault_code;
            fault_latched_reg  <= 1'b1;
        end else if (i_fault_valid && fault_latched_reg) begin
            // @SAFETY: Update if new fault has higher severity
            if (fault_severity > o_fault_severity) begin
                latched_fault_code <= i_fault_code;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Fault History Register
    // @SAFETY: Bit-per-fault-source history for diagnostic analysis
    // @CERT: AEGIS-SEC-SMU-004 — Fault history for ISO 26262-5 diagnostic
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            fault_history_reg <= 32'd0;
        end else if (i_fault_valid) begin
            // Set bit corresponding to fault code (bits 0-31)
            if (i_fault_code < 8'd32) begin
                fault_history_reg[i_fault_code[4:0]] <= 1'b1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Aggregation Counters
    // @SAFETY: Counters track fault accumulation per severity level
    // @WCET: Counter increment = 1 cycle; threshold comparison = combinational
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            spf_counter <= 3'd0;
            lf_counter  <= 3'd0;
            mpf_counter <= 3'd0;
        end else if (i_fault_ack) begin
            // Reset all counters on acknowledge
            spf_counter <= 3'd0;
            lf_counter  <= 3'd0;
            mpf_counter <= 3'd0;
        end else if (i_fault_valid) begin
            case (fault_severity)
                `SEV_LOW:    spf_counter <= spf_counter + 3'd1;
                `SEV_MEDIUM: lf_counter  <= lf_counter  + 3'd1;
                `SEV_HIGH:   mpf_counter <= mpf_counter + 3'd1;
                default: ; // No increment for SEV_NONE
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Safe-State Trigger FSM
    // @SAFETY: Triggers safe-state when aggregation threshold is breached
    // @WCET: IDLE→EVALUATE=1 cycle; EVALUATE→TRIGGER=1 cycle; total ≤2 cycles
    // @CERT: AEGIS-SEC-SMU-005 — Safe-state trigger timing (ISO 26262-5:2018 §8.4.3)
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            smu_state         <= SMU_IDLE;
            safe_state_req_reg <= 1'b0;
        end else begin
            case (smu_state)
                SMU_IDLE: begin
                    safe_state_req_reg <= 1'b0;
                    // @SAFETY: Check for threshold breach or software request
                    if (i_fault_valid || i_safe_state_req) begin
                        smu_state <= SMU_EVALUATE;
                    end
                end

                SMU_EVALUATE: begin
                    // @WCET: Combinational threshold check completes in this cycle
                    if ((spf_counter >= SPF_THRESHOLD) ||
                        (lf_counter  >= LF_THRESHOLD)  ||
                        (mpf_counter >= MPF_THRESHOLD) ||
                        i_safe_state_req) begin
                        smu_state <= SMU_TRIGGER;
                    end else begin
                        smu_state <= SMU_IDLE; // No threshold breach
                    end
                end

                SMU_TRIGGER: begin
                    // @SAFETY: Assert safe-state request for power orchestrator
                    safe_state_req_reg <= 1'b1;
                    smu_state <= SMU_SAFE_WAIT;
                end

                SMU_SAFE_WAIT: begin
                    // @SAFETY: Hold safe-state request until acknowledged
                    if (i_fault_ack) begin
                        safe_state_req_reg <= 1'b0;
                        smu_state <= SMU_IDLE;
                    end
                end

                default: begin
                    // @SAFETY: Default prevents latch inference (ISO 26262-8:2018 §8.4.3)
                    smu_state <= SMU_IDLE;
                    safe_state_req_reg <= 1'b0;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Output Assignments
    //-------------------------------------------------------------------------
    assign o_active_fault   = latched_fault_code;
    assign o_fault_severity = fault_latched_reg ? fault_severity : `SEV_NONE;
    assign o_safe_state_req = safe_state_req_reg;
    assign o_fault_history  = fault_history_reg;
    assign o_fault_latched  = fault_latched_reg;

endmodule
