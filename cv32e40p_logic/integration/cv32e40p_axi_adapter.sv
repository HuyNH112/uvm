// ============================================================
// CV32E40P OBI to AXI4 Adapter
// Purpose: Convert CV32E40P OBI (Open Bus Interface) memory
//          requests to AXI4 Full protocol for cache subsystem
// Author: CV32E40P-to-HPDcache Integration
// Date: July 24, 2026
// ============================================================

module cv32e40p_axi_adapter #(
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter int unsigned AXI_ID_WIDTH   = 4
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  // ============================================================
  // CV32E40P OBI SLAVE Interface (receiving from CPU)
  // ============================================================

  // Instruction memory interface
  input  logic                        instr_req_i,
  output logic                        instr_gnt_o,
  input  logic [AXI_ADDR_WIDTH-1:0]   instr_addr_i,
  output logic                        instr_rvalid_o,
  output logic [AXI_DATA_WIDTH-1:0]   instr_rdata_o,

  // Data memory interface
  input  logic                        data_req_i,
  output logic                        data_gnt_o,
  input  logic [AXI_ADDR_WIDTH-1:0]   data_addr_i,
  input  logic                        data_we_i,
  input  logic [AXI_DATA_WIDTH/8-1:0] data_be_i,
  input  logic [AXI_DATA_WIDTH-1:0]   data_wdata_i,
  output logic                        data_rvalid_o,
  output logic [AXI_DATA_WIDTH-1:0]   data_rdata_o,

  // ============================================================
  // AXI4 Full MASTER Interface (sending to memory/cache)
  // ============================================================

  // Read Address Channel
  output logic                        m_arvalid_o,
  input  logic                        m_arready_i,
  output logic [AXI_ADDR_WIDTH-1:0]   m_araddr_o,
  output logic [2:0]                  m_arsize_o,
  output logic [1:0]                  m_arburst_o,
  output logic [7:0]                  m_arlen_o,
  output logic [AXI_ID_WIDTH-1:0]     m_arid_o,

  // Read Data Channel
  input  logic                        m_rvalid_i,
  output logic                        m_rready_o,
  input  logic [AXI_DATA_WIDTH-1:0]   m_rdata_i,
  input  logic [1:0]                  m_rresp_i,
  input  logic                        m_rlast_i,
  input  logic [AXI_ID_WIDTH-1:0]     m_rid_i,

  // Write Address Channel
  output logic                        m_awvalid_o,
  input  logic                        m_awready_i,
  output logic [AXI_ADDR_WIDTH-1:0]   m_awaddr_o,
  output logic [2:0]                  m_awsize_o,
  output logic [1:0]                  m_awburst_o,
  output logic [7:0]                  m_awlen_o,
  output logic [AXI_ID_WIDTH-1:0]     m_awid_o,

  // Write Data Channel
  output logic                        m_wvalid_o,
  input  logic                        m_wready_i,
  output logic [AXI_DATA_WIDTH-1:0]   m_wdata_o,
  output logic [AXI_DATA_WIDTH/8-1:0] m_wstrb_o,
  output logic                        m_wlast_o,

  // Write Response Channel
  input  logic                        m_bvalid_i,
  output logic                        m_bready_o,
  input  logic [1:0]                  m_bresp_i
);

  // ============================================================
  // Simple OBI→AXI passthrough (Phase 1: Proof of concept)
  // For full cache integration, add burst generation here
  // ============================================================

  // Read path (instruction & data)
  // Priority: Instruction > Data (simple arbitration)
  logic is_read;
  assign is_read = instr_req_i | data_req_i;

  // Select source (instr has priority)
  logic [AXI_ADDR_WIDTH-1:0] read_addr;
  logic read_valid;

  assign read_addr = instr_req_i ? instr_addr_i : data_addr_i;
  assign read_valid = instr_req_i | data_req_i;

  // AXI read address channel
  assign m_arvalid_o = read_valid & ~m_awvalid_o;  // Don't send AR while write is active
  assign m_araddr_o = read_addr;
  assign m_arsize_o = 3'b010;  // 4 bytes
  assign m_arburst_o = 2'b01;  // INCR
  assign m_arlen_o = 8'd0;     // Single beat
  assign m_arid_o = instr_req_i ? 4'h0 : 4'h1;  // ID distinguishes instr vs data

  // AXI read data channel
  assign m_rready_o = 1'b1;  // Always ready
  assign instr_rvalid_o = m_rvalid_i & (m_rid_i == 4'h0);
  assign instr_rdata_o = m_rdata_i;
  assign data_rvalid_o = m_rvalid_i & (m_rid_i == 4'h1);
  assign data_rdata_o = m_rdata_i;

  // Grants: ready when master is ready
  // Read: instruction priority over data
  assign instr_gnt_o = instr_req_i & m_arready_i;
  // Data grant: write or read (read only if not instruction)
  assign data_gnt_o = data_req_i & ((data_we_i & m_awready_i & m_wready_i) | (~data_we_i & m_arready_i & ~instr_req_i));

  // Write path (data only)
  assign m_awvalid_o = data_req_i & data_we_i;
  assign m_awaddr_o = data_addr_i;
  assign m_awsize_o = 3'b010;  // 4 bytes
  assign m_awburst_o = 2'b01;  // INCR
  assign m_awlen_o = 8'd0;     // Single beat
  assign m_awid_o = 4'h1;      // Write ID

  assign m_wvalid_o = data_req_i & data_we_i;
  assign m_wdata_o = data_wdata_i;
  assign m_wstrb_o = data_be_i;
  assign m_wlast_o = 1'b1;     // Single beat

  assign m_bready_o = 1'b1;    // Always ready for write response

endmodule
