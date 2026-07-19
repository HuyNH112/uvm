// =============================================================================
// hpdcache_uvm_pkg.sv
// UVM Package cho HPDcache Wrapper Testbench
//
// Quy tắc:
//   - KHÔNG dùng `CONF_HPDCACHE_* macro bên trong package
//     (macro +define+ không truyền vào package scope)
//   - Dùng UVM_HPDCACHE_* localparam hardcode thay thế
//   - import hpdcache_pkg::* để dùng types/functions từ RTL pkg
//
// Enum chính xác từ hpdcache_pkg.sv:
//   hpdcache_req_op_t  → HPDCACHE_REQ_LOAD, HPDCACHE_REQ_STORE,
//                        HPDCACHE_REQ_CMO_PREFETCH, HPDCACHE_REQ_AMO_LR, ...
//   hpdcache_pma_t     → { logic uncacheable; logic io; }
//   hpdcache_req_size_t→ logic [2:0]
//   is_load(op), is_store(op), is_amo(op) đã có trong hpdcache_pkg
//
// Tool: QuestaSim 23.3 Starter Edition, UVM 1.1d built-in
// =============================================================================
`ifndef HPDCACHE_UVM_PKG_SV
`define HPDCACHE_UVM_PKG_SV

package hpdcache_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import RTL package — cung cấp hpdcache_req_op_t, hpdcache_pma_t,
    // hpdcache_req_size_t, is_load(), is_store(), is_amo(), ...
    import hpdcache_pkg::*;

    // =========================================================================
    // Configuration localparams — hardcode từ hpdcache_config.svh
    // Cập nhật nếu cấu hình DUT thay đổi
    // =========================================================================
    localparam int unsigned UVM_HPDCACHE_PA_WIDTH            = 56;
    localparam int unsigned UVM_HPDCACHE_WORD_WIDTH          = 64;
    localparam int unsigned UVM_HPDCACHE_SETS                = 64;
    localparam int unsigned UVM_HPDCACHE_WAYS                = 8;
    localparam int unsigned UVM_HPDCACHE_CL_WORDS            = 8;
    localparam int unsigned UVM_HPDCACHE_REQ_WORDS           = 2;
    localparam int unsigned UVM_HPDCACHE_REQ_TRANS_ID_WIDTH  = 6;
    localparam int unsigned UVM_HPDCACHE_REQ_SRC_ID_WIDTH    = 3;
    localparam int unsigned UVM_HPDCACHE_MEM_ADDR_WIDTH      = 56;
    localparam int unsigned UVM_HPDCACHE_MEM_ID_WIDTH        = 8;
    localparam int unsigned UVM_HPDCACHE_MEM_DATA_WIDTH      = 512;
    localparam int unsigned UVM_HPDCACHE_WBUF_TIMECNT_WIDTH  = 4;
    localparam int unsigned UVM_HPDCACHE_MSHR_SETS           = 4;
    localparam int unsigned UVM_HPDCACHE_MSHR_WAYS           = 4;

    // =========================================================================
    // Derived widths
    // =========================================================================
    localparam int unsigned UVM_CL_OFFSET_WIDTH  = $clog2(UVM_HPDCACHE_CL_WORDS
                                                         * UVM_HPDCACHE_WORD_WIDTH / 8); // 6
    localparam int unsigned UVM_SET_WIDTH        = $clog2(UVM_HPDCACHE_SETS);             // 6
    localparam int unsigned UVM_TAG_WIDTH        = UVM_HPDCACHE_PA_WIDTH
                                                 - UVM_SET_WIDTH
                                                 - UVM_CL_OFFSET_WIDTH;                   // 44
    localparam int unsigned UVM_REQ_OFFSET_WIDTH = UVM_SET_WIDTH + UVM_CL_OFFSET_WIDTH;  // 12
    localparam int unsigned UVM_REQ_DATA_WIDTH   = UVM_HPDCACHE_REQ_WORDS
                                                 * UVM_HPDCACHE_WORD_WIDTH;               // 128
    localparam int unsigned UVM_REQ_BE_WIDTH     = UVM_HPDCACHE_REQ_WORDS
                                                 * (UVM_HPDCACHE_WORD_WIDTH / 8);         // 16

    // =========================================================================
    // Type aliases
    // =========================================================================
    typedef logic [UVM_TAG_WIDTH-1:0]                                           hpdcache_tag_t;
    typedef logic [UVM_REQ_OFFSET_WIDTH-1:0]                                    hpdcache_req_offset_t;
    typedef logic [UVM_HPDCACHE_REQ_WORDS-1:0][UVM_HPDCACHE_WORD_WIDTH-1:0]    hpdcache_req_data_t;
    typedef logic [UVM_HPDCACHE_REQ_WORDS-1:0][UVM_HPDCACHE_WORD_WIDTH/8-1:0]  hpdcache_req_be_t;
    typedef logic [UVM_HPDCACHE_REQ_SRC_ID_WIDTH-1:0]                          hpdcache_req_sid_t;
    typedef logic [UVM_HPDCACHE_REQ_TRANS_ID_WIDTH-1:0]                        hpdcache_req_tid_t;
    typedef logic [UVM_HPDCACHE_PA_WIDTH-1:0]                                  hpdcache_req_addr_t;
    typedef logic [UVM_SET_WIDTH-1:0]                                           hpdcache_set_t;
    typedef logic [UVM_HPDCACHE_MEM_ADDR_WIDTH-1:0]                            hpdcache_mem_addr_t;
    typedef logic [UVM_HPDCACHE_MEM_ID_WIDTH-1:0]                              hpdcache_mem_id_t;
    typedef logic [UVM_HPDCACHE_MEM_DATA_WIDTH-1:0]                            hpdcache_mem_data_t;
    typedef logic [UVM_HPDCACHE_MEM_DATA_WIDTH/8-1:0]                          hpdcache_mem_be_t;

    // =========================================================================
    // hpdcache_rsp_t
    // Field order khớp HPDCACHE_DECL_RSP_T macro
    // =========================================================================
    typedef struct packed {
        hpdcache_req_data_t  rdata;
        hpdcache_req_sid_t   sid;
        hpdcache_req_tid_t   tid;
        logic                error;
        logic                aborted;
    } hpdcache_rsp_t;

    // =========================================================================
    // hpdcache_req_mon_t — struct dùng trong monitor
    // =========================================================================
    typedef struct {
        hpdcache_req_offset_t    addr_offset;
        hpdcache_req_data_t      wdata;
        hpdcache_req_op_t        op;       // từ hpdcache_pkg::hpdcache_req_op_t
        hpdcache_req_be_t        be;
        hpdcache_req_size_t      size;     // từ hpdcache_pkg::hpdcache_req_size_t (logic[2:0])
        hpdcache_req_sid_t       sid;
        hpdcache_req_tid_t       tid;
        logic                    need_rsp;
        logic                    phys_indexed;
        hpdcache_tag_t           addr_tag;
        hpdcache_pma_t           pma;      // từ hpdcache_pkg::hpdcache_pma_t
        hpdcache_req_addr_t      addr;
        logic                    abort;
        logic                    second_cycle;
    } hpdcache_req_mon_t;

    // =========================================================================
    // Helper: is_cmo — hpdcache_pkg không có is_cmo tổng quát
    // CMO ops: HPDCACHE_REQ_CMO_FENCE..HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL
    // =========================================================================
    function automatic logic is_cmo(input hpdcache_req_op_t op);
        return (int'(op) >= int'(HPDCACHE_REQ_CMO_FENCE) &&
                int'(op) <= int'(HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL));
    endfunction

    // =========================================================================
    // UVM components — include order = dependency order
    // =========================================================================
    `include "hpdcache_seq_item.sv"
    `include "hpdcache_sequencer.sv"
    `include "hpdcache_driver.sv"
    `include "hpdcache_monitor.sv"
    `include "hpdcache_scoreboard.sv"
    `include "hpdcache_env.sv"
	// =========================================================================
    // ISA Agent classes — TC 1.1 (ALU), TC 1.2 (Branch), TC 1.3 (Exception)
    // =========================================================================
    `include "isa_seq_item.sv"
    `include "isa_commit_monitor.sv"
    `include "isa_csr_monitor.sv"
    `include "isa_driver.sv"
    `include "isa_sequencer.sv"
    `include "isa_agent.sv"
    `include "isa_scoreboard.sv"
endpackage : hpdcache_uvm_pkg

`endif // HPDCACHE_UVM_PKG_SV
