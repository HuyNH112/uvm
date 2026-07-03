# =============================================================================
# run_uvm.do - QuestaSim 23.3 compile & simulate script
# HPDcache UVM Testbench - cv32a6_imac_sv32
# RTL da duoc add vao project "uvm_hpdcache" qua create_dcache.do
# Run from: D:/HCMUS/UVM/
# =============================================================================

if {[file exists work]} {
    vdel -all -lib work
}
vlib work

# =============================================================================
# BUOC 1: Compile toan bo RTL da duoc add vao project (theo dung Order)
# =============================================================================
project compileall

# =============================================================================
# Include path cho hpdcache_typedef.svh / hpdcache_config.svh
# =============================================================================
set HPDCACHE_INC "D:/HCMUS/THESIS/cv-hpdcache-master/rtl/include"

# =============================================================================
# BUOC 2: Compile Interface (phu thuoc hpdcache_pkg + hpdcache_typedef.svh)
# =============================================================================
vlog -sv +incdir+. +incdir+sv +incdir+$HPDCACHE_INC tb/hpdcache_if.sv

# =============================================================================
# BUOC 3: Compile UVM Package (toan bo class: seq_item, drv, mon, sb, cov, env)
# =============================================================================
vlog -sv +incdir+. +incdir+sv +incdir+$HPDCACHE_INC sv/hpdcache_uvm_pkg.sv

# =============================================================================
# BUOC 4: Compile Hardware top (DUT instantiation + memory model)
# =============================================================================
vlog -sv +incdir+. +incdir+sv +incdir+$HPDCACHE_INC tb/hw_top.sv

# =============================================================================
# BUOC 5: Compile Testbench top (bao gom test_lib + base_test)
# =============================================================================
vlog -sv +incdir+. +incdir+sv +incdir+tb +incdir+$HPDCACHE_INC tb/tb_top.sv

# =============================================================================
# BUOC 6: Chay mo phong
# Doi +UVM_TESTNAME de chon test khac:
#   hpdcache_base_test       - Smoke test
#   hpdcache_rand_test       - Random test
#   hpdcache_store_load_test - Store-Load verification
#   hpdcache_stride_test     - Stride sequence (kich hoat prefetcher)
# =============================================================================
vsim -voptargs="+acc" \
     -L mtiUvm \
     work.tb_top \
     +UVM_TESTNAME=hpdcache_base_test \
     +UVM_VERBOSITY=UVM_LOW

run -all
