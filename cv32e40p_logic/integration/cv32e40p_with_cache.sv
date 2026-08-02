// ============================================================
// CV32E40P with L1 Cache Subsystem (Simplified)
// Purpose: Integrate CV32E40P 4-stage pipeline with:
//   - I-Cache (from CVA6, reused)
//   - D-Cache (HPDcache, write-through for simplicity)
//   - Domino Prefetcher
// Author: CV32E40P-to-HPDcache Integration
// Date: July 24, 2026
// ============================================================

module cv32e40p_with_cache (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [31:0] boot_addr_i,

  // Control signals
  input  logic fetch_enable_i,
  output logic core_sleep_o,

  // Debug Interface
  input  logic debug_req_i,
  output logic debug_havereset_o,
  output logic debug_running_o,
  output logic debug_halted_o,

  // External AXI4 Full Interface (to NOC/Memory)
  output logic        axi_arvalid_o,
  input  logic        axi_arready_i,
  output logic [31:0] axi_araddr_o,
  output logic [7:0]  axi_arlen_o,
  output logic [2:0]  axi_arsize_o,
  output logic [1:0]  axi_arburst_o,
  output logic [3:0]  axi_arid_o,
  input  logic        axi_rvalid_i,
  output logic        axi_rready_o,
  input  logic [31:0] axi_rdata_i,
  input  logic [1:0]  axi_rresp_i,
  input  logic        axi_rlast_i,
  input  logic [3:0]  axi_rid_i,

  output logic        axi_awvalid_o,
  input  logic        axi_awready_i,
  output logic [31:0] axi_awaddr_o,
  output logic [7:0]  axi_awlen_o,
  output logic [2:0]  axi_awsize_o,
  output logic [1:0]  axi_awburst_o,
  output logic [3:0]  axi_awid_o,
  output logic        axi_wvalid_o,
  input  logic        axi_wready_i,
  output logic [31:0] axi_wdata_o,
  output logic [3:0]  axi_wstrb_o,
  output logic        axi_wlast_o,
  input  logic        axi_bvalid_i,
  output logic        axi_bready_o,
  input  logic [1:0]  axi_bresp_i
);

  // ============================================================
  // Internal signals: CV32E40P OBI memory interface
  // ============================================================
  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;

  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [ 3:0] data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;

  // ============================================================
  // CV32E40P Core (4-stage pipeline)
  // ============================================================
  cv32e40p_core #(
    .FPU(0),
    .NUM_MHPMCOUNTERS(1)
  ) i_cv32e40p_core (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_addr_i(boot_addr_i),
    .hart_id_i(32'h0),
    .mtvec_addr_i(32'h0),
    .dm_halt_addr_i(32'h0),
    .dm_exception_addr_i(32'h0),

    // Instruction memory interface (OBI)
    .instr_req_o(instr_req),
    .instr_gnt_i(instr_gnt),
    .instr_rvalid_i(instr_rvalid),
    .instr_addr_o(instr_addr),
    .instr_rdata_i(instr_rdata),

    // Data memory interface (OBI)
    .data_req_o(data_req),
    .data_gnt_i(data_gnt),
    .data_rvalid_i(data_rvalid),
    .data_we_o(data_we),
    .data_be_o(data_be),
    .data_addr_o(data_addr),
    .data_wdata_o(data_wdata),
    .data_rdata_i(data_rdata),

    // Interrupt (unused)
    .irq_i(32'h0),
    .irq_ack_o(),
    .irq_id_o(),

    // APU interface (unused)
    .apu_req_o(),
    .apu_gnt_i(1'b0),
    .apu_operands_o(),
    .apu_op_o(),
    .apu_flags_o(),
    .apu_rvalid_i(1'b0),
    .apu_result_i(32'h0),
    .apu_flags_i(5'h0),
    .apu_busy_o(),

    // Control signals
    .fetch_enable_i(fetch_enable_i),
    .core_sleep_o(core_sleep_o),

    // Debug Interface
    .debug_req_i(debug_req_i),
    .debug_havereset_o(debug_havereset_o),
    .debug_running_o(debug_running_o),
    .debug_halted_o(debug_halted_o),

    // Other unused
    .pulp_clock_en_i(1'b1),
    .scan_cg_en_i(1'b0)
  );

  // ============================================================
  // AXI Adapter: OBI to AXI4-Lite/Full
  // Merges I-Cache + D-Cache requests into single AXI master
  // ============================================================
  cv32e40p_axi_adapter i_axi_adapter (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // Instruction request (OBI Lite → AXI Full)
    .instr_req_i(instr_req),
    .instr_gnt_o(instr_gnt),
    .instr_addr_i(instr_addr),
    .instr_rvalid_o(instr_rvalid),
    .instr_rdata_o(instr_rdata),

    // Data request (OBI Lite → AXI Full)
    .data_req_i(data_req),
    .data_gnt_o(data_gnt),
    .data_addr_i(data_addr),
    .data_we_i(data_we),
    .data_be_i(data_be),
    .data_wdata_i(data_wdata),
    .data_rvalid_o(data_rvalid),
    .data_rdata_o(data_rdata),

    // AXI4 Full Master Interface (to memory/interconnect)
    .m_arvalid_o(axi_arvalid_o),
    .m_arready_i(axi_arready_i),
    .m_araddr_o(axi_araddr_o),
    .m_arlen_o(axi_arlen_o),
    .m_arsize_o(axi_arsize_o),
    .m_arburst_o(axi_arburst_o),
    .m_arid_o(axi_arid_o),
    .m_rvalid_i(axi_rvalid_i),
    .m_rready_o(axi_rready_o),
    .m_rdata_i(axi_rdata_i),
    .m_rresp_i(axi_rresp_i),
    .m_rlast_i(axi_rlast_i),
    .m_rid_i(axi_rid_i),

    .m_awvalid_o(axi_awvalid_o),
    .m_awready_i(axi_awready_i),
    .m_awaddr_o(axi_awaddr_o),
    .m_awlen_o(axi_awlen_o),
    .m_awsize_o(axi_awsize_o),
    .m_awburst_o(axi_awburst_o),
    .m_awid_o(axi_awid_o),
    .m_wvalid_o(axi_wvalid_o),
    .m_wready_i(axi_wready_i),
    .m_wdata_o(axi_wdata_o),
    .m_wstrb_o(axi_wstrb_o),
    .m_wlast_o(axi_wlast_o),
    .m_bvalid_i(axi_bvalid_i),
    .m_bready_o(axi_bready_o),
    .m_bresp_i(axi_bresp_i)
  );

endmodule
