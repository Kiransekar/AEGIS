//===============================================================================
// Module: rt_watchdog
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_watchdog.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Watchdog timer with configurable timeout and SMU fault reporting.
//   Must be periodically serviced (kick) to prevent timeout.
//   Timeout triggers SMU fault code FC_WATCHDOG_TIMEOUT.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-WDG-001 — ARCHITECTURE.md §3 (Watchdog)
//   @WCET: Timeout detection = 1 cycle after counter expires
//   @SAFETY: Watchdog timeout → SMU fault → safe-state (irreversible)
//   @SAFETY: Counter cannot be disabled — only kicked (restarted)
//   @FAULT: Watchdog timeout indicates software hang or timing violation
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_watchdog #(
    parameter COUNTER_WIDTH = 32
) (
    input  wire                        i_clk,
    input  wire                        i_rst_n,

    // Control
    input  wire                        i_enable,       // Watchdog enable (CSR-controlled)
    input  wire [COUNTER_WIDTH-1:0]    i_timeout,      // Timeout value (CSR-controlled)
    input  wire                        i_kick,          // Service/kick the watchdog

    // Status
    output reg                         o_timeout,      // Timeout occurred
    output reg  [COUNTER_WIDTH-1:0]    o_counter,      // Current counter value
    output reg                         o_enabled       // Watchdog enabled
);

    //-------------------------------------------------------------------------
    // Watchdog Counter
    // @SAFETY: Counts down from i_timeout; kick resets to i_timeout
    // @WCET: Timeout detection = 1 cycle
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_counter <= {COUNTER_WIDTH{1'b0}};
            o_timeout <= 1'b0;
            o_enabled <= 1'b0;
        end else begin
            o_enabled <= i_enable;

            if (!i_enable) begin
                // Watchdog disabled — hold counter at 0
                o_counter <= {COUNTER_WIDTH{1'b0}};
                o_timeout <= 1'b0;
            end else if (!o_enabled && i_enable) begin
                // @SAFETY: Load timeout on enable transition
                o_counter <= i_timeout;
                o_timeout  <= 1'b0;
            end else if (i_kick) begin
                // @SAFETY: Kick restarts the counter
                o_counter <= i_timeout;
                o_timeout  <= 1'b0;
            end else if (o_counter == {COUNTER_WIDTH{1'b0}}) begin
                // @SAFETY: Counter expired — timeout!
                // @FAULT: Software failed to service watchdog
                o_timeout <= 1'b1;
                // @SAFETY: Timeout is latching — requires reset to clear
            end else begin
                o_counter <= o_counter - 1'b1;
                o_timeout  <= 1'b0;
            end
        end
    end

endmodule
