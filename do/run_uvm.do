# =============================================================================
# run_uvm.do — QuestaSim 23.3 Compile + Simulate (TCL String Fix)
# Usage: do run_uvm.do [test_name]
# =============================================================================

# Test name (default: core_basic_alu_ops, or: hpdcache_base_test)
if {[llength $argv] > 0} {
    set TEST_NAME [lindex $argv 0]
} else {
    set TEST_NAME "core_basic_alu_ops"
}

# Hardcoded paths (raw strings - no TCL escape interpretation)
set TB_DIR {D:/HCMUS/UVM/tb}
set SV_DIR {D:/HCMUS/UVM/sv}
set HPDCACHE_INC {D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include}
set CVA6_INC {D:/khoaluantotnghiep/cva6-master/core/include}

# Clean & recreate work library
if {[file exists work]} { vdel -all -lib work }
vlib work

echo "=== Step 1: Compile RTL (via project) ==="
project compileall

echo "=== Step 2a: Compile HPDcache Interface ==="
vlog -sv -work work \
    +incdir+. +incdir+$TB_DIR +incdir+$SV_DIR +incdir+$HPDCACHE_INC \
    +define+CONF_HPDCACHE_PA_WIDTH=56 \
    +define+CONF_HPDCACHE_WORD_WIDTH=64 \
    +define+CONF_HPDCACHE_SETS=64 \
    +define+CONF_HPDCACHE_WAYS=8 \
    +define+CONF_HPDCACHE_CL_WORDS=8 \
    +define+CONF_HPDCACHE_REQ_WORDS=2 \
    +define+CONF_HPDCACHE_REQ_TRANS_ID_WIDTH=6 \
    +define+CONF_HPDCACHE_REQ_SRC_ID_WIDTH=3 \
    +define+CONF_HPDCACHE_MEM_ADDR_WIDTH=56 \
    +define+CONF_HPDCACHE_MEM_ID_WIDTH=8 \
    +define+CONF_HPDCACHE_MEM_DATA_WIDTH=512 \
    +define+CONF_HPDCACHE_MSHR_SETS=4 \
    +define+CONF_HPDCACHE_MSHR_WAYS=4 \
    +define+CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD=1 \
    +define+CONF_HPDCACHE_MSHR_SETS_PER_RAM=4 \
    +define+CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE=1 \
    +define+CONF_HPDCACHE_MSHR_USE_REGBANK=0 \
    +define+CONF_HPDCACHE_VICTIM_SEL=0 \
    +define+CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD=1 \
    +define+CONF_HPDCACHE_DATA_SETS_PER_RAM=64 \
    +define+CONF_HPDCACHE_DATA_RAM_WBYTEENABLE=1 \
    +define+CONF_HPDCACHE_ACCESS_WORDS=2 \
    +define+CONF_HPDCACHE_WBUF_DIR_ENTRIES=4 \
    +define+CONF_HPDCACHE_WBUF_DATA_ENTRIES=4 \
    +define+CONF_HPDCACHE_WBUF_WORDS=2 \
    +define+CONF_HPDCACHE_WBUF_TIMECNT_WIDTH=4 \
    +define+CONF_HPDCACHE_RTAB_ENTRIES=4 \
    +define+CONF_HPDCACHE_FLUSH_ENTRIES=2 \
    +define+CONF_HPDCACHE_FLUSH_FIFO_DEPTH=2 \
    +define+CONF_HPDCACHE_CBUF_ENTRIES=4 \
    +define+CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH=0 \
    +define+CONF_HPDCACHE_REFILL_FIFO_DEPTH=2 \
    +define+CONF_HPDCACHE_WT_ENABLE=1 \
    +define+CONF_HPDCACHE_WB_ENABLE=1 \
    +define+CONF_HPDCACHE_LOW_LATENCY=0 \
    +define+CONF_HPDCACHE_ECC_ENABLE=0 \
    +define+CONF_HPDCACHE_ECC_SCRUBBER_ENABLE=0 \
    +define+HPDCACHE_ASSERT_OFF \
    $TB_DIR/hpdcache_if.sv

echo "=== Step 2b: Compile RVFI Interface ==="
vlog -sv -work work \
    +incdir+. +incdir+$TB_DIR +incdir+$SV_DIR +incdir+$CVA6_INC \
    $TB_DIR/cva6_rvfi_if.sv

echo "=== Step 3: Compile UVM Package ==="
vlog -sv -work work \
    +incdir+. +incdir+$TB_DIR +incdir+$SV_DIR +incdir+$HPDCACHE_INC \
    -L mtiUvm \
    $SV_DIR/hpdcache_uvm_pkg.sv

echo "=== Step 4: Compile hw_top ==="
vlog -sv -work work \
    +incdir+. +incdir+$TB_DIR +incdir+$SV_DIR +incdir+$HPDCACHE_INC +incdir+$CVA6_INC \
    $TB_DIR/hw_top.sv

echo "=== Step 5: Compile tb_top ==="
vlog -sv -work work \
    +incdir+. +incdir+$TB_DIR +incdir+$SV_DIR +incdir+$HPDCACHE_INC \
    -L mtiUvm \
    $TB_DIR/tb_top.sv

echo "=== Step 6: Simulate $TEST_NAME ==="
vsim -voptargs="+acc=rn" \
     -L mtiUvm \
     -L work \
     work.tb_top \
     +UVM_TESTNAME=$TEST_NAME \
     +UVM_VERBOSITY=UVM_MEDIUM \
     -sv_seed random \
     -t 1ns

run -all 300ms

echo ""
echo "=== Simulation Complete ==="
echo "Results: Check transcript.txt for errors and UVM report"