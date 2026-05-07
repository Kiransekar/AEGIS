#===============================================================================
# AEGIS-RV OpenROAD Floorplan — RT Core Phase 2 (v2.0)
# Target: 130nm CMOS, 240 MHz
# Core area estimate: ~2.5 mm² (with MULDIV, FPU, Xdrone)
#===============================================================================

#--- Read synthesized netlist ---
read_db "syn/aegis_rt_core_phase2_syn.v"

#--- Initialize floorplan ---
# @SAFETY: Core dimensions must accommodate all Phase 2 modules
# MULDIV (2-4 cycle) + FPU (FTZ) + Xdrone (qmul/kalman) add ~40% area over Phase 1
initialize_floorplan \
    -die_area "0 0 2200 2200" \
    -core_area "20 20 2180 2180" \
    -site core_site

#--- Place macros (TCM banks) ---
# @SAFETY: TCM banks placed near core for 1-cycle access
place_macro -instance u_rt_domain/u_scratchpad/bank_0 \
    -location "200 200" \
    -orientation N
place_macro -instance u_rt_domain/u_scratchpad/bank_1 \
    -location "1200 200" \
    -orientation N

#--- Create voltage domains ---
# RT domain: always-on 1.2V
create_voltage_domain RT_CORE \
    -area "20 20 2180 2180"

#--- Place instances with timing constraints ---
# Critical path groups (Phase 2):
# 1. ALU → WB result (1 cycle, 4.167 ns)
# 2. FPU → WB result (1 cycle, 4.167 ns)
# 3. MULDIV → WB result (2-4 cycles, relaxed)
# 4. IRQ controller → PC mux (12 cycles, relaxed)
# 5. Xdrone qmul (2 cycles, 8.334 ns)
# 6. Xdrone kalman (4 cycles, 16.668 ns)

#--- Pin placement ---
# @SAFETY: Clock pin near PLL, reset near power-on-reset
set_pin_constraint -pin i_clk -edge left -offset 200
set_pin_constraint -pin i_rst_n -edge left -offset 400
set_pin_constraint -pin i_irq_pending[*] -edge top -offset 600
set_pin_constraint -pin o_axi_* -edge right

#--- Track creation ---
make_tracks

#--- Report ---
report_floorplan
