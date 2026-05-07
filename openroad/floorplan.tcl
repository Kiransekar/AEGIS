#===============================================================================
# AEGIS-RV OpenROAD Floorplan Script
# Target: SkyWater 130 / TSMC 130G
#===============================================================================

# Initialize floorplan
init_floorplan -utilization 0.45 -aspect_ratio 1.0 -core_space 20

# Create power domains
# @SAFETY: RT domain in dedicated corner for fault isolation
create_voltage_domain RT_DOMAIN -area {30 30 3000 3000}
create_voltage_domain SECURITY_DOMAIN -area {30 3100 3000 4500}

# Place macros
# @SAFETY: TCLS voter + SMU in isolated corner
place_macro -instance u_rt_domain.u_smu -location {50 50} -orientation R0
place_macro -instance u_rt_domain.u_power -location {50 200} -orientation R0

# Create placement blockages for safety-critical regions
create_placement_blockage -bbox {30 30 500 400} -type hard

# Create pin blockage for I/O placement
create_pin_blockage -bbox {0 0 50 5000} -type hard -layer metal3
create_pin_blockage -bbox {3000 0 3050 5000} -type hard -layer metal3

echo "✓ Floorplan complete"
