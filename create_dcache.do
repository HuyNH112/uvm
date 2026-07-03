# ============================================================
# create_full.do
# Target: HPDcache + Domino Prefetcher only (UVM testbench)
# Bam sat danh sach file trong project D:/HCMUS/THESIS/core
# ============================================================

set BASE_DIR  "D:/HCMUS/UVM"
set HPDCACHE_DIR "D:/HCMUS/THESIS/cv-hpdcache-master"

quit -sim
catch {project close}
project new $BASE_DIR uvm_hpdcache work

# ====================== ADD FILES ======================
set file_list [list \
    $HPDCACHE_DIR/hpdcache_config.svh \
    $HPDCACHE_DIR/rtl/include/hpdcache_typedef.svh \
\
    $HPDCACHE_DIR/prefetcher/domino_pkg.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_pkg.sv \
\
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_demux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_lfsr.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sync_buffer.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fifo_reg.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fifo_reg_initialized.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_fxarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_rrarb.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_mux.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_decoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_1hot_to_binary.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_prio_1hot_encoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_prio_bin_encoder.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram_wbyteenable.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_sram_wmask.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_regbank_wbyteenable_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_regbank_wmask_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_downsize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_upsize.sv \
    $HPDCACHE_DIR/rtl/src/common/hpdcache_data_resize.sv \
\
    $HPDCACHE_DIR/rtl/src/hwpf_stride/hwpf_stride_pkg.sv \
    $HPDCACHE_DIR/rtl/src/hwpf_stride/hwpf_stride.sv \
    $HPDCACHE_DIR/rtl/src/hwpf_stride/hwpf_stride_arb.sv \
    $HPDCACHE_DIR/rtl/src/hwpf_stride/hwpf_stride_wrapper.sv \
\
    $HPDCACHE_DIR/prefetcher/domino_trigger_detector.sv \
    $HPDCACHE_DIR/prefetcher/domino_history_buffers.sv \
    $HPDCACHE_DIR/prefetcher/domino_xor_hash.sv \
    $HPDCACHE_DIR/prefetcher/domino_mht_ram.sv \
    $HPDCACHE_DIR/prefetcher/domino_prefetcher_top.sv \
\
    $HPDCACHE_DIR/rtl/src/hpdcache.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_amo.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_cmo.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_core_arbiter.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_ctrl.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_ctrl_pe.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_memctrl.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_cbuf.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_miss_handler.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_mshr.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_rtab.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_uncached.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_plru.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_random.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_victim_sel.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_wbuf.sv \
    $HPDCACHE_DIR/rtl/src/hpdcache_flush.sv \
    $HPDCACHE_DIR/hpdcache_wrapper.sv \
\
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv \
    $HPDCACHE_DIR/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv \
\
    $HPDCACHE_DIR/tb_hpdcache_prefetch.sv \
]

foreach f $file_list {
    project addfile $f systemverilog
}

echo "=== HPDcache + Domino Prefetcher RTL loaded: [llength $file_list] files ==="
