# ============================================================
# uvm_FIXED.do - CORRECTED UVM VERIFICATION FRAMEWORK
# Purpose: Proper compilation order - ONLY package, not components
# Version: UVM Integration V2 (FIXED)
# Date: 31 July 2026
# Status: FIXED - Components included in package, not compiled standalone
# ============================================================

quit -sim
catch {project close}

# =====================================================================
# PATH CONFIGURATION (VERIFIED)
# =====================================================================
set BASE_DIR      "D:/UVM_CV32E40P/project_uvm"
set CV32E40P_DIR  "D:/khoaluantotnghiep/cv32e40p-master"
set ICACHE_DIR    "D:/khoaluantotnghiep/icache-master"
set HPDCACHE_DIR  "D:/khoaluantotnghiep/cv-hpdcache-master"
set TESTBENCH_DIR "D:/khoaluantotnghiep/testbench"
set INTEGRATION_DIR "D:/khoaluantotnghiep/integration"
set UVM_DIR       "D:/UVM_CV32E40P/sv"
set TB_DIR        "D:/UVM_CV32E40P/tb"

file mkdir $BASE_DIR
project new $BASE_DIR project_uvm work

# =====================================================================
# CRITICAL FIX: CORRECT UVM COMPILATION SEQUENCE
# =====================================================================
# RULE: UVM component files (seq_item, sequencer, driver, monitor, etc.)
#       are INCLUDED inside hpdcache_uvm_pkg.sv via `include directives.
#       They should NEVER be compiled as standalone files!
#
# CORRECT COMPILATION ORDER:
#   1. RTL packages (hpdcache_pkg, cv32e40p_pkg, etc.)
#   2. UVM package ONLY (hpdcache_uvm_pkg.sv)
#      └─ Automatically includes all 9 component files
#   3. Coverage (standalone, AFTER package)
#   4. Instruction decoder module (RTL, standalone)
#   5. OBI adapter interface (AFTER package)
#   6. Top-level testbench (AFTER all dependencies)
#   7. Test files (AFTER env is defined)
# =====================================================================

set file_list [list \
\
    "=== PHASE 1: INCLUDES & TYPEDEFS ===" \
	$CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/include/common_cells/registers.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_typedef.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_config.svh \
\
    "=== PHASE 2: CV32E40P CORE RTL ===" \
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
    "=== PHASE 2B: CV32E40P PACKAGES & VENDOR ===" \
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
    "=== PHASE 3: I-CACHE ===" \
    $ICACHE_DIR/plru.sv \
    $ICACHE_DIR/cv32e40p_icache_pkg.sv \
    $ICACHE_DIR/cv32e40p_icache_data_mem.sv \
    $ICACHE_DIR/cv32e40p_icache_tag_mem.sv \
    $ICACHE_DIR/cv32e40p_icache.sv \
\
    "=== PHASE 4: OBI-to-AXI4 ADAPTER (PRODUCTION) ===" \
    $INTEGRATION_DIR/obi_to_axi4_adapter.sv \
\
    "=== PHASE 5: HPDCACHE PACKAGES & UTILS ===" \
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
    "=== PHASE 6: HPDCACHE COMMON & UTILITIES ===" \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_lfsr.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_prio_1hot_encoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_prio_bin_encoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fxarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sync_buffer.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_downsize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_upsize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_resize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram_wbyteenable.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram_wmask.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_1hot_to_binary.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_decoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_demux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fifo_reg.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_mux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_rrarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv \
\
    "=== PHASE 6B: HPDCACHE SUBMODULES (TABLES & UTILITIES) ===" \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_plru.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_random.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_sel.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_rtab.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_mshr.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_cbuf.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_amo.sv \
\
    "=== PHASE 6C: HPDCACHE MAJOR BLOCKS ===" \
    $HPDCACHE_DIR/rtl/src/hpdcache_core_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_ctrl_pe.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_wbuf.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_memctrl.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_miss_handler.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_uncached.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_cmo.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_flush.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_ctrl.sv \
\
    "=== PHASE 6D: HPDCACHE CORE (MAIN CACHE) ===" \
    $HPDCACHE_DIR/rtl/src/hpdcache.sv \
\
    "=== PHASE 7: DOMINO PREFETCHER ===" \
    $HPDCACHE_DIR/prefetcher/domino_pkg.sv \
    $HPDCACHE_DIR/prefetcher/domino_trigger_detector.sv \
    $HPDCACHE_DIR/prefetcher/domino_history_buffers.sv \
    $HPDCACHE_DIR/prefetcher/domino_xor_hash.sv \
    $HPDCACHE_DIR/prefetcher/domino_mht_ram.sv \
    $HPDCACHE_DIR/prefetcher/domino_prefetcher_top.sv \
\
    "=== PHASE 7B: HPDCACHE WRAPPER (DUT) ===" \
    D:/UVM_CV32E40P/sv/hpdcache_wrapper.sv \
\
    "=== PHASE 8: TESTBENCH - OBI-to-AXI4 INTEGRATION ===" \
    $TESTBENCH_DIR/int_full_integration.sv \
\
    "=== PHASE 8A: INTERFACE DEFINITION ===" \
    $TB_DIR/hpdcache_if.sv \
\
    "=== PHASE 8B: HARDWARE TOP MODULE ===" \
    $TB_DIR/hw_top.sv \
\
    "=== PHASE 9: SIMPLE LOGIC SIMULATION - PERFORMANCE MONITORING ===" \
    $UVM_DIR/cache_perf_monitor.sv \
    $UVM_DIR/perf_report.sv \
\
    "=== PHASE 10: SIMPLE LOGIC SIMULATION - TESTBENCH ===" \
    $TB_DIR/tb_top_simple.sv \
]

puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║      UVM VERIFICATION FRAMEWORK FOR CV32E40P + L1 CACHE          ║"
puts "║      OPTIMIZED COMPILATION - 3 Key Files Only                    ║"
puts "║      Date: 31 July 2026 | Strategy: hpdcache_uvm_pkg + hw_top + tb_top ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"

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
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║  COMPILATION SETUP COMPLETE (RTL Foundation Ready)               ║"
puts "╠═══════════════════════════════════════════════════════════════════╣"
puts "║                                                                   ║"
puts "║  RTL PHASES 1-8: Foundation (~200 files)                         ║"
puts "║    ✓ Phase 1: Includes & Typedefs                                ║"
puts "║    ✓ Phase 2: CV32E40P Core RTL (~80 files)                      ║"
puts "║    ✓ Phase 3: I-Cache (~5 files)                                 ║"
puts "║    ✓ Phase 4: OBI-to-AXI4 Adapter (1 file)                       ║"
puts "║    ✓ Phase 5: HPDcache Packages (hpdcache_pkg.sv only)           ║"
puts "║    ✓ Phase 6: HPDcache Common + Utils (16 files)                 ║"
puts "║    ✓ Phase 6B: HPDcache Submodules (7 files)                     ║"
puts "║    ✓ Phase 6C: HPDcache Major Blocks (9 files)                   ║"
puts "║    ✓ Phase 6D: HPDcache Core (1 file: hpdcache.sv)               ║"
puts "║    ✓ Phase 7: Domino Prefetcher (~5 files)                       ║"
puts "║    ✓ Phase 7B: HPDcache Wrapper (1 file)                         ║"
puts "║    ✓ Phase 8: OBI-to-AXI4 Integration (1 file)                   ║"
puts "║                                                                   ║"
puts "║  UVM COMPILATION (Next Steps - SIMPLIFIED):                      ║"
puts "║    📋 PHASE 9 (Step 3): Compile UVM Package ONLY                 ║"
puts "║       → hpdcache_uvm_pkg.sv                                      ║"
puts "║       → Contains all 9 component files via `include              ║"
puts "║                                                                   ║"
puts "║    📋 PHASE 10 (Step 4): Compile hw_top.sv ONLY                  ║"
puts "║       → DUT instantiation + Memory model                         ║"
puts "║       → Requires: All RTL files above                            ║"
puts "║                                                                   ║"
puts "║    📋 PHASE 11 (Step 5): Compile tb_top.sv ONLY                  ║"
puts "║       → Test infrastructure + Testbench top                      ║"
puts "║       → Includes: base_test + all sequence classes               ║"
puts "║       → Requires: hpdcache_uvm_pkg.sv                            ║"
puts "║                                                                   ║"
puts "║  ✅ NO STANDALONE COMPILATION ✅                                 ║"
puts "║     • NO hpdcache_seq_item.sv standalone                         ║"
puts "║     • NO hpdcache_driver.sv standalone                           ║"
puts "║     • NO hpdcache_coverage.sv standalone                         ║"
puts "║     • NO individual test files                                   ║"
puts "║                                                                   ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"
puts ""

# =====================================================================
# STEP 1: Compile RTL foundation (project files)
# =====================================================================
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║  STEP 1: Compile RTL Foundation (57 CV32E40P + HPDcache)          ║"
puts "╚═══════════════════════════════════════════════════════════════════╝\n"

catch {compile -all} compile_result
if {[string match "*Error*" $compile_result]} {
    puts "✗ RTL Compilation FAILED"
    puts "   Result: $compile_result"
    return
} else {
    puts "✓ RTL Compilation successful!\n"
}

puts ""
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║  ✅ RTL COMPILATION COMPLETE                                      ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"
puts ""
puts "Next step: Run 'do D:/UVM_CV32E40P/do/run_uvm.do' to compile UVM"
puts ""
