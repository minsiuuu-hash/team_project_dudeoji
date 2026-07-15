## MONITOR2 Basys3 constraints

set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports reset]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports start_btn]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports restart_btn]

# ## hit_btn[5:0] mapped to SW0..SW5 by default.
# set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[0]}]
# set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[1]}]
# set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[2]}]
# set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[3]}]
# set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[4]}]
# set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {hit_btn[5]}]

#Pmod Header JA
# set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports {hit_btn[0]}];#Sch name = JA1
# set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {hit_btn[1]}];#Sch name = JA2
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[0]}];#Sch name = JA3
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[1]}];#Sch name = JA4
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[2]}];#Sch name = JA7
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[3]}];#Sch name = JA8
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[4]}];#Sch name = JA9
set_property -dict { PACKAGE_PIN G3   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports {hit_btn[5]}];#Sch name = JA10

## UART inter-board link on JA.
## Wire MONITOR1 uart_tx -> MONITOR2 uart_rx_i and common GND.
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports uart_rx_i]
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]

## VGA connector.
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports {vga_red[0]}]
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS33 } [get_ports {vga_red[1]}]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports {vga_red[2]}]
set_property -dict { PACKAGE_PIN N19 IOSTANDARD LVCMOS33 } [get_ports {vga_red[3]}]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {vga_green[0]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {vga_green[1]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {vga_green[2]}]
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports {vga_green[3]}]
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports {vga_blue[0]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {vga_blue[1]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {vga_blue[2]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {vga_blue[3]}]
set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports h_sync]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports v_sync]

set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

