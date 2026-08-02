// ============================================================
// tc_obi_axi4_adapter.sv - OBI-to-AXI4 Adapter Verification
// ============================================================
// Quick testcase to verify adapter compiles and basic protocol

`timescale 1ns/1ps

module tc_obi_axi4_adapter ();

  logic clk_i, rst_ni;

  // OBI Slave (from CV32E40P)
  logic instr_req_i, instr_gnt_o, instr_rvalid_o;
  logic [31:0] instr_addr_i, instr_rdata_o;

  logic data_req_i, data_gnt_o, data_rvalid_o;
  logic [31:0] data_addr_i, data_wdata_i, data_rdata_o;
  logic data_we_i;
  logic [3:0] data_be_i;

  // AXI4 Master (to HPDcache)
  logic m_arvalid_o, m_arready_i, m_rvalid_i, m_rlast_i;
  logic [31:0] m_araddr_o, m_rdata_i;
  logic [7:0] m_arlen_o;
  logic [2:0] m_arsize_o;
  logic [1:0] m_arburst_o, m_rresp_i;
  logic [3:0] m_arid_o, m_rid_i;
  logic m_arlock_o, m_rready_o;
  logic [3:0] m_arcache_o;
  logic [2:0] m_arprot_o;

  logic m_awvalid_o, m_awready_i, m_wvalid_o, m_wready_i;
  logic [31:0] m_awaddr_o, m_wdata_o;
  logic [7:0] m_awlen_o;
  logic [2:0] m_awsize_o;
  logic [1:0] m_awburst_o;
  logic [3:0] m_awid_o, m_awcache_o;
  logic [2:0] m_awprot_o;
  logic [5:0] m_awatop_o;
  logic [7:0] m_wstrb_o;
  logic m_wlast_o;

  logic m_bvalid_i, m_bready_o;
  logic [1:0] m_bresp_i;
  logic [3:0] m_bid_i;

  // Instantiate adapter
  obi_to_axi4_adapter #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(64),
    .AXI_ID_WIDTH(4)
  ) u_adapter (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .instr_req_i(instr_req_i), .instr_gnt_o(instr_gnt_o),
    .instr_addr_i(instr_addr_i), .instr_rvalid_o(instr_rvalid_o),
    .instr_rdata_o(instr_rdata_o),
    .data_req_i(data_req_i), .data_gnt_o(data_gnt_o),
    .data_addr_i(data_addr_i), .data_we_i(data_we_i),
    .data_be_i(data_be_i), .data_wdata_i(data_wdata_i),
    .data_rvalid_o(data_rvalid_o), .data_rdata_o(data_rdata_o),
    .m_arvalid_o(m_arvalid_o), .m_arready_i(m_arready_i),
    .m_araddr_o(m_araddr_o), .m_arsize_o(m_arsize_o),
    .m_arburst_o(m_arburst_o), .m_arlen_o(m_arlen_o),
    .m_arid_o(m_arid_o), .m_arlock_o(m_arlock_o),
    .m_arcache_o(m_arcache_o), .m_arprot_o(m_arprot_o),
    .m_rvalid_i(m_rvalid_i), .m_rready_o(m_rready_o),
    .m_rdata_i(m_rdata_i), .m_rresp_i(m_rresp_i),
    .m_rlast_i(m_rlast_i), .m_rid_i(m_rid_i),
    .m_awvalid_o(m_awvalid_o), .m_awready_i(m_awready_i),
    .m_awaddr_o(m_awaddr_o), .m_awsize_o(m_awsize_o),
    .m_awburst_o(m_awburst_o), .m_awlen_o(m_awlen_o),
    .m_awid_o(m_awid_o), .m_awlock_o(m_awlock_o),
    .m_awcache_o(m_awcache_o), .m_awprot_o(m_awprot_o),
    .m_awatop_o(m_awatop_o),
    .m_wvalid_o(m_wvalid_o), .m_wready_i(m_wready_i),
    .m_wdata_o(m_wdata_o), .m_wstrb_o(m_wstrb_o),
    .m_wlast_o(m_wlast_o),
    .m_bvalid_i(m_bvalid_i), .m_bready_o(m_bready_o),
    .m_bresp_i(m_bresp_i), .m_bid_i(m_bid_i)
  );

  // Clock
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  // Test
  initial begin
    $display("\n=== OBI-to-AXI4 Adapter Verification ===\n");

    // Reset
    rst_ni = 1'b0;
    instr_req_i = 1'b0;
    data_req_i = 1'b0;
    m_arready_i = 1'b1;
    m_wready_i = 1'b1;
    m_awready_i = 1'b1;
    m_rvalid_i = 1'b0;
    m_bvalid_i = 1'b0;

    #50 rst_ni = 1'b1;
    #20;

    // Test 1: Instruction read
    @(posedge clk_i);
    instr_req_i = 1'b1;
    instr_addr_i = 32'h1000;
    $display("[TEST 1] Instruction read request");
    $display("  instr_req=1, addr=0x%08h", instr_addr_i);

    @(posedge clk_i);
    instr_req_i = 1'b0;
    if (instr_gnt_o) $display("  ✓ instr_gnt=1");
    if (m_arvalid_o) $display("  ✓ m_arvalid=1, addr=0x%08h, arid=%0d", m_araddr_o, m_arid_o);

    @(posedge clk_i);
    m_rvalid_i = 1'b1;
    m_rdata_i = 64'hDEADBEEFCAFEBABE;
    m_rid_i = 4'h0;
    m_rlast_i = 1'b1;

    @(posedge clk_i);
    if (instr_rvalid_o) $display("  ✓ instr_rvalid=1, rdata=0x%08h", instr_rdata_o);
    m_rvalid_i = 1'b0;

    #20;

    // Test 2: Data write
    @(posedge clk_i);
    data_req_i = 1'b1;
    data_we_i = 1'b1;
    data_addr_i = 32'h2000;
    data_wdata_i = 32'hAABBCCDD;
    data_be_i = 4'b1111;
    $display("\n[TEST 2] Data write request");
    $display("  data_req=1, addr=0x%08h, wdata=0x%08h", data_addr_i, data_wdata_i);

    @(posedge clk_i);
    data_req_i = 1'b0;
    if (data_gnt_o) $display("  ✓ data_gnt=1");
    if (m_awvalid_o) $display("  ✓ m_awvalid=1, addr=0x%08h, awid=%0d", m_awaddr_o, m_awid_o);
    if (m_wvalid_o) $display("  ✓ m_wvalid=1, wdata=0x%016h, wstrb=%02b", m_wdata_o, m_wstrb_o);

    @(posedge clk_i);
    m_bvalid_i = 1'b1;
    m_bid_i = 4'h1;

    @(posedge clk_i);
    m_bvalid_i = 1'b0;

    #20;

    $display("\n=== All tests completed ===\n");
    $finish;
  end

endmodule : tc_obi_axi4_adapter
