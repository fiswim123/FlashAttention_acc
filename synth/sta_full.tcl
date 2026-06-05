# FlashAttention - Full STA with ASAP7 NLDM

# Read liberty files
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_SEQ_SRAM_TT_nldm_220123.lib

# Read netlist
read_verilog synth/netlist_full.v

# Link design
link_design fa_top

# Read constraints
read_sdc constraints/flashattention.sdc

# Report timing
report_checks

# Report design info
puts "=== Design Statistics ==="
puts "Cells: [sizeof_collection [get_cells]]"
puts "Nets: [sizeof_collection [get_nets]]"
puts "Ports: [sizeof_collection [get_ports]]"

exit
