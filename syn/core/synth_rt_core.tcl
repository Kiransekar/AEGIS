#===============================================================================
# AEGIS-RV Synthesis Script: RT Core
# Module: aegis_rt_core
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
#===============================================================================

# Read RTL
read_verilog -sv -defer rtl/core/rt_pipeline_if.v
read_verilog -sv -defer rtl/core/rt_register_file.v
read_verilog -sv -defer rtl/core/rt_alu.v
read_verilog -sv -defer rtl/core/rt_branch_unit.v
read_verilog -sv -defer rtl/core/rt_csr_unit.v
read_verilog -sv -defer rtl/core/xdrone_decoder.v
read_verilog -sv -defer rtl/core/xdrone_dispatcher.v
read_verilog -sv -defer rtl/core/tcls_voter.v
read_verilog -sv -defer rtl/core/tcls_mismatch_counter.v
read_verilog -sv -defer rtl/core/rt_interrupt_controller.v
read_verilog -sv -defer rtl/core/aegis_rt_core.v

# Elaborate
hierarchy -check -top aegis_rt_core

# Synthesize
synth -top aegis_rt_core

# Apply constraints & optimize
tcl syn/130nm_constraints.tcl
tcl syn/synth_common.tcl

# Reports
tee -o syn/reports/rt_core_area.rpt     print_stats
tee -o syn/reports/rt_core_timing.rpt   ltp
tee -o syn/reports/rt_core_check.rpt    check

# Output
write_verilog -noattr syn/core/aegis_rt_core_syn.v
write_json syn/core/aegis_rt_core.json

echo "✓ RT Core synthesis complete"
