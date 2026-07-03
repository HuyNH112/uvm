`ifndef HPDCACHE_UVM_PKG_SV
`define HPDCACHE_UVM_PKG_SV

package hpdcache_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import hpdcache_pkg::*;

    // ========================================================================
    //  Configuration parameters — cv32a6_imac_sv32
    //  (phai khop voi CONF_HPDCACHE_* macro dung trong hpdcache_if.sv /
    //   hpdcache_wrapper.sv)
    // ========================================================================
    localparam int unsigned UVM_HPDCACHE_PA_WIDTH           = 32;
    localparam int unsigned UVM_HPDCACHE_WORD_WIDTH         = 64;
    localparam int unsigned UVM_HPDCACHE_SETS               = 256;
    localparam int unsigned UVM_HPDCACHE_WAYS               = 8;
    localparam int unsigned UVM_HPDCACHE_CL_WORDS           = 8;
    localparam int unsigned UVM_HPDCACHE_REQ_WORDS          = 1;
    localparam int unsigned UVM_HPDCACHE_REQ_TRANS_ID_WIDTH = 8;
    localparam int unsigned UVM_HPDCACHE_REQ_SRC_ID_WIDTH   = 3;
    localparam int unsigned UVM_HPDCACHE_MEM_ADDR_WIDTH     = 32;
    localparam int unsigned UVM_HPDCACHE_MEM_ID_WIDTH       = 8;
    localparam int unsigned UVM_HPDCACHE_MEM_DATA_WIDTH     = 64;

    // Derived widths
    localparam int unsigned UVM_CL_OFFSET_WIDTH  = $clog2(UVM_HPDCACHE_CL_WORDS *
                                                           UVM_HPDCACHE_WORD_WIDTH / 8); // 6
    localparam int unsigned UVM_SET_WIDTH        = $clog2(UVM_HPDCACHE_SETS);            // 8
    localparam int unsigned UVM_NLINE_WIDTH      = UVM_HPDCACHE_PA_WIDTH -
                                                   UVM_CL_OFFSET_WIDTH;                  // 26
    localparam int unsigned UVM_TAG_WIDTH        = UVM_NLINE_WIDTH - UVM_SET_WIDTH;      // 18
    localparam int unsigned UVM_REQ_OFFSET_WIDTH = UVM_HPDCACHE_PA_WIDTH -
                                                   UVM_TAG_WIDTH;                        // 14
    localparam int unsigned UVM_REQ_DATA_WIDTH   = UVM_HPDCACHE_REQ_WORDS *
                                                   UVM_HPDCACHE_WORD_WIDTH;              // 64

    // ========================================================================
    //  Field-level types — dung chung cho seq_item / driver / monitor /
    //  scoreboard / coverage. Khop bit-width voi type tu sinh trong
    //  hpdcache_if.sv (qua HPDCACHE_DECL_REQ_T / HPDCACHE_DECL_RSP_T).
    // ========================================================================
    typedef logic [UVM_TAG_WIDTH-1:0]                                       hpdcache_tag_t;
    typedef logic [UVM_REQ_OFFSET_WIDTH-1:0]                                hpdcache_req_offset_t;
    typedef logic [UVM_HPDCACHE_REQ_WORDS-1:0][UVM_HPDCACHE_WORD_WIDTH-1:0]   hpdcache_req_data_t;
    typedef logic [UVM_HPDCACHE_REQ_WORDS-1:0][UVM_HPDCACHE_WORD_WIDTH/8-1:0] hpdcache_req_be_t;
    typedef logic [UVM_HPDCACHE_REQ_SRC_ID_WIDTH-1:0]                       hpdcache_req_sid_t;
    typedef logic [UVM_HPDCACHE_REQ_TRANS_ID_WIDTH-1:0]                     hpdcache_req_tid_t;
    typedef logic [UVM_HPDCACHE_PA_WIDTH-1:0]                               hpdcache_req_addr_t;
    typedef logic [UVM_SET_WIDTH-1:0]                                       hpdcache_set_t;
    typedef logic [UVM_HPDCACHE_MEM_ADDR_WIDTH-1:0]                         hpdcache_mem_addr_t;
    typedef logic [UVM_HPDCACHE_MEM_ID_WIDTH-1:0]                           hpdcache_mem_id_t;
    typedef logic [UVM_HPDCACHE_MEM_DATA_WIDTH-1:0]                         hpdcache_mem_data_t;
    typedef logic [UVM_HPDCACHE_MEM_DATA_WIDTH/8-1:0]                       hpdcache_mem_be_t;

    // ========================================================================
    //  hpdcache_rsp_t
    //  Field order khop HPDCACHE_DECL_RSP_T trong hpdcache_typedef.svh:
    //    rdata, sid, tid, error, aborted
    // ========================================================================
    typedef struct packed {
        hpdcache_req_data_t  rdata;
        hpdcache_req_sid_t   sid;
        hpdcache_req_tid_t   tid;
        logic                error;
        logic                aborted;
    } hpdcache_rsp_t;

    // ========================================================================
    //  hpdcache_req_mon_t
    //  Struct quan sat boi monitor: mo rong tu cac field cua hpdcache_req_t
    //  (addr_offset, wdata, op, be, size, sid, tid, need_rsp, phys_indexed,
    //   addr_tag, pma — dung khop HPDCACHE_DECL_REQ_T) cong them metadata
    //  quan sat duoc (addr ghep, abort, second_cycle cho virtually-indexed).
    //  KHONG packed — day la transaction object noi bo cua testbench,
    //  khong can anh xa bit-for-bit voi DUT.
    // ========================================================================
    typedef struct {
        // --- Cac field nguyen ban tu hpdcache_req_t (Phase 1) ---
        hpdcache_req_offset_t       addr_offset;
        hpdcache_req_data_t         wdata;
        hpdcache_pkg::hpdcache_req_op_t   op;
        hpdcache_req_be_t           be;
        hpdcache_pkg::hpdcache_req_size_t size;
        hpdcache_req_sid_t          sid;
        hpdcache_req_tid_t          tid;
        logic                       need_rsp;
        logic                       phys_indexed;
        hpdcache_tag_t              addr_tag;
        hpdcache_pkg::hpdcache_pma_t      pma;

        // --- Metadata quan sat boi monitor ---
        hpdcache_req_addr_t         addr;          // {addr_tag, addr_offset} ghep san
        logic                       abort;          // core_req_abort_i (Phase 2)
        logic                       second_cycle;   // 1 neu day la sample Phase 2
    } hpdcache_req_mon_t;

    // ========================================================================
    //  UVM components — included in dependency order
    // ========================================================================
    `include "hpdcache_seq_item.sv"
    `include "hpdcache_sequencer.sv"
    `include "hpdcache_driver.sv"
    `include "hpdcache_monitor.sv"
    `include "hpdcache_scoreboard.sv"
    `include "hpdcache_coverage.sv"
    `include "hpdcache_env.sv"

endpackage : hpdcache_uvm_pkg

`endif // HPDCACHE_UVM_PKG_SV
