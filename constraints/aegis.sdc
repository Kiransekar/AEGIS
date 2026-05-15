create_clock -name core_clk -period 10.0 [get_ports clk]
set_clock_uncertainty -setup 0.5 [get_clocks core_clk]
set_clock_uncertainty -hold 0.2 [get_clocks core_clk]

# I/O delays
set_input_delay -clock core_clk 2.0 [get_ports rst_n]
set_output_delay -clock core_clk 2.0 [get_ports {uart_tx gpio_out[*]}]

# Async reset
set_false_path -from [get_ports rst_n]
set_input_transition 0.1 [get_ports rst_n]
