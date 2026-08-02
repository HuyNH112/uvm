# ============================================================
# int_waveform.do - Waveform Trace Configuration for int.do
# Purpose: Auto-load all verification signals into ModelSim/QuestaSim
# Usage: vsim -do "int_waveform.do" work.int_full_integration_tb
# Date: 30 July 2026
# ============================================================

# ============================================================
# VIEW SETUP
# ============================================================
view wave
wave zoom fit

# ============================================================
# GROUP 1: CLOCK & RESET (Control)
# ============================================================
add wave -noupdate -divider "CONTROL SIGNALS"
add wave -noupdate -color Gold sim:/int_full_integration_tb/clk_i
add wave -noupdate -color Gold sim:/int_full_integration_tb/rst_ni

# ============================================================
# GROUP 2: OBI INSTRUCTION INTERFACE
# ============================================================
add wave -noupdate -divider "OBI INSTRUCTION PATH"
add wave -noupdate -format Logic -color {Light Blue} sim:/int_full_integration_tb/obi_instr_req
add wave -noupdate -format Logic -color {Light Blue} sim:/int_full_integration_tb/obi_instr_gnt
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/obi_instr_addr
add wave -noupdate -format Logic -color {Light Green} sim:/int_full_integration_tb/obi_instr_rvalid
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/obi_instr_rdata

# ============================================================
# GROUP 3: OBI DATA INTERFACE (Request)
# ============================================================
add wave -noupdate -divider "OBI DATA PATH - REQUEST"
add wave -noupdate -format Logic -color {Light Cyan} sim:/int_full_integration_tb/obi_data_req
add wave -noupdate -format Logic -color {Light Cyan} sim:/int_full_integration_tb/obi_data_gnt
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/obi_data_addr
add wave -noupdate -format Logic -color Magenta sim:/int_full_integration_tb/obi_data_we
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/obi_data_be
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/obi_data_wdata

# ============================================================
# GROUP 4: OBI DATA INTERFACE (Response)
# ============================================================
add wave -noupdate -divider "OBI DATA PATH - RESPONSE"
add wave -noupdate -format Logic -color {Light Green} sim:/int_full_integration_tb/obi_data_rvalid
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/obi_data_rdata

# ============================================================
# GROUP 5: AXI4 READ ADDRESS CHANNEL (AR)
# ============================================================
add wave -noupdate -divider "AXI4 READ ADDRESS CHANNEL (AR)"
add wave -noupdate -format Logic -color {Light Coral} sim:/int_full_integration_tb/axi_arvalid
add wave -noupdate -format Logic -color {Light Coral} sim:/int_full_integration_tb/axi_arready
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/axi_araddr
add wave -noupdate -format Unsigned -radix unsigned sim:/int_full_integration_tb/axi_arsize
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_arburst
add wave -noupdate -format Unsigned -radix unsigned sim:/int_full_integration_tb/axi_arlen
add wave -noupdate -format Unsigned -radix unsigned -color Yellow sim:/int_full_integration_tb/axi_arid
add wave -noupdate -format Logic sim:/int_full_integration_tb/axi_arlock
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_arcache
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_arprot

# ============================================================
# GROUP 6: AXI4 READ DATA CHANNEL (R)
# ============================================================
add wave -noupdate -divider "AXI4 READ DATA CHANNEL (R)"
add wave -noupdate -format Logic -color {Light Coral} sim:/int_full_integration_tb/axi_rvalid
add wave -noupdate -format Logic -color {Light Coral} sim:/int_full_integration_tb/axi_rready
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/axi_rdata
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_rresp
add wave -noupdate -format Logic sim:/int_full_integration_tb/axi_rlast
add wave -noupdate -format Unsigned -radix unsigned -color Yellow sim:/int_full_integration_tb/axi_rid

