// ============================================================
// cv32e40p_dcache_wrapper.sv
//
// D-Cache Wrapper: CV32E40P OBI ↔ HPDcache Integration
//
// Top-level wrapper that combines:
//  1. cv32e40p_to_hpdcache_adapter (protocol bridge)
//  2. hpdcache_wrapper (D-Cache implementation)
//  3. AXI4 memory interface routing
//
// Presents OBI data interface (32-bit, 1-cycle) to CV32E40P
// Hides HPDcache complexity (512-bit, 2-cycle) internally
//
// Design Date: 28 July 2026
// Status: ✅ TASK 2 - D-Cache Instantiation
// ============================================================

`include "hpdcache_typedef.svh"

module cv32e40p_dcache_wrapper
  import hpdcache_pkg::*;
#(
  // Cache configuration
  parameter int SETS = 256,
  parameter int WAYS = 4,
  parameter int CACHE_LINE_SIZE = 64,  // bytes (512 bits / 8)
  parameter int WORD_WIDTH = 64,       // bits (HPDcache default)
  parameter int REQ_WORDS = 8,         // 8 words × 64-bit = 512-bit

  // Memory interface
  parameter int MEM_ADDR_WIDTH = 32,
  parameter int MEM_DATA_WIDTH = 256  // AXI default for L2
) (
  input logic clk_i,
  input logic rst_ni,

  // ===== CV32E40P OBI DATA INTERFACE (INPUT) =====
  // Standard OBI protocol (1-cycle, 32-bit)
  input logic        data_req_i,           // Request valid
  output logic       data_gnt_o,           // Grant (ready)
  input logic [31:0] data_addr_i,          // Address
  input logic        data_we_i,            // Write enable
  input logic [3:0]  data_be_i,            // Byte enables
  input logic [31:0] data_wdata_i,         // Write data

  // Read response (from cache)
  output logic       data_rvalid_o,        // Response valid
  output logic [31:0] data_rdata_o,        // Read data
  output logic       data_err_o,           // Error

  // ===== AXI4 MEMORY INTERFACE (L2 Cache) =====
  // Write address channel
  output logic       axi_aw_valid_o,
  input logic        axi_aw_ready_i,
  output logic [MEM_ADDR_WIDTH-1:0] axi_aw_addr_o,
  output logic [7:0] axi_aw_len_o,
  output logic [2:0] axi_aw_size_o,
  output logic [1:0] axi_aw_burst_o,
  output logic [3:0] axi_aw_id_o,

  // Write data channel
  output logic       axi_w_valid_o,
  input logic        axi_w_ready_i,
  output logic [MEM_DATA_WIDTH-1:0] axi_w_data_o,
  output logic [MEM_DATA_WIDTH/8-1:0] axi_w_strb_o,
  output logic       axi_w_last_o,

  // Write response channel
  input logic        axi_b_valid_i,
  output logic       axi_b_ready_o,
  input logic [3:0]  axi_b_id_i,

  // Read address channel
  output logic       axi_ar_valid_o,
  input logic        axi_ar_ready_i,
  output logic [MEM_ADDR_WIDTH-1:0] axi_ar_addr_o,
  output logic [7:0] axi_ar_len_o,
  output logic [2:0] axi_ar_size_o,
  output logic [1:0] axi_ar_burst_o,
  output logic [3:0] axi_ar_id_o,

  // Read data channel
  input logic        axi_r_valid_i,
  output logic       axi_r_ready_o,
  input logic [MEM_DATA_WIDTH-1:0] axi_r_data_i,
  input logic [3:0]  axi_r_id_i,
  input logic [1:0]  axi_r_resp_i,
  input logic        axi_r_last_i
);

  // ===== INTERNAL SIGNALS =====

  // Adapter ↔ HPDcache interface
  logic                           adp_req_valid;
  logic                           adp_req_ready;
  hpdcache_req_t                  adp_req;
  logic                           adp_req_tag_valid;
  logic [18:0]                    adp_req_tag;      // 18-bit tag (32 - 6 - 8)
  hpdcache_pma_t                  adp_req_pma;

  logic                           adp_rsp_valid;
  hpdcache_rsp_t                  adp_rsp;

  // HPDcache configuration (build at runtime)
  localparam hpdcache_user_cfg_t UserCfg = '{
    nRequesters: 1,              // Single requester (CV32E40P)
    paWidth: 32,                 // 32-bit physical address
    wordWidth: 64,               // 64-bit word
    sets: SETS,                  // 256 sets
    ways: WAYS,                  // 4 ways (4-way associative)
    clWords: 8,                  // 512 bits / 64 bits = 8 words
    reqWords: REQ_WORDS,         // Request data width in words (8)
    reqTransIdWidth: 2,          // 2-bit transaction ID
    reqSrcIdWidth: 1,            // 1-bit source ID (only 1 requester)
    victimSel: 1,                // PLRU replacement
    dataWaysPerRamWord: 2,
    dataSetsPerRam: 16,
    dataRamByteEnable: 1,
    accessWords: 8,              // Access width in words
    mshrSets: 16,                // MSHR sets
    mshrWays: 4,                 // MSHR ways
    mshrWaysPerRamWord: 2,
    mshrSetsPerRam: 8,
    mshrRamByteEnable: 1,
    mshrUseRegbank: 0,
    cbufEntries: 4,
    refillCoreRspFeedthrough: 1,
    refillFifoDepth: 2,
    wbufDirEntries: 16,
    wbufDataEntries: 16,
    wbufWords: 8,
    wbufTimecntWidth: 8,
    rtabEntries: 16,
    flushEntries: 8,
    flushFifoDepth: 4,
    memAddrWidth: MEM_ADDR_WIDTH,
    memIdWidth: 4,
    memDataWidth: MEM_DATA_WIDTH,
    wtEn: 1,
    wbEn: 1,
    lowLatency: 1,
    eccEn: 0,
    eccScrubberEn: 0
  };

  localparam hpdcache_cfg_t Cfg = hpdcacheBuildConfig(UserCfg);

  // ===== TYPEDEFS =====
  typedef logic [Cfg.tagWidth-1:0] hpdcache_tag_t;
  typedef logic [Cfg.u.wordWidth-1:0] hpdcache_data_word_t;
  typedef logic [Cfg.u.wordWidth/8-1:0] hpdcache_data_be_t;
  typedef logic [Cfg.reqOffsetWidth-1:0] hpdcache_req_offset_t;
  typedef logic [Cfg.u.reqWords-1:0][Cfg.u.wordWidth-1:0] hpdcache_req_data_t;
  typedef logic [Cfg.u.reqWords-1:0][Cfg.u.wordWidth/8-1:0] hpdcache_req_be_t;
  typedef logic [Cfg.u.reqSrcIdWidth-1:0] hpdcache_req_sid_t;
  typedef logic [Cfg.u.reqTransIdWidth-1:0] hpdcache_req_tid_t;
  typedef `HPDCACHE_DECL_REQ_T(
    hpdcache_req_offset_t,
    hpdcache_req_data_t,
    hpdcache_req_be_t,
    hpdcache_req_sid_t,
    hpdcache_req_tid_t,
    hpdcache_tag_t
  ) hpdcache_req_t;

  typedef `HPDCACHE_DECL_RSP_T(
    hpdcache_req_data_t,
    hpdcache_req_sid_t,
    hpdcache_req_tid_t
  ) hpdcache_rsp_t;

  typedef logic [Cfg.u.memAddrWidth-1:0] hpdcache_mem_addr_t;
  typedef logic [Cfg.u.memIdWidth-1:0] hpdcache_mem_id_t;
  typedef logic [Cfg.u.memDataWidth-1:0] hpdcache_mem_data_t;
  typedef logic [Cfg.u.memDataWidth/8-1:0] hpdcache_mem_be_t;

  // ===== INSTANTIATE PROTOCOL ADAPTER =====
  cv32e40p_to_hpdcache_adapter #(
    .OFFSET_WIDTH(Cfg.reqOffsetWidth),
    .INDEX_WIDTH(8),                              // log2(256 sets)
    .TAG_WIDTH(Cfg.tagWidth),
    .REQ_WORDS(REQ_WORDS),
    .WORD_WIDTH(WORD_WIDTH),
    .REQ_SRC_ID_WIDTH(Cfg.u.reqSrcIdWidth),
    .REQ_TRANS_ID_WIDTH(Cfg.u.reqTransIdWidth)
  ) u_adapter (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // OBI interface (from CV32E40P)
    .obi_req_i(data_req_i),
    .obi_gnt_o(data_gnt_o),
    .obi_addr_i(data_addr_i),
    .obi_we_i(data_we_i),
    .obi_be_i(data_be_i),
    .obi_wdata_i(data_wdata_i),

    // Response (to CV32E40P)
    .obi_rvalid_o(data_rvalid_o),
    .obi_rdata_o(data_rdata_o),
    .obi_err_o(data_err_o),

    // HPDcache interface (to cache)
    .hpd_req_valid_o(adp_req_valid),
    .hpd_req_ready_i(adp_req_ready),
    .hpd_req_o(adp_req),
    .hpd_req_tag_valid_o(adp_req_tag_valid),
    .hpd_req_tag_o(adp_req_tag),
    .hpd_req_pma_o(adp_req_pma),
    .hpd_rsp_valid_i(adp_rsp_valid),
    .hpd_rsp_i(adp_rsp)
  );

  // ===== INSTANTIATE HPDCACHE D-CACHE =====
  hpdcache_wrapper #(
    .hpdcache_user_cfg_t(UserCfg),
    .hpdcache_cfg_t(Cfg),
    .hpdcache_tag_t(hpdcache_tag_t),
    .hpdcache_data_word_t(hpdcache_data_word_t),
    .hpdcache_data_be_t(hpdcache_data_be_t),
    .hpdcache_req_offset_t(hpdcache_req_offset_t),
    .hpdcache_req_data_t(hpdcache_req_data_t),
    .hpdcache_req_be_t(hpdcache_req_be_t),
    .hpdcache_req_sid_t(hpdcache_req_sid_t),
    .hpdcache_req_tid_t(hpdcache_req_tid_t),
    .hpdcache_req_t(hpdcache_req_t),
    .hpdcache_rsp_t(hpdcache_rsp_t),
    .hpdcache_mem_addr_t(hpdcache_mem_addr_t),
    .hpdcache_mem_id_t(hpdcache_mem_id_t),
    .hpdcache_mem_data_t(hpdcache_mem_data_t),
    .hpdcache_mem_be_t(hpdcache_mem_be_t),
    .hpdcache_nline_t(logic [Cfg.nlineWidth-1:0])
  ) u_dcache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .wbuf_flush_i(1'b0),  // No flush requested by default

    // Core request interface (from adapter)
    .core_req_valid_i(adp_req_valid),
    .core_req_ready_o(adp_req_ready),
    .core_req_i(adp_req),
    .core_req_abort_i(1'b0),
    .core_req_tag_i(adp_req_tag),
    .core_req_pma_i(adp_req_pma),

    // Core response interface (to adapter)
    .core_rsp_valid_o(adp_rsp_valid),
    .core_rsp_o(adp_rsp),

    // Memory read interface (to AXI L2)
    .mem_req_read_ready_i(axi_ar_ready_i),
    .mem_req_read_valid_o(axi_ar_valid_o),
    .mem_req_read_addr_o(axi_ar_addr_o),
    .mem_req_read_len_o(axi_ar_len_o),
    .mem_req_read_size_o(axi_ar_size_o),
    .mem_req_read_id_o(axi_ar_id_o),
    .mem_req_read_command_o(),           // Always READ
    .mem_req_read_atomic_o(),            // No atomic
    .mem_req_read_cacheable_o(),         // Always cacheable

    .mem_resp_read_ready_o(axi_r_ready_o),
    .mem_resp_read_valid_i(axi_r_valid_i),
    .mem_resp_read_error_i('0),
    .mem_resp_read_id_i(axi_r_id_i),
    .mem_resp_read_data_i(axi_r_data_i),
    .mem_resp_read_last_i(axi_r_last_i),

    // Memory write interface (to AXI L2)
    .mem_req_write_ready_i(axi_aw_ready_i),
    .mem_req_write_valid_o(axi_aw_valid_o),
    .mem_req_write_addr_o(axi_aw_addr_o),
    .mem_req_write_len_o(axi_aw_len_o),
    .mem_req_write_size_o(axi_aw_size_o),
    .mem_req_write_id_o(axi_aw_id_o),
    .mem_req_write_command_o(),
    .mem_req_write_atomic_o(),
    .mem_req_write_cacheable_o(),

    .mem_req_write_data_ready_i(axi_w_ready_i),
    .mem_req_write_data_valid_o(axi_w_valid_o),
    .mem_req_write_data_o(axi_w_data_o),
    .mem_req_write_strb_o(axi_w_strb_o),
    .mem_req_write_last_o(axi_w_last_o),

    .mem_resp_write_ready_o(axi_b_ready_o),
    .mem_resp_write_valid_i(axi_b_valid_i),
    .mem_resp_write_error_i('0),
    .mem_resp_write_id_i(axi_b_id_i)
  );

  // ===== AXI PROTOCOL ENFORCEMENT =====
  // Set default burst types
  assign axi_aw_burst_o = 2'b01;  // INCR burst
  assign axi_ar_burst_o = 2'b01;  // INCR burst

endmodule : cv32e40p_dcache_wrapper

