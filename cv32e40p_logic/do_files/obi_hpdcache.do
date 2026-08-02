# ============================================================
# int02.do - MINIMAL L1 CACHE INTEGRATION PROOF (COMPLETE)
# Purpose: Single unified script for project setup + compile + simulate
# 3-Signal Proof: PC, I-Cache Response, D-Cache Response
# Date: 29 July 2026
# Status: UNIFIED SCRIPT FOLLOWING create_cv32e40p STRUCTURE
# ============================================================

quit -sim
catch {project close}

set BASE_DIR      "D:/khoaluantotnghiep/project_int02_minimal_proof"
set CV32E40P_DIR  "D:/khoaluantotnghiep/cv32e40p-master"
set ICACHE_DIR    "D:/khoaluantotnghiep/icache-master"
set HPDCACHE_DIR  "D:/khoaluantotnghiep/cv-hpdcache-master"
set TESTBENCH_DIR "D:/khoaluantotnghiep/testbench"
set INTEGRATION_DIR "D:/khoaluantotnghiep/integration"

file mkdir $BASE_DIR
project new $BASE_DIR int02_minimal_proof work

# =====================================================================
# MINIMAL COMPILATION FOR INT-02: L1 CACHE PROOF
# =====================================================================
# Objective: Verify 3 signals simultaneously:
#   1. PC (instr_addr_o)     — CPU fetching instructions
#   2. I-Cache (instr_rvalid_i) — I-Cache responding
#   3. D-Cache (data_rvalid_i)  — D-Cache responding
#
# Strategy: Minimal RTL compilation + testbench
#   - Phase 1: Includes & Typedefs (CRITICAL)
#   - Phase 2: CV32E40P Core minimal (essential only)
#   - Phase 3: I-Cache (cv32e40p_icache.sv)
#   - Phase 4: D-Cache Adapter (cv32e40p_to_hpdcache_adapter.sv)
#   - Phase 5: HPDcache packages (types + config)
#   - Phase 6: Domino Prefetcher (optional, minimal)
#   - Phase 7: Testbench + stubs (int02_minimal_proof.sv)
# =====================================================================

