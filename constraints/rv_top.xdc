#set_property PACKAGE_PIN T5 [get_ports clk]
#set_property IOSTANDARD LVCMOS33 [get_ports clk]
#set_property PACKAGE_PIN T6 [get_ports LCD_A0]
#set_property PACKAGE_PIN U6 [get_ports LCD_CS]
#set_property PACKAGE_PIN R7 [get_ports LCD_RST]
#set_property PACKAGE_PIN V6 [get_ports LCD_SCK]
#set_property PACKAGE_PIN U9 [get_ports LCD_SDA]
#set_property PACKAGE_PIN K2 [get_ports LED_0]
#set_property PACKAGE_PIN P15 [get_ports rst_n]
#set_property IOSTANDARD LVCMOS33 [get_ports LCD_A0]
#set_property IOSTANDARD LVCMOS33 [get_ports LCD_CS]
#set_property IOSTANDARD LVCMOS33 [get_ports LCD_RST]
#set_property IOSTANDARD LVCMOS33 [get_ports LCD_SCK]
#set_property IOSTANDARD LVCMOS33 [get_ports LCD_SDA]
#set_property IOSTANDARD LVCMOS33 [get_ports LED_0]
#set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
#set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
#set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
#set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
#connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
# -----------------------------------------------------------------------------
# Xilinx Design Constraints (XDC) for 7-Segment Display on rv_top module
# -----------------------------------------------------------------------------

# Set the package pins and I/O standards for all 7-segment display outputs.
# IOSTANDARD is set to LVCMOS33 as a common standard for general I/O.

# -----------------------------------------------------------------------------
# Group 1: 7-Segment Display - Digits DN0_K1 to DN0_K4
# -----------------------------------------------------------------------------

# Segment A0-G0, DP0
set_property PACKAGE_PIN B4 [get_ports A0]
set_property IOSTANDARD LVCMOS33 [get_ports A0]
set_property PACKAGE_PIN A4 [get_ports B0]
set_property IOSTANDARD LVCMOS33 [get_ports B0]
set_property PACKAGE_PIN A3 [get_ports C0]
set_property IOSTANDARD LVCMOS33 [get_ports C0]
set_property PACKAGE_PIN B1 [get_ports D0]
set_property IOSTANDARD LVCMOS33 [get_ports D0]
set_property PACKAGE_PIN A1 [get_ports E0]
set_property IOSTANDARD LVCMOS33 [get_ports E0]
set_property PACKAGE_PIN B3 [get_ports F0]
set_property IOSTANDARD LVCMOS33 [get_ports F0]
set_property PACKAGE_PIN B2 [get_ports G0]
set_property IOSTANDARD LVCMOS33 [get_ports G0]
set_property PACKAGE_PIN D5 [get_ports DP0]
set_property IOSTANDARD LVCMOS33 [get_ports DP0]

# Digit Enables DN0_K1-K4
set_property PACKAGE_PIN G2 [get_ports DN0_K1]
set_property IOSTANDARD LVCMOS33 [get_ports DN0_K1]
set_property PACKAGE_PIN C2 [get_ports DN0_K2]
set_property IOSTANDARD LVCMOS33 [get_ports DN0_K2]
set_property PACKAGE_PIN C1 [get_ports DN0_K3]
set_property IOSTANDARD LVCMOS33 [get_ports DN0_K3]
set_property PACKAGE_PIN H1 [get_ports DN0_K4]
set_property IOSTANDARD LVCMOS33 [get_ports DN0_K4]

# -----------------------------------------------------------------------------
# Group 2: 7-Segment Display - Digits DN1_K1 to DN1_K4
# -----------------------------------------------------------------------------

