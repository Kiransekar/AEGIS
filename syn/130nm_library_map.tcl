#===============================================================================
# AEGIS-RV 130nm Library Mapping
# Maps generic Yosys cells to target PDK standard cells
#===============================================================================

# SkyWater 130 HD (high-density) standard cell library
# Use only when PDK is available (make synth PDK=sky130)

if { [info exists ::env(PDK_ROOT) ] } {
    set pdk_root $::env(PDK_ROOT)
    set pdk $::env(PDK)
    set lib_name "sky130_fd_sc_hd"

    # Read Liberty timing
    read_liberty $pdk_root/$pdk/libs.ref/$lib_name/liberty/${lib_name}__tt_025C_1v80.lib

    # Read Verilog models for functional simulation
    read_verilog -lib $pdk_root/$pdk/libs.ref/$lib_name/verilog/${lib_name}.v

    # Map to technology
    dfflibmap -liberty $pdk_root/$pdk/libs.ref/$lib_name/liberty/${lib_name}__tt_025C_1v80.lib
    abc -liberty $pdk_root/$pdk/libs.ref/$lib_name/liberty/${lib_name}__tt_025C_1v80.lib

    echo "✓ Library mapping complete: $lib_name"
} else {
    echo "[WARN] PDK_ROOT not set — using generic cells (no timing data)"
    echo "       Set PDK_ROOT and PDK environment variables for technology mapping"
}
