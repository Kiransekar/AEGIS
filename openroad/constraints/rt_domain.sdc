#===============================================================================
# AEGIS-RV RT Domain Timing Constraints (OpenROAD)
# Target: 240 MHz @ 130nm typical corner
#===============================================================================

# Clock
create_clock -name clk_rt -period 4.167 [get_ports i_clk]
set_clock_uncertainty 0.1 [get_clocks clk_rt]
set_clock_latency 0.3 [get_clocks clk_rt]

# I/O delays
set_input_delay -clock clk_rt 0.5 [all_inputs]
set_output_delay -clock clk_rt 0.5 [all_outputs]

# WCET paths
set_max_delay 12.0 -from [get_cells *irq_controller*] -to [get_cells *pc_mux*]
set_max_delay 5.0  -from [get_cells *tcls_mismatch_counter*] -to [get_cells *quarantine_mux*]

# False paths
set_false_path -from [get_cells *debug_halt*] -to [get_cells *pc_update*]

# Power intent
set_auto_clock_gating_enable true
