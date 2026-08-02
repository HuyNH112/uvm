// =============================================================================
// hpdcache_if.sv
// Interface cho HPDcache Wrapper Testbench
// Constraints: UVM 1.1d, QuestaSim 23.3 Starter (no svverification)
//              Không dùng SVA `disable iff`, không dùng `rand`
//
// FIX v3 (July 2026):
//   - hpdcache_req_t.op  : logic[2:0]  → hpdcache_pkg::hpdcache_req_op_t
//   - hpdcache_req_t.size: logic[2:0]  → hpdcache_pkg::hpdcache_req_size_t
//   - hpdcache_pma_t (standalone port): local typedef → hpdcache_pkg::hpdcache_pma_t
//   - mem_req_read_command_o / mem_req_write_command_o : logic[2:0] → hpdcache_pkg::hpdcache_mem_command_e
//   - mem_resp_read_error_i / mem_resp_write_error_i   : logic[1:0] → hpdcache_pkg::hpdcache_mem_error_e
//   - cfg_wbuf_threshold_i : logic[WBUF_TCW-1:0] → wbuf_timecnt_t (localparam type từ pkg)
//   NOTE: Tất cả enum/struct type phải khớp EXACTLY với hpdcache_pkg để tránh vopt-2241
//         dẫn đến Questa ICE (vgenstmt.c crash).
// =============================================================================
`ifndef HPDCACHE_IF_SV
`define HPDCACHE_IF_SV

// Direct includes for config macros (required before using CONF_* macros)
`include "D:/UVM_CV32E40P/cv32e40p_logic/cv-hpdcache-master/rtl/include/hpdcache_typedef.svh"
`include "D:/UVM_CV32E40P/cv32e40p_logic/cv-hpdcache-master/rtl/include/hpdcache_config.svh"

