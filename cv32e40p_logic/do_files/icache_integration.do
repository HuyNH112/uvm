# ============================================================
# Integration.do - MINIMAL I-Cache Performance Test
# CV32E40P + I-Cache Integration Verification
# Testcase: "I-Cache Sequential Hits" - Miss Rate Analysis
# Date: 29 July 2026
# Optimization: Only essential files for 1 testcase
# ============================================================

quit -sim
catch {project close}

set BASE_DIR      "D:/khoaluantotnghiep/project_e40p_icache"
set CV32E40P_DIR  "D:/khoaluantotnghiep/cv32e40p-master"
set ICACHE_DIR    "D:/khoaluantotnghiep/icache-master"
set TESTBENCH_DIR "D:/khoaluantotnghiep/testbench"

file mkdir $BASE_DIR
project new $BASE_DIR cv32e40p_icache work

# ====================== MINIMAL COMPILATION ======================
# Phase 0:  Packages (CRITICAL - FIRST)
# Phase 1:  CV32E40P Core RTL (27 files)
# Phase 2:  CV32E40P Packages & Dependencies (selected)
# Phase 3:  I-Cache (5 files)
# Phase 4:  Testbench (1 file - tc_icache_miss_rate.sv)
# Total: ~60 files (vs 239 full integration)

set file_list [list \
\
    "=== PHASE 0: PACKAGES (CRITICAL - MUST BE FIRST) ===" \
	$CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/include/common_cells/registers.svh \
    $CV32E40P_DIR/rtl/include/cv32e40p_pkg.sv \
    $CV32E40P_DIR/rtl/include/cv32e40p_apu_core_pkg.sv \
    $CV32E40P_DIR/rtl/include/cv32e40p_fpu_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cf_math_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cb_filter_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_pkg.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_fpnew/src/fpnew_pkg.sv \
    $CV32E40P_DIR/bhv/include/cv32e40p_rvfi_pkg.sv \
    $CV32E40P_DIR/bhv/include/cv32e40p_tracer_pkg.sv \
\
    "=== PHASE 1: CV32E40P CORE RTL (27 FILES - ESSENTIAL) ===" \
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
    "=== PHASE 2: CV32E40P VENDOR DEPS (MINIMAL) ===" \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/addr_decode.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/binary_to_gray.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cb_filter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_2phase.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_fifo_2phase.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/cdc_fifo_gray.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/clk_div.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/delta_counter.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_decode.sv \
    $CV32E40P_DIR/rtl/vendor/pulp_platform_common_cells/src/ecc_encode.sv \
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
    "=== PHASE 3: I-CACHE PACKAGE (CRITICAL - DEFINE CACHE PARAMS) ===" \
    $ICACHE_DIR/cv32e40p_icache_pkg.sv \
\
    "=== PHASE 3B: I-CACHE CORE (5 FILES - ESSENTIAL) ===" \
    $ICACHE_DIR/plru.sv \
    $ICACHE_DIR/cv32e40p_icache_data_mem.sv \
    $ICACHE_DIR/cv32e40p_icache_tag_mem.sv \
    $ICACHE_DIR/cv32e40p_icache.sv \
\
    "=== PHASE 4: TESTBENCH (1 FILE - I-CACHE MISS RATE TEST) ===" \
    $TESTBENCH_DIR/tc_icache_miss_rate.sv \
	$TESTBENCH_DIR/tc_icache_advanced.sv \
]

puts "╔═══════════════════════════════════════════════════════════╗"
puts "║  INTEGRATION TEST: I-Cache Miss Rate Analysis             ║"
puts "║  Minimal file set for single testcase verification        ║"
puts "║  Total files: ~65 (vs 239 full integration)               ║"
puts "╚═══════════════════════════════════════════════════════════╝"

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
puts "╔═══════════════════════════════════════════════════════════╗"
puts "║  STATUS                                                   ║"
puts "╠═══════════════════════════════════════════════════════════╣"
puts "║                                                           ║"
puts "║  RTL Files Added: $file_count                             ║"
puts "║  Compilation Phases: $phase_count                        ║"
puts "║                                                           ║"
puts "║  TESTCASE: I-Cache Sequential Hits                        ║"
puts "║    Objective: Measure I-Cache miss rate                  ║"
puts "║    Success Criteria: miss_rate < 10% (sequential access) ║"
puts "║                                                           ║"
puts "║  Key Signals to Monitor:                                  ║"
puts "║    ✓ cv32e40p_icache.miss_o                              ║"
puts "║    ✓ cv32e40p_icache.miss_event_o                        ║"
puts "║    ✓ cv32e40p_icache.instr_rvalid_o                      ║"
puts "║                                                           ║"
puts "║  Next: elaborate -all                                    ║"
puts "║        vsim -c tb_icache_miss_rate                       ║"
puts "║                                                           ║"
puts "╚═══════════════════════════════════════════════════════════╝"
puts ""
