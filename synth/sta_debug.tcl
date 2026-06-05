read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib
read_verilog synth/netlist_sta_clean.v
link_design fa_top
read_sdc constraints/flashattention.sdc

# Check clocks
report_clocks

# Check if there are any cells
puts "Cell count: [sizeof_collection [get_cells]]"
puts "Pin count: [sizeof_collection [get_pins]]"
puts "Port count: [sizeof_collection [get_ports]]"

# Try to get timing paths
set paths [find_timing_paths -from clk -to clk]
puts "Paths found: [llength $paths]"

exit
