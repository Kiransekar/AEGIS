#===============================================================================
# AEGIS-RV Synthesis Script: TCLS Voter
# Module: tcls_voter
# Target: 130nm CMOS — timing-critical path (≤5 cycle quarantine)
#===============================================================================

# Read RTL
read_verilog -sv -defer rtl/core/tcls_voter.v
read_verilog -sv -defer rtl/core/tcls_mismatch_counter.v

# Elaborate
hierarchy -check -top tcls_voter

# Synthesize
synth -top tcls_voter

# Apply constraints & optimize
tcl syn/130nm_constraints.tcl
tcl syn/synth_common.tcl

# Reports
tee -o syn/reports/tcls_voter_area.rpt     print_stats
tee -o syn/reports/tcls_voter_timing.rpt    ltp
tee -o syn/reports/tcls_voter_check.rpt     check

# Output
write_verilog -noattr syn/core/tcls_voter_syn.v
write_json syn/core/tcls_voter.json

echo "✓ TCLS Voter synthesis complete"
