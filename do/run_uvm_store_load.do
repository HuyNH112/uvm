# =============================================================================
# run_uvm_store_load.do
# QuestaSim 23.3 Starter Edition — Compile + Simulate script
# Usage: do run_uvm_store_load.do
# TC 3.2: hpdcache_store_load_test — verify STORE→LOAD forwarding, PASS > 0
# =============================================================================

# --- Test name ---
set TEST_NAME "hpdcache_store_load_test"

# --- Path configuration ---
set UVM_HOME   "C:/altera/23.3/questa_fse/verilog_src/uvm-1.1d"
set HPDCACHE   "D:/HCMUS/THESIS/cv-hpdcache-master"
set TB_DIR     "D:/HCMUS/UVM"
set HPDCACHE_INC "$HPDCACHE/rtl/include"

# --- Clean & recreate work library ---
if {[file exists work]} { vdel -all -lib work }
vlib work

echo "=== Step 1: Compile RTL (project files) ==="
# Compile từ QuestaSim project (57 RTL files, đúng thứ tự)
project compileall
if {[catch {project compileall} err]} {
    echo "RTL compile error: $err"
    return
}

echo "=== Step 2: Compile Interface ==="
vlog -sv -work work \
    +incdir+. \
    +incdir+$TB_DIR/sv \
    +incdir+$TB_DIR/tb \
    +incdir+$HPDCACHE_INC \
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
    $TB_DIR/tb/hpdcache_if.sv

echo "=== Step 3: Compile UVM Package ==="
vlog -sv -work work \
    +incdir+. \
    +incdir+$TB_DIR/sv \
    +incdir+$TB_DIR/tb \
    +incdir+$HPDCACHE_INC \
    -L mtiUvm \
    $TB_DIR/sv/hpdcache_uvm_pkg.sv

echo "=== Step 4: Compile hw_top (DUT + Memory Model) ==="
vlog -sv -work work \
    +incdir+. \
    +incdir+$TB_DIR/sv \
    +incdir+$TB_DIR/tb \
    +incdir+$HPDCACHE_INC \
    $TB_DIR/tb/hw_top.sv

echo "=== Step 5: Compile tb_top (Tests + top) ==="
# QUAN TRỌNG: tb_top.sv include seq_lib → base_test → test_lib
vlog -sv -work work \
    +incdir+. \
    +incdir+$TB_DIR/sv \
    +incdir+$TB_DIR/tb \
    +incdir+$HPDCACHE_INC \
    -L mtiUvm \
    $TB_DIR/tb/tb_top.sv

echo "=== Step 6: Simulate test: $TEST_NAME ==="
vsim -voptargs="+acc=rn" \
     -L mtiUvm \
     -L work \
     work.tb_top \
     +UVM_TESTNAME=$TEST_NAME \
     +UVM_VERBOSITY=UVM_MEDIUM \
     -sv_seed random \
     -t 1ns

# Add waveforms (key signals cho debug)
add wave -divider "=== CLOCK / RESET ==="
add wave /tb_top/u_hw/clk
add wave /tb_top/u_hw/rst_n

add wave -divider "=== CORE REQUEST ==="
add wave /tb_top/u_hw/dut_if/core_req_valid_i
add wave /tb_top/u_hw/dut_if/core_req_ready_o
add wave -radix hex /tb_top/u_hw/dut_if/core_req_i
add wave -radix hex /tb_top/u_hw/dut_if/core_req_tag_i

add wave -divider "=== CORE RESPONSE ==="
add wave /tb_top/u_hw/dut_if/core_rsp_valid_o
add wave -radix hex /tb_top/u_hw/dut_if/core_rsp_o

add wave -divider "=== AXI READ ==="
add wave /tb_top/u_hw/dut_if/mem_req_read_valid_o
add wave /tb_top/u_hw/dut_if/mem_req_read_ready_i
add wave -radix hex /tb_top/u_hw/dut_if/mem_req_read_addr_o
add wave /tb_top/u_hw/dut_if/mem_resp_read_ready_o
add wave /tb_top/u_hw/dut_if/mem_resp_read_valid_i

add wave -divider "=== AXI WRITE ==="
add wave /tb_top/u_hw/dut_if/mem_req_write_valid_o
add wave /tb_top/u_hw/dut_if/mem_req_write_ready_i
add wave /tb_top/u_hw/dut_if/mem_resp_write_ready_o
add wave /tb_top/u_hw/dut_if/mem_resp_write_valid_i

add wave -divider "=== PERF EVENTS ==="
add wave /tb_top/u_hw/dut_if/evt_cache_read_miss_o
add wave /tb_top/u_hw/dut_if/evt_cache_write_miss_o
add wave /tb_top/u_hw/dut_if/evt_prefetch_req_o
add wave /tb_top/u_hw/dut_if/evt_stall_o
add wave /tb_top/u_hw/dut_if/wbuf_empty_o

run -all
wave zoom full