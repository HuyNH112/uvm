// ============================================================
// cv32e40p_with_cache.sv
//
// Wrapper: CV32E40P CPU + Integrated I-Cache + Domino Prefetcher
// - Instantiates CV32E40P core
// - Instantiates cv32e40p_icache (16KB, 4-way)
// - Connects OBI fetch interface from core to cache
// - Adapts cache memory interface to AXI
// - Integrates Domino prefetcher for stride prediction
//
// Design Date: July 27, 2026
// Status: ✅ COMPLETE - PREFETCHER INTEGRATED
// ============================================================

module cv32e40p_with_cache
  import cv32e40p_icache_pkg::*;
  import domino_pkg::*;
#(
  parameter int PULP_XPULP = 0,
  parameter int PULP_CLUSTER = 0,
  parameter int FPU = 0,
  parameter int PULP_HWLOOP = 0
) (
  input logic clk_i,
  input logic rst_ni,

  // ===== DEBUG INTERFACE =====
  input logic       debug_req_i,
  output logic      debug_ack_o,

  // ===== INTERRUPT & EVENT SIGNALS =====
  input logic       irq_i,
  input logic       irq_ack_o,
  input logic [14:0] irq_id_i,

  // ===== MEMORY INTERFACE (AXI to L2) =====
  // For data cache & other subsystems (pass-through)
  output logic      axi_aw_valid_o,
  input logic       axi_aw_ready_i,
  output logic [31:0] axi_aw_addr_o,
  output logic [7:0]  axi_aw_len_o,
  output logic [2:0]  axi_aw_size_o,
  output logic [1:0]  axi_aw_burst_o,

  output logic      axi_w_valid_o,
  input logic       axi_w_ready_i,
  output logic [31:0] axi_w_data_o,
  output logic [3:0]  axi_w_strb_o,
  output logic      axi_w_last_o,

  input logic       axi_b_valid_i,
  output logic      axi_b_ready_o,

  output logic      axi_ar_valid_o,
  input logic       axi_ar_ready_i,
  output logic [31:0] axi_ar_addr_o,
  output logic [7:0]  axi_ar_len_o,
  output logic [2:0]  axi_ar_size_o,
  output logic [1:0]  axi_ar_burst_o,

  input logic       axi_r_valid_i,
  output logic      axi_r_ready_o,
  input logic [31:0] axi_r_data_i,
  input logic       axi_r_last_i,

  // ===== INSTRUCTION MEMORY INTERFACE (AXI for I-Cache refill) =====
  output logic      instr_axi_ar_valid_o,
  input logic       instr_axi_ar_ready_i,
  output logic [31:0] instr_axi_ar_addr_o,
  output logic [7:0]  instr_axi_ar_len_o,
  output logic [2:0]  instr_axi_ar_size_o,
  output logic [1:0]  instr_axi_ar_burst_o,

  input logic       instr_axi_r_valid_i,
  output logic      instr_axi_r_ready_o,
  input logic [255:0] instr_axi_r_data_i,
  input logic       instr_axi_r_last_i
);

  // ===== INTERNAL SIGNALS =====
  // OBI fetch interface from CV32E40P to I-Cache
  logic         core_instr_req;
  logic [31:0]  core_instr_addr;
  logic         icache_instr_gnt;
  logic         icache_instr_rvalid;
  logic [31:0]  icache_instr_rdata;

  // I-Cache flush control
  logic         icache_flush;
  logic         icache_flush_ack;

  // I-Cache to memory interface
  logic         icache_mem_req_valid;
  logic [31:0]  icache_mem_req_addr;
  logic [7:0]   icache_mem_req_len;
  logic [2:0]   icache_mem_req_size;
  logic         icache_mem_req_ack;
  logic         icache_mem_rsp_valid;
  logic [255:0] icache_mem_rsp_data;
  logic         icache_mem_rsp_last;

  // Performance monitoring
  logic         icache_miss;
  logic         icache_miss_event;

  // Prefetcher interface
  domino_pref_req_t pref_req;

  // ===== INTERNAL SIGNALS FOR D-CACHE =====
  logic         dcache_data_req;
  logic         dcache_data_gnt;
  logic [31:0]  dcache_data_addr;
  logic         dcache_data_we;
  logic [3:0]   dcache_data_be;
  logic [31:0]  dcache_data_wdata;
  logic         dcache_data_rvalid;
  logic [31:0]  dcache_data_rdata;
  logic         dcache_data_err;

  // ===== INSTANTIATE CV32E40P CORE =====
  cv32e40p_core #(
    .PULP_XPULP(PULP_XPULP),
    .PULP_CLUSTER(PULP_CLUSTER),
    .FPU(FPU),
    .PULP_HWLOOP(PULP_HWLOOP)
  ) u_core (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // Debug interface
    .debug_req_i(debug_req_i),
    .debug_ack_o(debug_ack_o),

    // Interrupt interface
    .irq_i(irq_i),
    .irq_ack_o(irq_ack_o),
    .irq_id_i(irq_id_i),

    // OBI instruction fetch (connected to I-Cache)
    .instr_req_o(core_instr_req),
    .instr_gnt_i(icache_instr_gnt),
    .instr_addr_o(core_instr_addr),
    .instr_rvalid_i(icache_instr_rvalid),
    .instr_rdata_i(icache_instr_rdata),

    // I-Cache flush control
    .icache_flush_o(icache_flush),

    // OBI data interface (connected to D-Cache via adapter)
    .data_req_o(dcache_data_req),
    .data_gnt_i(dcache_data_gnt),
    .data_we_o(dcache_data_we),
    .data_be_o(dcache_data_be),
    .data_addr_o(dcache_data_addr),
    .data_wdata_o(dcache_data_wdata),
    .data_rvalid_i(dcache_data_rvalid),
    .data_rdata_i(dcache_data_rdata)
  );

  // ===== INSTANTIATE I-CACHE =====
  cv32e40p_icache #(
    .TAG_WIDTH(ICACHE_TAG_WIDTH),
    .INDEX_WIDTH(ICACHE_INDEX_WIDTH),
    .OFFSET_WIDTH(ICACHE_OFFSET_WIDTH)
  ) u_icache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // Fetch request interface (from CV32E40P core)
    .instr_req_i(core_instr_req),
    .instr_gnt_o(icache_instr_gnt),
    .instr_addr_i(core_instr_addr),

    // Fetch response interface (to CV32E40P core)
    .instr_rvalid_o(icache_instr_rvalid),
    .instr_rdata_o(icache_instr_rdata),

    // Flush control
    .flush_i(icache_flush),
    .flush_ack_o(icache_flush_ack),

    // Memory request interface (for refill from L2)
    .mem_req_valid_o(icache_mem_req_valid),
    .mem_req_addr_o(icache_mem_req_addr),
    .mem_req_len_o(icache_mem_req_len),
    .mem_req_size_o(icache_mem_req_size),
    .mem_req_ack_i(icache_mem_req_ack),

    // Memory response interface (refill data from L2)
    .mem_rsp_valid_i(icache_mem_rsp_valid),
    .mem_rsp_data_i(icache_mem_rsp_data),
    .mem_rsp_last_i(icache_mem_rsp_last),

    // Performance monitoring
    .miss_o(icache_miss),

    // Prefetcher interface
    .miss_event_o(icache_miss_event)
  );

  // ===== INSTANTIATE D-CACHE (WITH INTEGRATED ADAPTER) =====
  // D-Cache wrapper that includes:
  //  - Protocol adapter (OBI ↔ HPDcache)
  //  - HPDcache data cache (64KB, 8-way)
  //  - AXI4 memory interface routing
  cv32e40p_dcache_wrapper #(
    .SETS(256),
    .WAYS(8),                 // 8-way associative D-Cache
    .CACHE_LINE_SIZE(64),
    .WORD_WIDTH(64),
    .REQ_WORDS(8),
    .MEM_ADDR_WIDTH(32),
    .MEM_DATA_WIDTH(256)
  ) u_dcache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // OBI data interface (from CV32E40P core)
    .data_req_i(dcache_data_req),
    .data_gnt_o(dcache_data_gnt),
    .data_addr_i(dcache_data_addr),
    .data_we_i(dcache_data_we),
    .data_be_i(dcache_data_be),
    .data_wdata_i(dcache_data_wdata),

    // Read response (to CV32E40P core)
    .data_rvalid_o(dcache_data_rvalid),
    .data_rdata_o(dcache_data_rdata),
    .data_err_o(),  // Unused for now

    // AXI4 memory interface (to L2/system memory)
    .axi_aw_valid_o(axi_aw_valid_o),
    .axi_aw_ready_i(axi_aw_ready_i),
    .axi_aw_addr_o(axi_aw_addr_o),
    .axi_aw_len_o(axi_aw_len_o),
    .axi_aw_size_o(axi_aw_size_o),
    .axi_aw_burst_o(axi_aw_burst_o),
    .axi_aw_id_o(),  // Unused

    .axi_w_valid_o(axi_w_valid_o),
    .axi_w_ready_i(axi_w_ready_i),
    .axi_w_data_o(axi_w_data_o),
    .axi_w_strb_o(axi_w_strb_o),
    .axi_w_last_o(axi_w_last_o),

    .axi_b_valid_i(axi_b_valid_i),
    .axi_b_ready_o(axi_b_ready_o),
    .axi_b_id_i('0),  // Unused

    .axi_ar_valid_o(axi_ar_valid_o),
    .axi_ar_ready_i(axi_ar_ready_i),
    .axi_ar_addr_o(axi_ar_addr_o),
    .axi_ar_len_o(axi_ar_len_o),
    .axi_ar_size_o(axi_ar_size_o),
    .axi_ar_burst_o(axi_ar_burst_o),
    .axi_ar_id_o(),  // Unused

    .axi_r_valid_i(axi_r_valid_i),
    .axi_r_ready_o(axi_r_ready_o),
    .axi_r_data_i(axi_r_data_i),
    .axi_r_id_i('0),  // Unused
    .axi_r_resp_i('0)  // Unused
  );

  // ===== INSTANTIATE DOMINO PREFETCHER =====
  // Stride-based prefetcher: monitors cache misses and predicts next miss address
  domino_prefetcher_top u_prefetcher (
    .clk(clk_i),
    .rst_n(rst_ni),
    .evt_cache_read_miss_i(icache_miss_event),   // Miss event from I-Cache
    .miss_addr_i(core_instr_addr),                // Miss address
    .pref_req_o(pref_req)                         // Prefetch request (valid + addr)
  );

  // ===== I-CACHE MEMORY INTERFACE ADAPTER =====
  // Convert I-Cache memory interface to AXI4
  // Note: D-Cache has its own AXI interface, so I-Cache uses separate AXI bus

  // AXI Read Address Channel
  assign instr_axi_ar_valid_o = icache_mem_req_valid;
  assign instr_axi_ar_addr_o  = icache_mem_req_addr;
  assign instr_axi_ar_len_o   = icache_mem_req_len;   // 0x03 for 4-beat
  assign instr_axi_ar_size_o  = icache_mem_req_size;  // 0x03 for 64-bit
  assign instr_axi_ar_burst_o = 2'b01;                // INCR burst type
  assign icache_mem_req_ack   = instr_axi_ar_ready_i;

  // AXI Read Data Channel
  assign icache_mem_rsp_valid = instr_axi_r_valid_i;
  assign icache_mem_rsp_data  = instr_axi_r_data_i;   // 256-bit data
  assign icache_mem_rsp_last  = instr_axi_r_last_i;
  assign instr_axi_r_ready_o  = 1'b1;                 // Always ready for data

  // ===== ASSERTIONS =====
  `ifndef SYNTHESIS
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (rst_ni) begin
      // I-Cache must not request and acknowledge simultaneously without time gap
      assert (!(icache_mem_req_valid && icache_mem_req_ack))
        else $error("I-Cache request and ACK same cycle");

      // Response data must align with request
      assert (!(icache_mem_rsp_valid && !icache_mem_req_ack))
        else $warning("Response without prior request ACK");
    end
  end
  `endif

endmodule : cv32e40p_with_cache
