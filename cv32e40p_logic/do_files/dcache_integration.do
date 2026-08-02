# ============================================================
# dcache_integration.do
# D-Cache Integration Test: Verify HPDcache responds to CPU requests
# Purpose: Check icache_rsp_valid=1 & dcache_rsp_valid=1
# Date: 29 July 2026
# Status: MINIMAL CORE FILES ONLY
# ============================================================

quit -sim
catch {project close}

set BASE_DIR      "D:/khoaluantotnghiep/project_dcache_integration"
set CV32E40P_DIR  "D:/khoaluantotnghiep/cv32e40p-master"
set ICACHE_DIR    "D:/khoaluantotnghiep/icache-master"
set HPDCACHE_DIR  "D:/khoaluantotnghiep/cv-hpdcache-master"
set INTEGRATION_DIR "D:/khoaluantotnghiep/integration"
set TESTBENCH_DIR "D:/khoaluantotnghiep/testbench"

file mkdir $BASE_DIR
project new $BASE_DIR dcache_integration work

# ====================== MINIMAL COMPILATION FOR DCACHE TEST ======================
# Phase 1:  Includes & HPDcache Typedefs (CRITICAL - FIRST)
# Phase 2:  HPDcache Package (core logic types)
# Phase 3:  OBI Adapter (already compiled successfully)
# Phase 4:  I-Cache RTL (essential for icache_rsp_valid)
# Phase 5:  HPDcache Core Logic (MINIMAL - only critical modules)
# Phase 6:  Testbench (check icache_rsp_valid=1, dcache_rsp_valid=1)
# =====================================================================

set file_list [list \
\
    "=== PHASE 1: INCLUDES & TYPEDEFS (CRITICAL - MUST BE FIRST) ===" \
    $HPDCACHE_DIR/rtl/include/hpdcache_typedef.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_config.svh \
\
    "=== PHASE 2: HPDCACHE PACKAGE (core logic types) ===" \
    $HPDCACHE_DIR/rtl/src/hpdcache_pkg.sv \
\
    "=== PHASE 3: OBI ADAPTER (342 LOC - already compiled) ===" \
    $INTEGRATION_DIR/obi_to_hpdcache_adapter.sv \
\
    "=== PHASE 4: I-CACHE RTL (16KB 4-way, 315 LOC + SRAM) ===" \
    $ICACHE_DIR/plru.sv \
    $ICACHE_DIR/cv32e40p_icache_pkg.sv \
    $ICACHE_DIR/cv32e40p_icache_data_mem.sv \
    $ICACHE_DIR/cv32e40p_icache_tag_mem.sv \
    $ICACHE_DIR/cv32e40p_icache.sv \
\
    "=== PHASE 5: HPDCACHE CORE LOGIC (MINIMAL - CRITICAL MODULES ONLY) ===" \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_1hot_to_binary.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_resize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_decoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_demux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fifo_reg.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_mux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_rrarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_resp_demux.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_core_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_miss_handler.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_wbuf.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_uncached.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_ctrl.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache.sv \
\
    "=== PHASE 6: TESTBENCH (D-Cache Integration Test) ===" \
    $TESTBENCH_DIR/tc_hpdcache_basic_v2.sv \
]

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  D-CACHE INTEGRATION TEST                                      ║"
puts "║  Objective: Verify icache_rsp_valid=1 & dcache_rsp_valid=1    ║"
puts "║  Strategy: Minimal core files + OBI adapter + stub cache      ║"
puts "╚════════════════════════════════════════════════════════════════╝"

set file_count 0
set phase_count 0
foreach f $file_list {
    if {[string match "==*" $f]} {
        puts $f
        incr phase_count
    } else {
        project addfile $f systemverilog
        incr file_count
    }
}

puts ""
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  COMPILATION SUMMARY                                          ║"
puts "╠════════════════════════════════════════════════════════════════╣"
puts "║                                                                ║"
puts "║  Total RTL Files: $file_count                                  ║"
puts "║  Total Phases:    $phase_count                                ║"
puts "║                                                                ║"
puts "║  Component Breakdown:                                          ║"
puts "║    Phase 1: HPDcache Typedefs         2 files (.svh)          ║"
puts "║    Phase 2: HPDcache Package          1 file (core types)     ║"
puts "║    Phase 3: OBI Adapter               1 file (v2 - compiled)  ║"
puts "║    Phase 4: I-Cache RTL               5 files (16KB 4-way)    ║"
puts "║    Phase 5: HPDcache Core            16 files (critical only) ║"
puts "║    Phase 6: Testbench                 1 file (integration)    ║"
puts "║                                                                ║"
puts "║  TEST OBJECTIVE:                                              ║"
puts "║    ✓ icache_rsp_valid = 1 → I-Cache hoạt động                ║"
puts "║    ✓ dcache_rsp_valid = 1 → D-Cache hoạt động                ║"
puts "║    ✓ Both respond with data → HPDcache integrated             ║"
puts "║                                                                ║"
puts "║  SUCCESS CRITERIA:                                            ║"
puts "║    ✓ Compilation succeeds (26 RTL files)                      ║"
puts "║    ✓ Adapter instantiates correctly                           ║"
puts "║    ✓ PHASE 1 PASS: I-Cache request → response                ║"
puts "║    ✓ PHASE 2 PASS: D-Cache request → response                ║"
puts "║    ✓ PHASE 3 PASS: Concurrent requests → both respond        ║"
puts "║                                                                ║"
puts "║  NEXT STEPS:                                                  ║"
puts "║    1. compile -all                                             ║"
puts "║    2. elaborate -all                                           ║"
puts "║    3. vsim -c tc_hpdcache_basic_v2                             ║"
puts "║    4. run -all                                                 ║"
puts "║                                                                ║"
puts "║  Status: ✅ READY FOR COMPILATION                              ║"
puts "║                                                                ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""
