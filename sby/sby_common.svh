//===============================================================================
// AEGIS-RV Formal Verification Common Macros
// File: sby/sby_common.svh
// Purpose: Standardize assertions, assumptions, and coverage points
//===============================================================================

`ifndef SBY_COMMON_SVH
`define SBY_COMMON_SVH

// Safety reset assumption
`define ASSUME_RESET \
  assume property (@(posedge i_clk) $fell(i_rst_n) |-> $stable(i_rst_n)[*1:2]);

// WCET bounding macro (max N cycles for operation)
`define WCET_BOUND(OP_START, OP_DONE, MAX_CYCLES) \
  assert property (@(posedge i_clk) disable iff (!i_rst_n) \
    (OP_START) |-> ##[1:`MAX_CYCLES] (OP_DONE));

// Fixed-latency invariant (exactly N cycles)
`define FIXED_LATENCY(START, DONE, EXACT_CYCLES) \
  assert property (@(posedge i_clk) disable iff (!i_rst_n) \
    (START) |-> ##`EXACT_CYCLES (DONE));

// Fault injection assumption (single-cycle SEU)
`define ASSUME_SEU(signal) \
  assume property (@(posedge i_clk) `signal |-> ##1 !`signal);

// Coverage point macro
`define COVER_SAFETY(name, condition) \
  cover property (@(posedge i_clk) disable iff (!i_rst_n) `condition);

`endif // SBY_COMMON_SVH
