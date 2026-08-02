# run_hpdcache_adapter_wave.do
# Run tc_hpdcache_basic_v2 với waveform chỉ OBI ↔ HPDCACHE signals

vsim -voptargs=+acc work.tc_hpdcache_basic_v2

# ===== OBI PATH (I-CACHE) =====
add wave -position insertpoint -color yellow sim:/tc_hpdcache_basic_v2/obi_instr_req
add wave -position insertpoint -color cyan sim:/tc_hpdcache_basic_v2/obi_instr_addr
add wave -position insertpoint -color lime sim:/tc_hpdcache_basic_v2/obi_instr_gnt
add wave -position insertpoint -color orange sim:/tc_hpdcache_basic_v2/obi_instr_rvalid

# ===== OBI PATH (D-CACHE) =====
add wave -position insertpoint -color yellow sim:/tc_hpdcache_basic_v2/obi_data_req
add wave -position insertpoint -color cyan sim:/tc_hpdcache_basic_v2/obi_data_addr
add wave -position insertpoint -color lime sim:/tc_hpdcache_basic_v2/obi_data_gnt
add wave -position insertpoint -color orange sim:/tc_hpdcache_basic_v2/obi_data_rvalid

# ===== HPDCACHE CORE SIGNALS (Optional - thấy adapter hoạt động) =====
add wave -position insertpoint -color red sim:/tc_hpdcache_basic_v2/hpd_core_req_valid
add wave -position insertpoint -color red sim:/tc_hpdcache_basic_v2/hpd_core_rsp_valid

# Configure waveform
configure wave -namecolwidth 300
configure wave -valuecolwidth 80

# Run simulation
run -all
