//===============================================================================
// AEGIS-RV Common Testbench Utilities
// File: tb/tb_common.vh
// Purpose: Shared macros for testbench logging, assertions, and clock/reset
//===============================================================================

`ifndef AEGIS_TB_COMMON_VH
`define AEGIS_TB_COMMON_VH

//-----------------------------------------------------------------------------
// Logging Macros
//-----------------------------------------------------------------------------
`define TB_INFO(msg)    $display("[INFO]  %0t: %s", $time, msg)
`define TB_WARN(msg)    $display("[WARN]  %0t: %s", $time, msg)
`define TB_ERROR(msg)   $display("[ERROR] %0t: %s", $time, msg)
`define TB_FATAL(msg)   begin $display("[FATAL] %0t: %s", $time, msg); $finish; end

//-----------------------------------------------------------------------------
// Assertion Macros
//-----------------------------------------------------------------------------
`define TB_ASSERT(cond, msg) \
    if (!(cond)) begin \
        $display("[FAIL] %0t: %s (condition: %s)", $time, msg, `"cond`"); \
    end

`define TB_ASSERT_FATAL(cond, msg) \
    if (!(cond)) begin \
        $display("[FATAL] %0t: %s (condition: %s)", $time, msg, `"cond`"); \
        $finish; \
    end

//-----------------------------------------------------------------------------
// Clock Generation Macro
// Usage: `TB_CLK_GEN(clk_signal, period_ns)
//-----------------------------------------------------------------------------
`define TB_CLK_GEN(clk_sig, period) \
    initial begin \
        clk_sig = 0; \
        forever #(period/2) clk_sig = ~clk_sig; \
    end

//-----------------------------------------------------------------------------
// Reset Task Macro
// Usage: `TB_RESET(clk_sig, rst_n_sig, cycles)
//-----------------------------------------------------------------------------
`define TB_RESET(clk_sig, rst_n_sig, cycles) \
    initial begin \
        rst_n_sig = 0; \
        repeat(cycles) @(posedge clk_sig); \
        rst_n_sig = 1; \
        @(posedge clk_sig); \
    end

`endif // AEGIS_TB_COMMON_VH
