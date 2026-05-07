#===============================================================================
# AEGIS-RV OpenROAD Clock Tree Synthesis
# @SAFETY: Zero-skew clock tree for RT domain (deterministic timing)
#===============================================================================

source openroad/flow_common.tcl

# CTS configuration
# @SAFETY: RT domain requires zero-skew for deterministic interrupt latency
set cts_clks [list $rt_clock_name]
set cts_corner_max_slew 0.1
set cts_max_fanout 20
set cts_max_length 100

# Run CTS
clock_tree_synthesis -root_clk $rt_clock_name \
    -buf_list "sky130_fd_sc_hd__clkbuf_1 sky130_fd_sc_hd__clkbuf_2" \
    -sink_clks_in_groups true

# Post-CTS optimization
set_propagated_clock [all_clocks]

# Update timing after CTS
update_timing

echo "✓ CTS complete"
