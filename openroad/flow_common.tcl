#===============================================================================
# AEGIS-RV OpenROAD Common Settings
# Target: SkyWater 130 / TSMC 130G / UMC 130nm
#===============================================================================

# PDK Configuration
set pdk_root $::env(PDK_ROOT)
set pdk $::env(PDK)
set std_cell_library $::env(STD_CELL_LIBRARY)

# Technology setup
source $pdk_root/$pdk/libs.tech/openroad/common/setup.tcl

# Design name
set design_name "aegis_rt_top"

# Layer configuration (SkyWater 130)
set metal_layers 5

# @SAFETY: RT domain clock — dedicated zero-skew tree
set rt_clock_name "i_clk"
set rt_clock_period 4.167  ;# 240 MHz

# Placement density
set placement_density 0.55

# Routing configuration
set routing_layer_min "metal1"
set routing_layer_max "metal5"

# @SAFETY: Safety-critical placement constraints
# TCLS voter must be placed adjacent to SMU
# ECC encoder must be placed adjacent to scratchpad banks

echo "✓ OpenROAD common settings loaded: PDK=$pdk, design=$design_name"
