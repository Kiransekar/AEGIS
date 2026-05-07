#===============================================================================
# AEGIS-RV OpenROAD Power Grid Script
# Target: SkyWater 130
#===============================================================================

# Define power nets
# @SAFETY: RT domain has dedicated VDD/VSS for isolation
add_global_connection -net VDD -pin VDD -power -instance_pattern u_rt_domain.*
add_global_connection -net VSS -pin VSS -ground -instance_pattern u_rt_domain.*
add_global_connection -net VDD_SEC -pin VDD -power -instance_pattern u_security_domain.*
add_global_connection -net VSS -pin VSS -ground -instance_pattern u_security_domain.*

# Power grid parameters (130nm)
# M5: horizontal VDD, 0.5 µm width, 5 µm pitch
# M6: vertical VSS, 0.5 µm width, 5 µm pitch
initialize_floorplan -core_margins {20 20 20 20}

# Route power grid
# RT domain
place_pad -master sky130_fd_io__gpiov2 -instance vdd_rt_pad -location {100 0}
place_pad -master sky130_fd_io__gpiov2 -instance vss_rt_pad -location {200 0}

echo "✓ Power grid complete"
