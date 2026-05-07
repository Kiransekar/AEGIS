#===============================================================================
# AEGIS-RV 130nm Timing & Power Constraints
# Target: 240 MHz @ 130nm typical corner (25°C, 1.2V)
#===============================================================================

# Clock definition
create_clock -name clk_rt -period 4.167 [get_ports i_clk]

# Input/Output delays (conservative for 130nm)
set_input_delay -clock clk_rt 0.5 [all_inputs]
set_output_delay -clock clk_rt 0.5 [all_outputs]

# Clock uncertainty (jitter + margin)
set_clock_uncertainty 0.1 [get_clocks clk_rt]

# Clock latency
set_clock_latency 0.3 [get_clocks clk_rt]

# Fanout limits
set_max_fanout 16 [all_inputs]

# Capacitance limits
set_max_capacitance 0.1 [all_inputs]

# WCET bounding paths (from CLAUDE.md §2.3)
set_max_delay 12.0 -from [get_cells *irq_controller*] -to [get_cells *pc_mux*]
set_max_delay 5.0  -from [get_cells *tcls_mismatch_counter*] -to [get_cells *quarantine_mux*]
set_max_delay 2.0  -from [get_cells *xdrone_qmul*] -to [get_cells *wb_reg*]
set_max_delay 4.0  -from [get_cells *xdrone_kalman*] -to [get_cells *wb_reg*]

# False paths (async/safe)
set_false_path -from [get_cells *debug_halt*] -to [get_cells *pc_update*]
set_false_path -from [get_cells *smu_fault_latch*] -to [get_cells *pipeline*]

# Power optimization
set_auto_clock_gating_enable true
