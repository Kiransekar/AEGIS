#===============================================================================
# AEGIS-RV Synthesis Script: Scratchpad Controller
# Module: scratchpad_ctrl
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
#===============================================================================

# Read RTL
read_verilog -sv -defer rtl/memory/ecc_secdec_32.v
read_verilog -sv -defer rtl/memory/scratchpad_bank.v
read_verilog -sv -defer rtl/memory/scratchpad_ctrl.v

# Elaborate
hierarchy -check -top scratchpad_ctrl

# Synthesize
synth -top scratchpad_ctrl

# Apply constraints & optimize
tcl syn/130nm_constraints.tcl
tcl syn/synth_common.tcl

# Reports
tee -o syn/reports/scratchpad_area.rpt     print_stats
tee -o syn/reports/scratchpad_timing.rpt    ltp
tee -o syn/reports/scratchpad_check.rpt     check

# Output
write_verilog -noattr syn/memory/scratchpad_ctrl_syn.v
write_json syn/memory/scratchpad_ctrl.json

echo "✓ Scratchpad Controller synthesis complete"