# ============================================================
# GROUP 7: AXI4 WRITE ADDRESS CHANNEL (AW)
# ============================================================
add wave -noupdate -divider "AXI4 WRITE ADDRESS CHANNEL (AW)"
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_awvalid
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_awready
add wave -noupdate -format Hex -radix hexadecimal sim:/int_full_integration_tb/axi_awaddr
add wave -noupdate -format Unsigned -radix unsigned sim:/int_full_integration_tb/axi_awsize
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_awburst
add wave -noupdate -format Unsigned -radix unsigned sim:/int_full_integration_tb/axi_awlen
add wave -noupdate -format Unsigned -radix unsigned -color Yellow sim:/int_full_integration_tb/axi_awid
add wave -noupdate -format Logic sim:/int_full_integration_tb/axi_awlock
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_awcache
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_awprot
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_awatop

# ============================================================
# GROUP 8: AXI4 WRITE DATA CHANNEL (W) - CRITICAL FOR WIDTH CONVERSION
# ============================================================
add wave -noupdate -divider "AXI4 WRITE DATA CHANNEL (W) [DATA WIDTH CONVERSION]"
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_wvalid
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_wready
add wave -noupdate -format Hex -radix hexadecimal -color Cyan sim:/int_full_integration_tb/axi_wdata
add wave -noupdate -format Binary -radix binary -color Cyan sim:/int_full_integration_tb/axi_wstrb
add wave -noupdate -format Logic sim:/int_full_integration_tb/axi_wlast

# ============================================================
# GROUP 9: AXI4 WRITE RESPONSE CHANNEL (B)
# ============================================================
add wave -noupdate -divider "AXI4 WRITE RESPONSE CHANNEL (B)"
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_bvalid
add wave -noupdate -format Logic -color {Light Sea Green} sim:/int_full_integration_tb/axi_bready
add wave -noupdate -format Binary -radix binary sim:/int_full_integration_tb/axi_bresp
add wave -noupdate -format Unsigned -radix unsigned -color Yellow sim:/int_full_integration_tb/axi_bid

# ============================================================
# CONFIGURATION
# ============================================================

# Set zoom level for readability
configure wave -timelineunits ns
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -gridperiod 100ns

# Set time display format
configure wave -timeoffset 0ns
configure wave -timeobjectmultiply 1ns

# Scroll to beginning
bookmark add wave 0

puts "╔════════════════════════════════════════════════════════╗"
puts "║  WAVEFORM CONFIGURATION LOADED                         ║"
puts "║  File: int_waveform.do                                 ║"
puts "║  Signals: 58 (Clock, OBI, AXI4 all 5 channels)        ║"
puts "║                                                        ║"
puts "║  Key Trace Groups:                                    ║"
puts "║  • OBI Instruction Path (5 signals)                  ║"
puts "║  • OBI Data Path (7 signals request + 2 response)    ║"
puts "║  • AXI4 AR Channel (10 signals)                      ║"
puts "║  • AXI4 R Channel (6 signals)                        ║"
puts "║  • AXI4 AW Channel (11 signals)                      ║"
puts "║  • AXI4 W Channel (5 signals) [CRITICAL: WIDTH CONV] ║"
puts "║  • AXI4 B Channel (4 signals)                        ║"
puts "║  • Control (2 signals)                               ║"
puts "║                                                        ║"
puts "║  Critical Signal Highlights:                         ║"
puts "║  • IDs (Yellow): axi_arid, axi_rid, axi_awid, axi_bid║"
puts "║  • Data Width (Cyan): axi_wdata, axi_wstrb           ║"
puts "║  • Handshakes (Light Blue/Cyan): req/gnt signals     ║"
puts "║                                                        ║"
puts "║  Usage:                                              ║"
puts "║  run -all                                            ║"
puts "║  (waveform will auto-populate during simulation)    ║"
puts "║                                                        ║"
puts "║  View in GTKWave:                                    ║"
puts "║  gtkwave int_full_integration.vcd                    ║"
puts "║                                                        ║"
puts "╚════════════════════════════════════════════════════════╝"
