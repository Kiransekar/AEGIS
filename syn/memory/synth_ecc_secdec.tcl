#===============================================================================
# AEGIS-RV Synthesis Script: ECC SECDED-32
# Module: ecc_secdec_32
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
#===============================================================================

# Read RTL
read_verilog -sv -defer rtl/memory/ecc_secdec_32.v

# Elaborate
hierarchy -check -top ecc_secdec_32

# Synthesize
synth -top ecc_secdec_32

# Apply constraints & optimize
tcl syn/130nm_constraints.tcl
tcl syn/synth_common.tcl

# Reports
tee -o syn/reports/ecc_area.rpt     print_stats
tee -o syn/reports/ecc_timing.rpt   ltp
tee -o syn/reports/ecc_check.rpt    check

# Output
write_verilog -noattr syn/memory/ecc_secdec_32_syn.v
write_json syn/memory/ecc_secdec_32.json

echo "✓ ECC SECDED-32 synthesis complete"
