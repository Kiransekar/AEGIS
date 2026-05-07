#===============================================================================
# AEGIS-RV OpenROAD Placement Script
# @SAFETY: Safety-critical proximity constraints for TCLS + SMU
#===============================================================================

source openroad/flow_common.tcl

# Global placement
global_placement -density $placement_density -init_density_penalty 0.01

# @SAFETY: Place TCLS voter adjacent to SMU (fault isolation)
# Create placement region for safety-critical block
create_region -name safety_region -coordinate {30 30 500 500}
assign_inst_to_region u_rt_domain.u_smu safety_region
assign_inst_to_region u_rt_domain.u_power safety_region

# @SAFETY: Place ECC encoder adjacent to scratchpad banks
create_region -name ecc_region -coordinate {30 500 800 1500}
assign_inst_to_region u_rt_domain.u_scratchpad.u_ecc_encoder ecc_region

# Detailed placement
detailed_placement

# Check placement legality
check_placement

echo "✓ Placement complete"
