# FlashAttention STA Script
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/asap7sc7p5t_27_SL_0.70V_25C.lib
read_verilog synth/netlist_asap7.v
link_design fa_top
read_sdc constraints/flashattention.sdc

# Check timing
check_setup -verbose

# Report timing
report_checks -path_delay max -max_paths 10
report_checks -path_delay min -max_paths 10

# Report design stats
report_design_area

# Report power
report_power

exit
