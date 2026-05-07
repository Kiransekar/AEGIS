#===============================================================================
# AEGIS-RV Common Synthesis Settings
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
#===============================================================================

# Process & optimize
proc
opt -fast
memory -nomap
opt -fast

# Technology mapping (if PDK library is available)
if {[info exists ::env(STD_CELL_LIBRARY)]} {
    set PDK_LIB "$::env(STD_CELL_LIBRARY)/typ/liberty/sky130_fd_sc_hd__tt_025C_1v20.lib"
    if {[file exists $PDK_LIB]} {
        abc9 -liberty $PDK_LIB
        dfflibmap -liberty $PDK_LIB
        abc9 -liberty $PDK_LIB
    }
}

# Memory mapping (TCM banks)
memory_map
opt -fast

# Post-mapping optimization
opt -fast -area

# Clean up
clean
