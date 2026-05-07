#===============================================================================
# AEGIS-RV OpenROAD Routing Script
# Global + detailed routing for 130nm
#===============================================================================

source openroad/flow_common.tcl

# Global routing
global_route -guide_file openroad/routes/global_route.guide \
    -congestion_iterations 100 \
    -overflow_margin 0.1

# Check congestion
check_route -congestion

# Detailed routing
detailed_route -output openroad/routes/ \
    -guide_file openroad/routes/global_route.guide \
    -or_route_aware

# Post-route optimization
set_propagated_clock [all_clocks]
set_timing_derate -early 0.95 -late 1.05
update_timing

# Check DRC
check_drc -output openroad/reports/drc.rpt

echo "✓ Routing complete"
