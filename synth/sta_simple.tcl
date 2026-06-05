read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/NLDM/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib
read_verilog synth/netlist_sta_clean.v
link_design fa_top
read_sdc constraints/flashattention.sdc

# Simple timing report
report_checks

exit
