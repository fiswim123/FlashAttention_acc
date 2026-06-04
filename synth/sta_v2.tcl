# FlashAttention STA Script
read_liberty /home/ghoti/Babel/libs/asap7/asap7sc7p5t_27/lib/asap7sc7p5t_27_SL_0.70V_25C.lib
read_verilog synth/netlist_asap7.v
link_design fa_top
read_sdc constraints/flashattention.sdc

# Check for setup violations
report_checks

# Summary
puts "=== Timing Summary ==="
puts "Design: flashattention"
puts "Clock: clk @ 50MHz (20ns)"
puts "End of STA"
exit
