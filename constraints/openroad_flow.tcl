read_lef /opt/pdk/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef
read_lef /opt/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_liberty /opt/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog outputs/aegis_rv_syn.v
link_design aegis_rv_core
read_sdc constraints/aegis.sdc

initialize_floorplan -site_name sky130_fd_sc_hd -core_margin 10 -aspect_ratio 1.0 -utilization 0.40
place_pins -hor_layers met2 -ver_layers met3
global_place
detailed_place
clock_tree_synthesis -root_buf CLKBUF -buf_list CLKBUF -sink_buf CLKBUF
detailed_clock_route
global_route
detailed_route
filler_placement sky130_fd_sc_hd__fill*
write_def outputs/aegis_rv.def
write_sdf outputs/aegis_rv.sdf