set file_list [list \
\
    "=== PHASE 1: INCLUDES & TYPEDEFS (CRITICAL - MUST BE FIRST) ===" \
	$CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/include/common_cells/registers.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_typedef.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_config.svh \
\
    "=== PHASE 2: CV32E40P CORE - MINIMAL RTL (ESSENTIAL ONLY) ===" \
    $CV32E40P_DIR/bhv/cv32e40p_sim_clock_gate.sv \
    $CV32E40P_DIR/rtl/cv32e40p_aligner.sv \
    $CV32E40P_DIR/rtl/cv32e40p_alu.sv \
    $CV32E40P_DIR/rtl/cv32e40p_alu_div.sv \
    $CV32E40P_DIR/rtl/cv32e40p_apu_disp.sv \
    $CV32E40P_DIR/rtl/cv32e40p_compressed_decoder.sv \
    $CV32E40P_DIR/rtl/cv32e40p_controller.sv \
    $CV32E40P_DIR/rtl/cv32e40p_core.sv \
    $CV32E40P_DIR/rtl/cv32e40p_cs_registers.sv \
    $CV32E40P_DIR/rtl/cv32e40p_decoder.sv \
    $CV32E40P_DIR/rtl/cv32e40p_ex_stage.sv \
    $CV32E40P_DIR/rtl/cv32e40p_ff_one.sv \
    $CV32E40P_DIR/rtl/cv32e40p_fifo.sv \
    $CV32E40P_DIR/rtl/cv32e40p_fp_wrapper.sv \
    $CV32E40P_DIR/rtl/cv32e40p_hwloop_regs.sv \
    $CV32E40P_DIR/rtl/cv32e40p_id_stage.sv \
    $CV32E40P_DIR/rtl/cv32e40p_if_stage.sv \
    $CV32E40P_DIR/rtl/cv32e40p_int_controller.sv \
    $CV32E40P_DIR/rtl/cv32e40p_load_store_unit.sv \
    $CV32E40P_DIR/rtl/cv32e40p_mult.sv \
    $CV32E40P_DIR/rtl/cv32e40p_obi_interface.sv \
    $CV32E40P_DIR/rtl/cv32e40p_popcnt.sv \
    $CV32E40P_DIR/rtl/cv32e40p_prefetch_buffer.sv \
    $CV32E40P_DIR/rtl/cv32e40p_prefetch_controller.sv \
    $CV32E40P_DIR/rtl/cv32e40p_register_file_ff.sv \
    $CV32E40P_DIR/rtl/cv32e40p_register_file_latch.sv \
    $CV32E40P_DIR/rtl/cv32e40p_sleep_unit.sv \
    $CV32E40P_DIR/rtl/cv32e40p_top.sv \
\
    "=== PHASE 2B: CV32E40P PACKAGES & VENDOR DEPENDENCIES ===" \
    $CV32E40P_DIR/rtl/include/cv32e40p_pkg.sv \
    $CV32E40P_DIR/rtl/include/cv32e40p_apu_core_pkg.sv \
    $CV32E40P_DIR/rtl/include/cv32e40p_fpu_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_pkg.sv \
    $CV32E40P_DIR/bhv/cv32e40p_apu_tracer.sv \
    $CV32E40P_DIR/bhv/cv32e40p_core_log.sv \
    $CV32E40P_DIR/bhv/cv32e40p_rvfi.sv \
    $CV32E40P_DIR/bhv/cv32e40p_rvfi_trace.sv \
    $CV32E40P_DIR/bhv/cv32e40p_tb_wrapper.sv \
    $CV32E40P_DIR/bhv/cv32e40p_tracer.sv \
    $CV32E40P_DIR/bhv/include/cv32e40p_rvfi_pkg.sv \
    $CV32E40P_DIR/bhv/include/cv32e40p_tracer_pkg.sv \
    $CV32E40P_DIR/example_tb/core/amo_shim.sv \
    $CV32E40P_DIR/example_tb/core/cv32e40p_random_interrupt_generator.sv \
    $CV32E40P_DIR/example_tb/core/cv32e40p_tb_subsystem.sv \
    $CV32E40P_DIR/example_tb/core/dp_ram.sv \
    $CV32E40P_DIR/example_tb/core/mm_ram.sv \
    $CV32E40P_DIR/example_tb/core/riscv_gnt_stall.sv \
    $CV32E40P_DIR/example_tb/core/riscv_rvalid_stall.sv \
    $CV32E40P_DIR/example_tb/core/tb_top.sv \
    $CV32E40P_DIR/example_tb/core/include/perturbation_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/addr_decode.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/binary_to_gray.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cb_filter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cb_filter_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_2phase.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_fifo_2phase.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_fifo_gray.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cf_math_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/clk_div.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/delta_counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_decode.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_encode.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/edge_detect.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/edge_propagator.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/edge_propagator_rx.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/edge_propagator_tx.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/exp_backoff.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/fall_through_register.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/fifo_v3.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/gray_to_binary.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/id_queue.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/isochronous_spill_register.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/lfsr.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/lfsr_16bit.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/lfsr_8bit.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/lzc.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/max_counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/mv_filter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/onehot_to_bin.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/plru_tree.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/popcount.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/rr_arb_tree.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/rstgen.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/rstgen_bypass.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/serial_deglitch.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/shift_reg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/spill_register.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_arbiter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_arbiter_flushable.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_delay.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_demux.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_fifo.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_filter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_fork.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_fork_dynamic.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_intf.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_join.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_mux.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_omega_net.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_register.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_to_mem.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/stream_xbar.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/sub_per_hash.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/sync.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/sync_wedge.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/unread.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/clock_divider.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/clock_divider_counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/fifo_v1.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/fifo_v2.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/find_first_one.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/generic_LFSR_8bit.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/generic_fifo.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/generic_fifo_adv.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/deprecated/prioarbiter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_cast_multi.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_classifier.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_divsqrt_multi.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_divsqrt_th_32.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_fma.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_fma_multi.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_noncomp.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_block.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_fmt_slice.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_multifmt_slice.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_rounding.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_top.sv \
\
    "=== PHASE 3: I-CACHE (16KB 4-WAY, 315 LOC + SRAM) ===" \
    $ICACHE_DIR/plru.sv \
    $ICACHE_DIR/cv32e40p_icache_pkg.sv \
    $ICACHE_DIR/cv32e40p_icache_data_mem.sv \
    $ICACHE_DIR/cv32e40p_icache_tag_mem.sv \
    $ICACHE_DIR/cv32e40p_icache.sv \
\
    "=== PHASE 4: D-CACHE ADAPTER (342 LOC - OBI ↔ HPDCACHE BRIDGE) ===" \
    $ICACHE_DIR/cv32e40p_to_hpdcache_adapter.sv \
\
    "=== PHASE 5: HPDCACHE PACKAGES & UTILITIES ===" \
    $HPDCACHE_DIR/rtl/src/hpdcache_pkg.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_resp_demux.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_36_29_dec.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_36_29_enc.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_39_32_dec.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_39_32_enc.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_55_48_dec.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_55_48_enc.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_72_64_dec.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_72_64_enc.sv \
    $HPDCACHE_DIR/rtl/src/utils/ecc/prim_secded_pkg.sv \
\
    "=== PHASE 6: HPDCACHE COMMON UTILITIES ===" \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_1hot_to_binary.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_resize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_decoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_demux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fifo_reg.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_mux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_rrarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
\
    "=== PHASE 7: DOMINO PREFETCHER (6 FILES, 187 LOC) ===" \
    $HPDCACHE_DIR/prefetcher/domino_pkg.sv \
    $HPDCACHE_DIR/prefetcher/domino_trigger_detector.sv \
    $HPDCACHE_DIR/prefetcher/domino_history_buffers.sv \
    $HPDCACHE_DIR/prefetcher/domino_xor_hash.sv \
    $HPDCACHE_DIR/prefetcher/domino_mht_ram.sv \
    $HPDCACHE_DIR/prefetcher/domino_prefetcher_top.sv \
\
    "=== PHASE 8: TESTBENCH - MINIMAL PROOF (int02_minimal_proof.sv) ===" \
    $TESTBENCH_DIR/int02_minimal_proof.sv \
]

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  INT-02: MINIMAL L1 CACHE INTEGRATION PROOF                    ║"
puts "║  Complete Single Script: Setup + Compile + Run                 ║"
puts "║  3-Signal Proof: PC, I-Cache Response, D-Cache Response       ║"
puts "║  Date: 29 July 2026                                            ║"
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
puts "║  Total RTL Files Added: $file_count                            ║"
puts "║  Total Compilation Phases: $phase_count                       ║"
puts "║                                                                ║"
puts "║  Component Breakdown:                                          ║"
puts "║    Phase 1: HPDcache Typedefs          2 files (.svh)         ║"
puts "║    Phase 2: CV32E40P Core RTL         27 files (core logic)   ║"
puts "║    Phase 2B: CV32E40P Packages        36 files (pkg + vendor) ║"
puts "║    Phase 3: I-Cache                   5 files (315 LOC)       ║"
puts "║    Phase 4: D-Cache Adapter           1 file (342 LOC)        ║"
puts "║    Phase 5: HPDcache Packages         14 files (utils + ECC)  ║"
puts "║    Phase 6: HPDcache Common            9 files (primitives)   ║"
puts "║    Phase 7: Domino Prefetcher         6 files (187 LOC)       ║"
puts "║    Phase 8: Testbench                 1 file (int02_minimal)  ║"
puts "║                                                                ║"
puts "║  Test Objectives:                                             ║"
puts "║    SIGNAL 1: PC (instr_addr_o)        CPU fetching?           ║"
puts "║    SIGNAL 2: I-Cache (instr_rvalid_i) Cache responding?       ║"
puts "║    SIGNAL 3: D-Cache (data_rvalid_i)  D-Cache responding?     ║"
puts "║                                                                ║"
puts "║  Success Criteria:                                            ║"
puts "║    ✓ All 3 signals active simultaneously in waveform          ║"
puts "║    ✓ I-Cache: instr_rvalid_i pulses ≥ 5 times                 ║"
puts "║    ✓ D-Cache: data_rvalid_i pulses ≥ 1 time                   ║"
puts "║                                                                ║"
puts "║  Waveform Output:                                             ║"
puts "║    - int02_minimal_proof.vcd (3 key signals)                  ║"
puts "║    - Monitor: instr_addr_o, instr_rvalid_i, data_rvalid_i     ║"
puts "║                                                                ║"
puts "║  Next Steps (in QuestaSim):                                   ║"
puts "║    1. compile -all                                            ║"
puts "║    2. elaborate int02_minimal_proof_tb                         ║"
puts "║    3. vsim -c int02_minimal_proof_tb                           ║"
puts "║    4. run -all                                                 ║"
puts "║    5. gtkwave int02_minimal_proof.vcd                          ║"
puts "║                                                                ║"
puts "║  Status: ✅ READY FOR COMPILATION & SIMULATION                ║"
puts "║                                                                ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# =====================================================================
# AUTO-RUN: Compile all files
# =====================================================================
puts "AUTO-STARTING COMPILATION (compile -all)...\n"

catch {compile -all} compile_result
if {[string match "*Error*" $compile_result]} {
    puts "✗ Compilation FAILED"
    puts "   Result: $compile_result"
    puts "\n   Note: Fix errors then run manually:"
    puts "   compile -all"
    puts "   elaborate int02_minimal_proof_tb"
    puts "   vsim -c int02_minimal_proof_tb"
} else {
    puts "✓ Compilation successful!"
    puts "\n   Next: Elaborate the testbench"
    puts "   elaborate int02_minimal_proof_tb"
    puts "\n   Then: Start simulation"
    puts "   vsim -c int02_minimal_proof_tb -do \"run -all\""
}
puts ""