interface hpdcache_if
import hpdcache_pkg::*;
(input logic clk_i, input logic rst_ni);

    // -------------------------------------------------------------------------
    // Width localparams (tham chiếu nội bộ, không dùng cho port type declarations)
    // -------------------------------------------------------------------------
    localparam int unsigned PA_W      = `CONF_HPDCACHE_PA_WIDTH;            // 56
    localparam int unsigned WORD_W    = `CONF_HPDCACHE_WORD_WIDTH;           // 64
    localparam int unsigned SETS      = `CONF_HPDCACHE_SETS;                 // 64
    localparam int unsigned WAYS      = `CONF_HPDCACHE_WAYS;                 // 8
    localparam int unsigned CL_WORDS  = `CONF_HPDCACHE_CL_WORDS;             // 8
    localparam int unsigned REQ_WORDS = `CONF_HPDCACHE_REQ_WORDS;            // 2
    localparam int unsigned TID_W     = `CONF_HPDCACHE_REQ_TRANS_ID_WIDTH;   // 6
    localparam int unsigned SID_W     = `CONF_HPDCACHE_REQ_SRC_ID_WIDTH;     // 3
    localparam int unsigned MEM_DW    = `CONF_HPDCACHE_MEM_DATA_WIDTH;       // 512
    localparam int unsigned MEM_AW    = `CONF_HPDCACHE_MEM_ADDR_WIDTH;       // 56
    localparam int unsigned MEM_IDW   = `CONF_HPDCACHE_MEM_ID_WIDTH;         // 8
    localparam int unsigned WBUF_TCW  = `CONF_HPDCACHE_WBUF_TIMECNT_WIDTH;   // 8

    // Derived widths
    localparam int unsigned SET_W    = $clog2(SETS);
    localparam int unsigned CL_OFF_W = $clog2(CL_WORDS * (WORD_W/8));       // 6
    localparam int unsigned TAG_W    = PA_W - SET_W - CL_OFF_W;              // 44
    localparam int unsigned OFF_W    = SET_W + CL_OFF_W;                     // 12
    localparam int unsigned DATA_W   = REQ_WORDS * WORD_W;                   // 128
    localparam int unsigned BE_W     = REQ_WORDS * (WORD_W/8);               // 16

    // -------------------------------------------------------------------------
    // Type aliases — dùng đúng pkg types để khớp với hpdcache_wrapper port list
    // -------------------------------------------------------------------------
    typedef logic [TAG_W-1:0]    hpdcache_tag_t;
    typedef logic [OFF_W-1:0]    hpdcache_req_offset_t;
    typedef logic [REQ_WORDS-1:0][WORD_W-1:0]    hpdcache_req_data_t;
	typedef logic [REQ_WORDS-1:0][WORD_W/8-1:0]  hpdcache_req_be_t;
    typedef logic [SID_W-1:0]    hpdcache_req_sid_t;
    typedef logic [TID_W-1:0]    hpdcache_req_tid_t;
    typedef logic [PA_W-1:0]     hpdcache_req_addr_t;

    // wbuf_timecnt_t phải khớp với localparam type trong hpdcache_wrapper
    typedef logic unsigned [WBUF_TCW-1:0] wbuf_timecnt_t;

    // hpdcache_req_t: dùng HPDCACHE_DECL_REQ_T macro — field op và size phải dùng
    // hpdcache_pkg::hpdcache_req_op_t và hpdcache_pkg::hpdcache_req_size_t
    // FIX: op từ logic[2:0] → hpdcache_req_op_t; size từ logic[2:0] → hpdcache_req_size_t
    typedef struct packed {
        hpdcache_req_offset_t       addr_offset;
        hpdcache_req_data_t         wdata;
        hpdcache_pkg::hpdcache_req_op_t   op;      // FIX: phải là pkg enum, không phải logic[2:0]
        hpdcache_req_be_t           be;
        hpdcache_pkg::hpdcache_req_size_t size;    // FIX: phải là pkg typedef, không phải logic[2:0]
        hpdcache_req_sid_t          sid;
        hpdcache_req_tid_t          tid;
        logic                       need_rsp;
        logic                       phys_indexed;
        hpdcache_tag_t              addr_tag;
        hpdcache_pkg::hpdcache_pma_t pma;          // pma nằm TRONG req_t struct (HPDCACHE_DECL_REQ_T)
    } hpdcache_req_t;

    // hpdcache_rsp_t: khớp HPDCACHE_DECL_RSP_T macro
    // NOTE: field order trong macro là rdata, sid, tid, error, aborted
    typedef struct packed {
        hpdcache_req_data_t     rdata;
        hpdcache_req_sid_t      sid;
        hpdcache_req_tid_t      tid;
        logic                   error;
        logic                   aborted;
    } hpdcache_rsp_t;

    // -------------------------------------------------------------------------
    // Core Request Interface signals
    // -------------------------------------------------------------------------
    logic                               core_req_valid_i;
    logic                               core_req_ready_o;
    hpdcache_req_t                      core_req_i;
    logic                               core_req_abort_i;
    hpdcache_tag_t                      core_req_tag_i;
    // FIX 1: core_req_pma_i phải dùng hpdcache_pkg::hpdcache_pma_t
    // (đây là standalone 2nd-cycle port, khác với pma field bên trong req_t)
    hpdcache_pkg::hpdcache_pma_t        core_req_pma_i;

    // Core Response Interface
    logic                               core_rsp_valid_o;
    hpdcache_rsp_t                      core_rsp_o;

    // -------------------------------------------------------------------------
    // Memory Read Interface signals
    // -------------------------------------------------------------------------
    logic                               mem_req_read_ready_i;
    logic                               mem_req_read_valid_o;
    logic [MEM_AW-1:0]                  mem_req_read_addr_o;
    hpdcache_pkg::hpdcache_mem_len_t    mem_req_read_len_o;
    hpdcache_pkg::hpdcache_mem_size_t   mem_req_read_size_o;
    logic [MEM_IDW-1:0]                 mem_req_read_id_o;
    // FIX 2: mem_req_read_command_o phải là hpdcache_mem_command_e (enum), không phải logic[2:0]
    hpdcache_pkg::hpdcache_mem_command_e mem_req_read_command_o;
    hpdcache_pkg::hpdcache_mem_atomic_e  mem_req_read_atomic_o;
    logic                               mem_req_read_cacheable_o;

    logic                               mem_resp_read_ready_o;   // OUTPUT của DUT!
    logic                               mem_resp_read_valid_i;
    // FIX (bonus): mem_resp_read_error_i phải là hpdcache_mem_error_e, không phải logic[1:0]
    hpdcache_pkg::hpdcache_mem_error_e  mem_resp_read_error_i;
    logic [MEM_IDW-1:0]                 mem_resp_read_id_i;
    logic [MEM_DW-1:0]                  mem_resp_read_data_i;
    logic                               mem_resp_read_last_i;

    // -------------------------------------------------------------------------
    // Memory Write Interface signals
    // -------------------------------------------------------------------------
    logic                               mem_req_write_ready_i;
    logic                               mem_req_write_valid_o;
    logic [MEM_AW-1:0]                  mem_req_write_addr_o;
    hpdcache_pkg::hpdcache_mem_len_t    mem_req_write_len_o;
    hpdcache_pkg::hpdcache_mem_size_t   mem_req_write_size_o;
    logic [MEM_IDW-1:0]                 mem_req_write_id_o;
    // FIX 3: mem_req_write_command_o phải là hpdcache_mem_command_e
    hpdcache_pkg::hpdcache_mem_command_e mem_req_write_command_o;
    hpdcache_pkg::hpdcache_mem_atomic_e  mem_req_write_atomic_o;
    logic                               mem_req_write_cacheable_o;

    logic                               mem_req_write_data_ready_i;
    logic                               mem_req_write_data_valid_o;
    logic [MEM_DW-1:0]                  mem_req_write_data_o;
    logic [MEM_DW/8-1:0]               mem_req_write_be_o;
    logic                               mem_req_write_last_o;

    logic                               mem_resp_write_ready_o;  // OUTPUT của DUT!
    logic                               mem_resp_write_valid_i;
    logic                               mem_resp_write_is_atomic_i;
    // FIX (bonus): mem_resp_write_error_i phải là hpdcache_mem_error_e
    hpdcache_pkg::hpdcache_mem_error_e  mem_resp_write_error_i;
    logic [MEM_IDW-1:0]                 mem_resp_write_id_i;

    // -------------------------------------------------------------------------
    // Performance Events & Status & Config
    // -------------------------------------------------------------------------
    logic evt_cache_write_miss_o;
    logic evt_cache_read_miss_o;
    logic evt_cache_dir_unc_err_o;
    logic evt_cache_dir_cor_err_o;
    logic evt_cache_dat_unc_err_o;
    logic evt_cache_dat_cor_err_o;
    logic evt_scrub_complete_o;
    logic evt_uncached_req_o;
    logic evt_cmo_req_o;
    logic evt_write_req_o;
    logic evt_read_req_o;
    logic evt_prefetch_req_o;
    logic evt_req_on_hold_o;
    logic evt_rtab_rollback_o;
    logic evt_stall_refill_o;
    logic evt_stall_o;
    logic wbuf_empty_o;
    logic wbuf_flush_i;

    // Config signals
    // FIX 4: cfg_wbuf_threshold_i phải dùng wbuf_timecnt_t (bitmatch với wrapper localparam type)
    logic                               cfg_enable_i;
    wbuf_timecnt_t                      cfg_wbuf_threshold_i;
    logic                               cfg_wbuf_reset_timecnt_on_write_i;
    logic                               cfg_wbuf_sequential_waw_i;
    logic                               cfg_wbuf_inhibit_write_coalescing_i;
    logic                               cfg_prefetch_updt_plru_i;
    logic                               cfg_error_on_cacheable_amo_i;
    logic                               cfg_rtab_single_entry_i;
    logic                               cfg_default_wb_i;
    logic                               cfg_scrub_enable_i;
    logic [5:0]                         cfg_scrub_period_i;
    logic                               cfg_scrub_restart_i;

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport driver_mp (
        input  clk_i, rst_ni,
        // Core request (drive)
        output core_req_valid_i, core_req_i, core_req_abort_i,
               core_req_tag_i, core_req_pma_i,
        // Core request ready (sample)
        input  core_req_ready_o,
        // Core response (sample)
        input  core_rsp_valid_o, core_rsp_o,
        // Config (drive)
        output cfg_enable_i, cfg_wbuf_threshold_i,
               cfg_wbuf_reset_timecnt_on_write_i, cfg_wbuf_sequential_waw_i,
               cfg_wbuf_inhibit_write_coalescing_i, cfg_prefetch_updt_plru_i,
               cfg_error_on_cacheable_amo_i, cfg_rtab_single_entry_i,
               cfg_default_wb_i, cfg_scrub_enable_i, cfg_scrub_period_i,
               cfg_scrub_restart_i, wbuf_flush_i,
        // Memory handshake inputs (drive)
        output mem_req_read_ready_i,
               mem_resp_read_valid_i, mem_resp_read_error_i,
               mem_resp_read_id_i, mem_resp_read_data_i, mem_resp_read_last_i,
               mem_req_write_ready_i, mem_req_write_data_ready_i,
               mem_resp_write_valid_i, mem_resp_write_is_atomic_i,
               mem_resp_write_error_i, mem_resp_write_id_i,
        // Memory outputs (sample)
        input  mem_req_read_valid_o, mem_req_read_addr_o, mem_req_read_id_o,
               mem_req_read_len_o, mem_req_read_size_o, mem_req_read_cacheable_o,
               mem_resp_read_ready_o,
               mem_req_write_valid_o, mem_req_write_addr_o, mem_req_write_id_o,
               mem_req_write_data_valid_o, mem_req_write_data_o, mem_req_write_be_o,
               mem_req_write_last_o, mem_resp_write_ready_o
    );

    modport monitor_mp (
        input  clk_i, rst_ni,
        input  core_req_valid_i, core_req_ready_o, core_req_i,
               core_req_tag_i, core_req_pma_i, core_req_abort_i,
               core_rsp_valid_o, core_rsp_o,
               mem_req_read_valid_o, mem_req_read_ready_i,
               mem_req_read_addr_o, mem_req_read_id_o,
               mem_resp_read_ready_o, mem_resp_read_valid_i,
               mem_resp_read_id_i, mem_resp_read_data_i, mem_resp_read_last_i,
               mem_req_write_valid_o, mem_req_write_ready_i,
               mem_req_write_data_valid_o, mem_req_write_data_o,
               mem_resp_write_valid_i, mem_resp_write_ready_o,
               evt_cache_read_miss_o, evt_cache_write_miss_o,
               evt_prefetch_req_o, evt_req_on_hold_o,
               evt_stall_refill_o, evt_stall_o, wbuf_empty_o
    );

endinterface : hpdcache_if

`endif // HPDCACHE_IF_SV
