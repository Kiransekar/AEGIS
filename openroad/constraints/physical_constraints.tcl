#===============================================================================
# AEGIS-RV Physical Constraints
# Blockages, keepouts, pin placement for 130nm
#===============================================================================

# Die area: 3.0 mm × 4.5 mm (RT domain only)
set die_area {0 0 3000 4500}

# Core area with margins
set core_area {30 30 2970 4470}

# @SAFETY: Placement blockage for safety-critical region
# SMU and power orchestrator must be in isolated corner
create_placement_blockage -bbox {30 30 500 500} -type hard

# @SAFETY: Keepout region around TCLS voter (prevent routing congestion)
create_placement_blockage -bbox {510 30 900 300} -type soft

# Pin placement
# Clock pins on left edge
set_pin_constraint -pins {i_clk i_rt_clk} -edge left -offset 100
# Reset pins on left edge
set_pin_constraint -pins {i_rst_n i_rt_rst_n} -edge left -offset 200
# AXI pins on right edge
set_pin_constraint -pins {o_axi_* i_axi_*} -edge right
# Interrupt pins on bottom edge
set_pin_constraint -pins {i_irq_pending[*]} -edge bottom
# Power domain pins on top edge
set_pin_constraint -pins {o_rt_* i_tcls_*} -edge top

echo "✓ Physical constraints loaded"
