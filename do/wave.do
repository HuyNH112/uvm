# ============================================================
# wave.do - HPDcache Waveform & Testcase Verification Script
# Purpose: Add wave signals and verify cache testcase correctness
# Version: 1.0
# Date: 31 July 2026
# Strategy: Phase 1 → Phase 2 → Phase 3 verification
# ============================================================

# NOTE: This script runs AFTER simulation has elaborated tb_top
# Usage: do wave.do

puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║      HPDcache Waveform & Testcase Verification                   ║"
puts "║      Phase-based testing: Phase 1 → Phase 2 → Phase 3            ║"
puts "║      Date: 31 July 2026                                          ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"
puts ""

# =====================================================================
# SECTION 1: CLOCK & RESET SIGNALS
# =====================================================================
puts "Adding clock & reset signals..."

add wave -divider "===== CLOCK / RESET ====="
add wave -label "clk" /tb_top/u_hw/clk
add wave -label "rst_n" /tb_top/u_hw/rst_n

# =====================================================================
# SECTION 2: CORE REQUEST INTERFACE
# Purpose: Monitor request handshaking from core to cache
# Check: valid/ready protocol, request data validity
# =====================================================================
puts "Adding core request signals..."

add wave -divider "===== CORE REQUEST (Core -> Cache) ====="
add wave -label "core_req_valid_i" /tb_top/u_hw/hpdcache_if/core_req_valid_i
add wave -label "core_req_ready_o" /tb_top/u_hw/hpdcache_if/core_req_ready_o
add wave -radix hex -label "core_req_i[addr]" /tb_top/u_hw/hpdcache_if/core_req_i
add wave -radix hex -label "core_req_i[data]" /tb_top/u_hw/hpdcache_if/core_req_i
add wave -radix hex -label "core_req_tag_i[tid]" /tb_top/u_hw/hpdcache_if/core_req_tag_i

# =====================================================================
# SECTION 3: CORE RESPONSE INTERFACE
# Purpose: Monitor response handshaking from cache to core
# Check: response valid, response data, TID correlation
# =====================================================================
puts "Adding core response signals..."

add wave -divider "===== CORE RESPONSE (Cache -> Core) ====="
add wave -label "core_rsp_valid_o" /tb_top/u_hw/hpdcache_if/core_rsp_valid_o
add wave -radix hex -label "core_rsp_o[data]" /tb_top/u_hw/hpdcache_if/core_rsp_o
add wave -radix hex -label "core_rsp_o[tid]" /tb_top/u_hw/hpdcache_if/core_rsp_o

# =====================================================================
# SECTION 4: AXI READ INTERFACE (L2 Memory)
# Purpose: Monitor memory read requests and responses
# Check: Read arbitration, memory latency, data flow
# =====================================================================
puts "Adding AXI read interface signals..."

add wave -divider "===== AXI READ (Cache -> L2 Mem) ====="
add wave -label "mem_req_read_valid_o" /tb_top/u_hw/hpdcache_if/mem_req_read_valid_o
add wave -label "mem_req_read_ready_i" /tb_top/u_hw/hpdcache_if/mem_req_read_ready_i
add wave -radix hex -label "mem_req_read_addr_o" /tb_top/u_hw/hpdcache_if/mem_req_read_addr_o
add wave -label "mem_resp_read_valid_i" /tb_top/u_hw/hpdcache_if/mem_resp_read_valid_i
add wave -label "mem_resp_read_ready_o" /tb_top/u_hw/hpdcache_if/mem_resp_read_ready_o
add wave -radix hex -label "mem_resp_read_data_i" /tb_top/u_hw/hpdcache_if/mem_resp_read_data_i

# =====================================================================
# SECTION 5: AXI WRITE INTERFACE (L2 Memory)
# Purpose: Monitor memory write requests (write-back)
# Check: Write arbitration, write data, write responses
# =====================================================================
puts "Adding AXI write interface signals..."

add wave -divider "===== AXI WRITE (Cache -> L2 Mem) ====="
add wave -label "mem_req_write_valid_o" /tb_top/u_hw/hpdcache_if/mem_req_write_valid_o
add wave -label "mem_req_write_ready_i" /tb_top/u_hw/hpdcache_if/mem_req_write_ready_i
add wave -radix hex -label "mem_req_write_addr_o" /tb_top/u_hw/hpdcache_if/mem_req_write_addr_o
add wave -radix hex -label "mem_req_write_data_o" /tb_top/u_hw/hpdcache_if/mem_req_write_data_o
add wave -label "mem_resp_write_valid_i" /tb_top/u_hw/hpdcache_if/mem_resp_write_valid_i
add wave -label "mem_resp_write_ready_o" /tb_top/u_hw/hpdcache_if/mem_resp_write_ready_o

# =====================================================================
# SECTION 6: PERFORMANCE EVENTS
# Purpose: Track cache events (hits, misses, prefetch activity)
# Check: Event generation, event counting, performance metrics
# =====================================================================
puts "Adding performance event signals..."