# Segment A1-G1, DP1
set_property PACKAGE_PIN D4 [get_ports A1]
set_property IOSTANDARD LVCMOS33 [get_ports A1]
set_property PACKAGE_PIN E3 [get_ports B1]
set_property IOSTANDARD LVCMOS33 [get_ports B1]
set_property PACKAGE_PIN D3 [get_ports C1]
set_property IOSTANDARD LVCMOS33 [get_ports C1]
set_property PACKAGE_PIN F4 [get_ports D1]
set_property IOSTANDARD LVCMOS33 [get_ports D1]
set_property PACKAGE_PIN F3 [get_ports E1]
set_property IOSTANDARD LVCMOS33 [get_ports E1]
set_property PACKAGE_PIN E2 [get_ports F1]
set_property IOSTANDARD LVCMOS33 [get_ports F1]
set_property PACKAGE_PIN D2 [get_ports G1]
set_property IOSTANDARD LVCMOS33 [get_ports G1]
set_property PACKAGE_PIN H2 [get_ports DP1]
set_property IOSTANDARD LVCMOS33 [get_ports DP1]

# Digit Enables DN1_K1-K4
set_property PACKAGE_PIN G1 [get_ports DN1_K1]
set_property IOSTANDARD LVCMOS33 [get_ports DN1_K1]
set_property PACKAGE_PIN F1 [get_ports DN1_K2]
set_property IOSTANDARD LVCMOS33 [get_ports DN1_K2]
set_property PACKAGE_PIN E1 [get_ports DN1_K3]
set_property IOSTANDARD LVCMOS33 [get_ports DN1_K3]
set_property PACKAGE_PIN G6 [get_ports DN1_K4]
set_property IOSTANDARD LVCMOS33 [get_ports DN1_K4]

#-----------------------------------------------------------------------------------------------------
#System Clock and Reset (You need to connect these to your top-level module)
#-----------------------------------------------------------------------------------------------------
set_property PACKAGE_PIN T5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PACKAGE_PIN K2 [get_ports LED_0]
set_property IOSTANDARD LVCMOS33 [get_ports LED_0]

set_property PACKAGE_PIN R15 [get_ports btn_commit]
set_property IOSTANDARD LVCMOS33 [get_ports btn_commit]
set_property PACKAGE_PIN U4 [get_ports btn_down]
set_property IOSTANDARD LVCMOS33 [get_ports btn_down]
set_property IOSTANDARD LVCMOS33 [get_ports btn_left]
set_property PACKAGE_PIN V1 [get_ports btn_right]
set_property PACKAGE_PIN R11 [get_ports btn_left]
set_property PACKAGE_PIN R17 [get_ports btn_up]
set_property IOSTANDARD LVCMOS33 [get_ports btn_up]
set_property IOSTANDARD LVCMOS33 [get_ports btn_right]


# VGA Red Signals (4-bit)
set_property PACKAGE_PIN F5 [get_ports vga_r[0]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_r[0]]
set_property PACKAGE_PIN C6 [get_ports vga_r[1]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_r[1]]
set_property PACKAGE_PIN C5 [get_ports vga_r[2]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_r[2]]
set_property PACKAGE_PIN B7 [get_ports vga_r[3]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_r[3]]

# VGA Green Signals (4-bit)
set_property PACKAGE_PIN B6 [get_ports vga_g[0]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_g[0]]
set_property PACKAGE_PIN A6 [get_ports vga_g[1]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_g[1]]
set_property PACKAGE_PIN A5 [get_ports vga_g[2]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_g[2]]
set_property PACKAGE_PIN D8 [get_ports vga_g[3]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_g[3]]

# VGA Blue Signals (4-bit)
set_property PACKAGE_PIN C7 [get_ports vga_b[0]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_b[0]]
set_property PACKAGE_PIN E6 [get_ports vga_b[1]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_b[1]]
set_property PACKAGE_PIN E5 [get_ports vga_b[2]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_b[2]]
set_property PACKAGE_PIN E7 [get_ports vga_b[3]]
set_property IOSTANDARD LVCMOS33 [get_ports vga_b[3]]

# HSYNC and VSYNC Signals
set_property PACKAGE_PIN D7 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property PACKAGE_PIN C4 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

# The clock and reset pins need to be set in your main project file
# set_property PACKAGE_PIN E3 [get_ports clk_in]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_in]
# set_property PACKAGE_PIN C3 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]