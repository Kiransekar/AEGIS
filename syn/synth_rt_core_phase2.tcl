#===============================================================================
# AEGIS-RV Synthesis Script — RT Core Phase 2 (v2.0)
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
# Clock: 240 MHz (4.167 ns period)
#===============================================================================

#--- Read RTL ---
read_verilog -sv -defer rtl/core/rt_pipeline_if.v
read_verilog -sv -defer rtl/core/rt_pipeline_controller.v
read_verilog -sv -defer rtl/core/rv32c_expander.v
read_verilog -sv -defer rtl/core/rt_decoder.v
read_verilog -sv -defer rtl/core/rt_register_file.v
read_verilog -sv -defer rtl/core/rt_alu.v
read_verilog -sv -defer rtl/core/rt_fpu.v
read_verilog -sv -defer rtl/core/rt_muldiv.v
read_verilog -sv -defer rtl/core/rt_atomic.v
read_verilog -sv -defer rtl/core/rt_watchdog.v
read_verilog -sv -defer rtl/core/rt_branch_unit.v
read_verilog -sv -defer rtl/core/rt_csr_unit.v
read_verilog -sv -defer rtl/core/xdrone_decoder.v
read_verilog -sv -defer rtl/core/xdrone_qmul.v
read_verilog -sv -defer rtl/core/xdrone_kalman.v
read_verilog -sv -defer rtl/core/xdrone_dispatcher.v
read_verilog -sv -defer rtl/core/tcls_voter.v
read_verilog -sv -defer rtl/core/tcls_mismatch_counter.v
read_verilog -sv -defer rtl/core/rt_interrupt_controller.v
read_verilog -sv -defer rtl/core/rt_dft_scan.v
read_verilog -sv -defer rtl/core/aegis_rt_core.v

#--- Elaborate ---
hierarchy -check -top aegis_rt_core

#--- Synthesis ---
# @SAFETY: Preserve safety-critical signals for formal verification
synth -top aegis_rt_core -flatten

#--- Optimize ---
opt
opt_clean -purge

#--- Timing constraints (130nm) ---
# Clock
create_clock -name clk_rt -period 4.167 [get_ports i_clk]

# Input/Output delays
set_input_delay -clock clk_rt 0.5 [all_inputs]
set_output_delay -clock clk_rt 0.5 [all_outputs]

# WCET bounding paths (Phase 2)
set_max_delay 8.334  -from [get_cells *u_muldiv*]  -to [get_cells *wb_result*]
set_max_delay 16.668 -from [get_cells *u_muldiv*]  -to [get_cells *wb_result*]
set_max_delay 4.167  -from [get_cells *u_fpu*]     -to [get_cells *wb_result*]
set_max_delay 4.167  -from [get_cells *u_atomic*]  -to [get_cells *wb_result*]
set_max_delay 50.004 -from [get_cells *u_irq_ctrl*] -to [get_cells *pc*]

# False paths
set_false_path -from [get_cells *i_debug_halt*]
set_false_path -from [get_cells *i_smu_safe_req*]

#--- Reports ---
report_checks -path_delay max
report_checks -path_delay min
report_area

#--- Output ---
write_verilog -noattr syn/aegis_rt_core_phase2_syn.v
write_json   syn/aegis_rt_core_phase2.json