add wave -divider "===== PERFORMANCE EVENTS ====="
add wave -label "evt_cache_read_miss_o" /tb_top/u_hw/hpdcache_if/evt_cache_read_miss_o
add wave -label "evt_cache_write_miss_o" /tb_top/u_hw/hpdcache_if/evt_cache_write_miss_o
add wave -label "evt_prefetch_req_o" /tb_top/u_hw/hpdcache_if/evt_prefetch_req_o
add wave -label "evt_stall_o" /tb_top/u_hw/hpdcache_if/evt_stall_o
add wave -label "wbuf_empty_o" /tb_top/u_hw/hpdcache_if/wbuf_empty_o

# =====================================================================
# SECTION 7: ZOOM & TIMESTAMP
# =====================================================================
puts ""
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║  Waveform Setup Complete - Ready for testcase verification      ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"
puts ""

wave zoom full
configure wave -timelineunits ns

# =====================================================================
# VERIFICATION CHECKLIST FOR EACH TESTCASE
# =====================================================================

puts "════════════════════════════════════════════════════════════════════"
puts "  TESTCASE VERIFICATION CHECKLIST - Phase 1 (Basic Tests)"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  TEST: tc_d_01_test (D-Cache Basic)"
puts "  ─────────────────────────────────"
puts ""
puts "  ✓ CHECK 1: Valid/Ready Handshaking"
puts "    • core_req_valid_i goes HIGH"
puts "    • core_req_ready_o goes HIGH within 1-2 cycles"
puts "    • Request held until grant (valid stays HIGH)"
puts "    • Byte Enable (BE) is non-zero for write operations"
puts ""
puts "  ✓ CHECK 2: Request Data"
puts "    • core_req_i contains correct address"
puts "    • core_req_i contains correct write data (for STORE)"
puts "    • core_req_tag_i[tid] is unique per transaction"
puts ""
puts "  ✓ CHECK 3: Response Handshaking"
puts "    • core_rsp_valid_o goes HIGH 2-3 cycles after request"
puts "    • Response latency is CONSTANT (cache hits ~3 cycles)"
puts "    • Response data contains requested value"
puts ""
puts "  ✓ CHECK 4: TID Correlation"
puts "    • core_rsp_o[tid] MATCHES core_req_tag_i[tid] sent earlier"
puts "    • Response appears in order of requests (FIFO behavior)"
puts ""
puts "  ✓ CHECK 5: Cold Miss Behavior (First Access)"
puts "    • First LOAD to new address: core_rsp latency LONGER (~20 cycles)"
puts "    • evt_cache_read_miss_o pulses HIGH"
puts "    • mem_req_read_valid_o goes HIGH (L2 memory request)"
puts "    • mem_resp_read_valid_i goes HIGH after memory delay"
puts ""
puts "  ✓ CHECK 6: Cache Hit (Repeat Access)"
puts "    • Second LOAD to same address: core_rsp latency SHORT (~3 cycles)"
puts "    • evt_cache_read_miss_o stays LOW"
puts "    • mem_req_read_valid_o stays LOW (no L2 request)"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts "  TESTCASE VERIFICATION - Phase 2 (Advanced Tests)"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  TEST: tc_d_02_test (D-Cache Advanced Patterns)"
puts "  ──────────────────────────────────────────────"
puts ""
puts "  ✓ CHECK 7: Concurrent Requests (Multiple Outstanding)"
puts "    • Multiple core_req_valid_i pulses while previous response pending"
puts "    • core_req_ready_o handles request pipelining"
puts "    • Each response TID matches its corresponding request"
puts ""
puts "  ✓ CHECK 8: Write-back to Memory"
puts "    • Dirty cache line eviction triggers write"
puts "    • mem_req_write_valid_o goes HIGH"
puts "    • mem_req_write_data_o contains cache line data"
puts "    • mem_resp_write_valid_i acknowledges write"
puts ""
puts "  TEST: tc_int_01_test (Integration - I-Cache + D-Cache)"
puts "  ───────────────────────────────────────────────────────"
puts ""
puts "  ✓ CHECK 9: Dual Request Routing (SID differentiation)"
puts "    • Instruction fetches and data loads run concurrently"
puts "    • Both caches respond independently"
puts "    • No interference between I-Cache and D-Cache"
puts ""
puts "  ✓ CHECK 10: Shared L2 Memory Arbitration"
puts "    • Both I-Cache and D-Cache share L2 interface"
puts "    • Memory requests arbitrated fairly (round-robin or priority)"
puts "    • No deadlock or starvation"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts "  TESTCASE VERIFICATION - Phase 3 (Stress & Prefetch)"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  TEST: tc_p_01_test (Prefetcher Basic)"
puts "  ──────────────────────────────────────"
puts ""
puts "  ✓ CHECK 11: Prefetch Trigger Detection"
puts "    • Access pattern triggers prefetch (e.g., strided accesses)"
puts "    • evt_prefetch_req_o pulses HIGH"
puts "    • Prefetch address is predictable (e.g., next cacheline)"
puts ""
puts "  ✓ CHECK 12: Prefetch Accuracy"
puts "    • Prefetch data arrives BEFORE core requests it (ideally)"
puts "    • Prefetch misses don't waste bandwidth (selective prefetch)"
puts ""
puts "  TEST: tc_d_03_test (D-Cache Stress - High Traffic)"
puts "  ───────────────────────────────────────────────────"
puts ""
puts "  ✓ CHECK 13: Sustained Throughput"
puts "    • core_req_ready_o stays HIGH (no backpressure stalls)"
puts "    • Response rate = Request rate (sustained throughput)"
puts "    • No timeout or deadlock"
puts ""
puts "  ✓ CHECK 14: Memory Bandwidth Saturation"
puts "    • mem_req_read_valid_o stays HIGH continuously"
puts "    • mem_resp_read_valid_i appears regularly (pipeline filled)"
puts "    • L2 memory keeps cache supplied with data"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts "  WAVEFORM INSPECTION TIPS"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  1. ZOOM to Region of Interest:"
puts "     - Right-click waveform → Zoom → Fit"
puts "     - Or use scroll wheel to zoom in/out"
puts ""
puts "  2. MEASURE Delays:"
puts "     - Click on rising edge of valid_i"
puts "     - Drag to rising edge of ready_o (or rsp_valid_o)"
puts "     - Window status bar shows delay"
puts ""
puts "  3. TRACK Transaction:"
puts "     - Write down core_req_tag_i[tid] value"
puts "     - Find matching core_rsp_o[tid] in response wave"
puts "     - Verify timing and data correctness"
puts ""
puts "  4. COUNT Events:"
puts "     - Scroll through wave and count evt_cache_read_miss_o pulses"
puts "     - For tc_d_01_test: expect ~50% misses (cold misses early)"
puts ""
puts "  5. DETECT Protocol Violations:"
puts "    ✗ ERROR: core_req_valid_i HIGH but core_req_ready_o LOW > 10 cycles"
puts "    ✗ ERROR: core_rsp_valid_o HIGH but rsp_data is X (undefined)"
puts "    ✗ ERROR: evt_cache_read_miss_o HIGH in consecutive cycles (should pulse)"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts "  EXPECTED RESULTS BY TESTCASE"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  ┌─────────────────────┬──────────────┬─────────────────────────┐"
puts "  │ Test Case           │ Duration     │ Expected Outcome        │"
puts "  ├─────────────────────┼──────────────┼─────────────────────────┤"
puts "  │ tc_d_01_test        │ ~1000 ns     │ ✓ No violations         │"
puts "  │ (D-Cache basic)     │              │ ✓ Hit ratio ~50%        │"
puts "  │                     │              │ ✓ Responses in time     │"
puts "  ├─────────────────────┼──────────────┼─────────────────────────┤"
puts "  │ tc_i_01_test        │ ~1000 ns     │ ✓ No violations         │"
puts "  │ (I-Cache basic)     │              │ ✓ Constant latency      │"
puts "  │                     │              │ ✓ Sequential responses  │"
puts "  ├─────────────────────┼──────────────┼─────────────────────────┤"
puts "  │ tc_p_01_test        │ ~1500 ns     │ ✓ Prefetch triggers     │"
puts "  │ (Prefetcher basic)  │              │ ✓ Pattern detected      │"
puts "  │                     │              │ ✓ Accuracy > 70%        │"
puts "  ├─────────────────────┼──────────────┼─────────────────────────┤"
puts "  │ tc_d_02_test        │ ~2000 ns     │ ✓ Concurrent requests   │"
puts "  │ (D-Cache advanced)  │              │ ✓ Write-backs occur     │"
puts "  │                     │              │ ✓ No stalls             │"
puts "  ├─────────────────────┼──────────────┼─────────────────────────┤"
puts "  │ tc_int_01_test      │ ~3000 ns     │ ✓ I & D concurrent      │"
puts "  │ (Integration)       │              │ ✓ Fair arbitration      │"
puts "  │                     │              │ ✓ No deadlock           │"
puts "  └─────────────────────┴──────────────┴─────────────────────────┘"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts "  NEXT STEPS"
puts "════════════════════════════════════════════════════════════════════"
puts ""
puts "  1. RUN: run -all"
puts "     (or 'run 1000' for first 1000 ns)"
puts ""
puts "  2. INSPECT: Check each signal against verification checklist"
puts ""
puts "  3. COMPARE: Mark testcase as PASS/FAIL per table above"
puts ""
puts "  4. NEXT TEST: Change +UVM_TESTNAME and repeat"
puts ""
puts "════════════════════════════════════════════════════════════════════"
puts ""
