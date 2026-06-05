# FlashAttention STA - OpenSTA
# Read liberty files
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib

# Read netlist
read_verilog synth/netlist_sta_bb.v

# Link design
link_design fa_top

# Read SDC
read_sdc constraints/flashattention.sdc

# Report timing
report_checks -path_delay max -corner tt_0p70v_25c

# Report design info
report_design_area

exit
