#===============================================================================
# AEGIS-RV OpenROAD PnR Flow (130nm)
# Target: SkyWater 130 / TSMC 130G
#===============================================================================

# Load design
if {[info exists ::env(TECH_LEF)]} {
    read_lef $::env(TECH_LEF)
}
if {[info exists ::env(STD_CELL_LEF)]} {
    read_lef $::env(STD_CELL_LEF)
}

if {[file exists "syn/aegis_rt_top_syn.v"]} {
    read_verilog syn/aegis_rt_top_syn.v
    link_design aegis_rt_top
} else {
    puts "ERROR: Synthesized netlist not found. Run synthesis first."
    exit 1
}

# Read constraints
if {[file exists "openroad/constraints/rt_domain.sdc"]} {
    read_sdc openroad/constraints/rt_domain.sdc
}

# Floorplan
init_floorplan -utilization 0.45 -aspect_ratio 1.0

# Place safety blocks in isolated corner
# @SAFETY: TCLS voter + SMU in dedicated corner for fault isolation
place_macro -instance tcls_voter -location {50 50} -orientation R0
place_macro -instance smu -location {50 200} -orientation R0
create_placement_blockage -bbox {30 30 200 400} -type hard

# Placement
global_placement -density 0.65
detailed_placement

# CTS (Zero-skew for RT domain)
clock_tree_synthesis -root_buf BUF4 -sink_buf BUF1 -max_cap 0.05 -max_slew 0.1

# Routing
global_route
detailed_route

# Timing Optimization
repair_timing -max_slew -max_cap -max_fanout

# Signoff Reports
report_wns
report_tns
report_power
report_drc
report_lvs

# Output
write_def openroad/aegis_rt_top.def
if {[info exists ::env(TECH_GDS)]} {
    write_gds openroad/aegis_rt_top.gds -merge $::env(TECH_GDS)
}
puts "✓ PnR complete. Check signoff/ for reports."
