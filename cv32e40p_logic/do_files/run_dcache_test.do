do dcache_integration.do
compile -all
elaborate -all
vsim -c tc_hpdcache_basic_v2
run -all