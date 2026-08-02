# run_icache_advanced_wave.do
# Run tc_icache_advanced với waveform chỉ 4 tín hiệu chính

vsim -voptargs=+acc work.tc_icache_advanced

# Add 4 tín hiệu chính để theo dõi I-Cache HIT/MISS
add wave -position insertpoint -color yellow sim:/tc_icache_advanced/instr_req
add wave -position insertpoint -color cyan sim:/tc_icache_advanced/instr_addr
add wave -position insertpoint -color lime sim:/tc_icache_advanced/cache_instr_rvalid
add wave -position insertpoint -color red sim:/tc_icache_advanced/cache_miss

# Expand waves để dễ nhìn
configure wave -namecolwidth 250
configure wave -valuecolwidth 80

# Run simulation
run -all
