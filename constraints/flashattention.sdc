# FlashAttention Accelerator - SDC Constraints
# Target: 50MHz (20ns period)

# Clock definition
create_clock -name clk -period 20.0 [get_ports clk]

# Clock uncertainty
set_clock_uncertainty 0.5 [get_clocks clk]

# Input delays
set_input_delay -clock clk 2.0 [get_ports rst_n]
set_input_delay -clock clk 2.0 [get_ports {s_axil_awaddr[*]}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_awvalid}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_wdata[*]}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_wstrb[*]}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_wvalid}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_bready}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_araddr[*]}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_arvalid}]
set_input_delay -clock clk 2.0 [get_ports {s_axil_rready}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_awready}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_wready}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_bresp[*]}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_bvalid}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_arready}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_rdata[*]}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_rresp[*]}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_rlast}]
set_input_delay -clock clk 2.0 [get_ports {m_axi_rvalid}]

# Output delays
set_output_delay -clock clk 2.0 [get_ports {s_axil_awready}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_wready}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_bresp[*]}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_bvalid}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_arready}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_rdata[*]}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_rresp[*]}]
set_output_delay -clock clk 2.0 [get_ports {s_axil_rvalid}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_awaddr[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_awlen[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_awsize[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_awburst[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_awvalid}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_wdata[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_wstrb[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_wlast}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_wvalid}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_bready}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_araddr[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_arlen[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_arsize[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_arburst[*]}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_arvalid}]
set_output_delay -clock clk 2.0 [get_ports {m_axi_rready}]

# Async reset
set_false_path -from [get_ports rst_n]

# Drive strength
set_driving_cell -lib_cell INVx1 [get_ports clk]
set_driving_cell -lib_cell INVx1 [get_ports rst_n]

# Load
set_load 0.01 [all_outputs]

# Max fanout
set_max_fanout 10 [current_design]
