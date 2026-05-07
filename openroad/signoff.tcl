#===============================================================================
# AEGIS-RV OpenROAD Signoff Script
# Generates: timing, power, area, DRC, LVS reports
#===============================================================================

# Timing Signoff
echo "=== Timing Signoff ==="
report_wns
report_tns
report_worst_slack -max
report_worst_slack -min
tee -o signoff/timing/wns.rpt report_wns
tee -o signoff/timing/tns.rpt report_tns
tee -o signoff/timing/setup.rpt report_checks -path_delay max
tee -o signoff/timing/hold.rpt report_checks -path_delay min

# Power Signoff
echo "=== Power Signoff ==="
tee -o signoff/power/total.rpt report_power
tee -o signoff/power/leakage.rpt report_power -leakage
tee -o signoff/power/switching.rpt report_power -switching

# Area Signoff
echo "=== Area Signoff ==="
tee -o signoff/area/summary.rpt print_stats

# DRC
echo "=== DRC Check ==="
tee -o signoff/drc/drc.rpt run_drc

# LVS
echo "=== LVS Check ==="
tee -o signoff/dft/lvs.rpt run_lvs

echo "✓ Signoff complete. Check signoff/ directory for reports."
