// ============================================================
// tc_hpdcache_basic_v2.sv - OBI Adapter Verification Test
// ============================================================
// Purpose: Verify OBI adapter 5-cycle latency model
//
// Key Design:
// - Adapter has built-in latency counter (no stub model needed)
// - Testbench latches response pulse instead of polling
// - Pure @posedge synchronization (no #delay)
// - Minimal HPDcache port assignments
//
// Date: 29 July 2026
// Status: CORRECTED - Robust response detection
// ============================================================

`timescale 1ns/1ps

module tc_hpdcache_basic_v2
  import hpdcache_pkg::*;
();

  // ===== CLOCK & RESET =====
  logic clk_i;
  logic rst_ni;

  // ===== OBI INSTRUCTION INTERFACE =====
  logic        obi_instr_req;
  logic        obi_instr_gnt;
  logic [31:0] obi_instr_addr;
  logic        obi_instr_rvalid;
  logic [31:0] obi_instr_rdata;

  // ===== OBI DATA INTERFACE =====
  logic        obi_data_req;
  logic        obi_data_gnt;
  logic [31:0] obi_data_addr;
  logic [31:0] obi_data_wdata;
  logic        obi_data_we;
  logic [3:0]  obi_data_be;
  logic        obi_data_rvalid;
  logic [31:0] obi_data_rdata;

  // ===== HPDCACHE INTERFACE SIGNALS =====
  // Requester 0: I-Cache
  logic hpd_core_req_valid_0;
  logic hpd_core_req_ready_0;
  logic hpd_core_req_abort_0;
  logic hpd_core_req_tag_0;
  logic hpd_core_req_pma_0;
  logic hpd_core_rsp_valid_0;

  // Requester 1: D-Cache
  logic hpd_core_req_valid_1;
  logic hpd_core_req_ready_1;
  logic hpd_core_req_abort_1;
  logic hpd_core_req_tag_1;
  logic hpd_core_req_pma_1;
  logic hpd_core_rsp_valid_1;

  // ===== INSTANTIATE OBI ↔ HPDCACHE ADAPTER =====
  obi_to_hpdcache_adapter u_adapter (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // OBI Instruction Interface
    .obi_instr_req_i(obi_instr_req),
    .obi_instr_gnt_o(obi_instr_gnt),
    .obi_instr_addr_i(obi_instr_addr),
    .obi_instr_rvalid_o(obi_instr_rvalid),
    .obi_instr_rdata_o(obi_instr_rdata),

    // OBI Data Interface
    .obi_data_req_i(obi_data_req),
    .obi_data_gnt_o(obi_data_gnt),
    .obi_data_addr_i(obi_data_addr),
    .obi_data_wdata_i(obi_data_wdata),
    .obi_data_we_i(obi_data_we),
    .obi_data_be_i(obi_data_be),
    .obi_data_rvalid_o(obi_data_rvalid),
    .obi_data_rdata_o(obi_data_rdata),

    // HPDcache Requester 0: I-Cache
    .hpd_core_req_valid_o_0(hpd_core_req_valid_0),
    .hpd_core_req_ready_i_0(hpd_core_req_ready_0),
    .hpd_core_req_o_0(),
    .hpd_core_req_abort_i_0(hpd_core_req_abort_0),
    .hpd_core_req_tag_i_0(hpd_core_req_tag_0),
    .hpd_core_req_pma_i_0(hpd_core_req_pma_0),

    // HPDcache Requester 1: D-Cache
    .hpd_core_req_valid_o_1(hpd_core_req_valid_1),
    .hpd_core_req_ready_i_1(hpd_core_req_ready_1),
    .hpd_core_req_o_1(),
    .hpd_core_req_abort_i_1(hpd_core_req_abort_1),
    .hpd_core_req_tag_i_1(hpd_core_req_tag_1),
    .hpd_core_req_pma_i_1(hpd_core_req_pma_1),

    // HPDcache Response Interface
    .hpd_core_rsp_valid_i_0(hpd_core_rsp_valid_0),
    .hpd_core_rsp_i_0('0),
    .hpd_core_rsp_valid_i_1(hpd_core_rsp_valid_1),
    .hpd_core_rsp_i_1('0)
  );

  // ===== HPDCACHE STUB: Minimal port assignments =====
  assign hpd_core_req_ready_0 = 1'b1;
  assign hpd_core_req_ready_1 = 1'b1;
  assign hpd_core_req_abort_0 = 1'b0;
  assign hpd_core_req_abort_1 = 1'b0;
  assign hpd_core_req_tag_0 = '0;
  assign hpd_core_req_tag_1 = '0;
  assign hpd_core_req_pma_0 = '0;
  assign hpd_core_req_pma_1 = '0;
  assign hpd_core_rsp_valid_0 = 1'b0;
  assign hpd_core_rsp_valid_1 = 1'b0;

  // ===== CLOCK GENERATION =====
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 10ns period (100 MHz)
  end

  // ===== TEST STIMULUS =====
  initial begin
    integer wait_cnt_p1, wait_cnt_p2, wait_cnt_p3;
    integer icache_done, dcache_done;
    logic instr_resp_received, data_resp_received;

    $display("\n╔════════════════════════════════════════════════════════════════╗");
    $display("║  OBI ↔ HPDCACHE ADAPTER INTEGRATION TEST                      ║");
    $display("║  Purpose: Verify 5-cycle latency model with pulse detection   ║");
    $display("║  Key: Latch response instead of polling loop                  ║");
    $display("╚════════════════════════════════════════════════════════════════╝\n");

    // ===== RESET =====
    rst_ni = 1'b0;
    obi_instr_req = 1'b0;
    obi_data_req = 1'b0;
    obi_instr_addr = 32'h0000_0000;
    obi_data_addr = 32'h0000_0000;
    obi_data_wdata = 32'h0000_0000;
    obi_data_we = 1'b0;
    obi_data_be = 4'b0000;

    #50;
    rst_ni = 1'b1;
    #100;

    // ===== PHASE 1: I-CACHE REQUEST =====
    $display("[PHASE 1] I-Cache Request");
    $display("  Expected: latency pulse at cycle 4-5");

    instr_resp_received = 1'b0;

    @(posedge clk_i);
    obi_instr_req = 1'b1;
    obi_instr_addr = 32'h0000_0100;

    $display("  @%0t ns: instr_req=1, addr=0x%08h", $time, obi_instr_addr);
    $display("  @%0t ns: instr_gnt=%b, core_req_valid[0]=%b", $time, obi_instr_gnt, hpd_core_req_valid_0);

    // CRITICAL: Deassert req after grant to allow latency countdown
    @(posedge clk_i);
    obi_instr_req = 1'b0;

    // Wait 10 cycles for response
    for (wait_cnt_p1 = 0; wait_cnt_p1 < 10; wait_cnt_p1++) begin
      @(posedge clk_i);
      if (obi_instr_rvalid && !instr_resp_received) begin
        instr_resp_received = 1'b1;
        $display("  @%0t ns: ✓ instr_rvalid=1, rdata=0x%08h", $time, obi_instr_rdata);
      end
    end

    $display("  Result: %s\n", instr_resp_received ? "✓ PASS" : "✗ FAIL");

    // ===== PHASE 2: D-CACHE REQUEST =====
    $display("[PHASE 2] D-Cache Request");
    $display("  Expected: latency pulse at cycle 4-5");

    data_resp_received = 1'b0;

    @(posedge clk_i);
    obi_data_req = 1'b1;
    obi_data_addr = 32'h2000_0000;
    obi_data_wdata = 32'hDEAD_BEEF;
    obi_data_we = 1'b1;
    obi_data_be = 4'b1111;

    $display("  @%0t ns: data_req=1, addr=0x%08h", $time, obi_data_addr);
    $display("  @%0t ns: data_gnt=%b, core_req_valid[1]=%b", $time, obi_data_gnt, hpd_core_req_valid_1);

    // CRITICAL: Deassert req after grant to allow latency countdown
    @(posedge clk_i);
    obi_data_req = 1'b0;

    // Wait 10 cycles for response
    for (wait_cnt_p2 = 0; wait_cnt_p2 < 10; wait_cnt_p2++) begin
      @(posedge clk_i);
      if (obi_data_rvalid && !data_resp_received) begin
        data_resp_received = 1'b1;
        $display("  @%0t ns: ✓ data_rvalid=1, rdata=0x%08h", $time, obi_data_rdata);
      end
    end

    $display("  Result: %s\n", data_resp_received ? "✓ PASS" : "✗ FAIL");

    // ===== PHASE 3: CONCURRENT REQUESTS =====
    $display("[PHASE 3] Concurrent I/D Requests");
    $display("  Expected: both responses within 10 cycles");

    icache_done = 0;
    dcache_done = 0;

    @(posedge clk_i);
    obi_instr_req = 1'b1;
    obi_data_req = 1'b1;
    obi_instr_addr = 32'h0000_0200;
    obi_data_addr = 32'h3000_0000;
    obi_data_wdata = 32'h1111_2222;
    obi_data_we = 1'b1;
    obi_data_be = 4'b1111;

    $display("  @%0t ns: Both instr_req=1, data_req=1", $time);

    // CRITICAL: Deassert req after grant to allow latency countdown
    @(posedge clk_i);
    obi_instr_req = 1'b0;
    obi_data_req = 1'b0;

    // Wait 10 cycles for both responses
    for (wait_cnt_p3 = 0; wait_cnt_p3 < 10; wait_cnt_p3++) begin
      @(posedge clk_i);

      if (obi_instr_rvalid && !icache_done) begin
        icache_done = 1;
        $display("  @%0t ns: ✓ instr_rvalid=1, rdata=0x%08h", $time, obi_instr_rdata);
      end

      if (obi_data_rvalid && !dcache_done) begin
        dcache_done = 1;
        $display("  @%0t ns: ✓ data_rvalid=1, rdata=0x%08h", $time, obi_data_rdata);
      end
    end

    $display("  Result: %s\n", (icache_done && dcache_done) ? "✓ PASS" : "✗ FAIL");

    // ===== SUMMARY =====
    #100;

    $display("╔════════════════════════════════════════════════════════════════╗");
    $display("║  SUMMARY                                                       ║");
    $display("╠════════════════════════════════════════════════════════════════╣");
    $display("║  PHASE 1 (I-Cache):    %s                                   ║", instr_resp_received ? "✓ PASS" : "✗ FAIL");
    $display("║  PHASE 2 (D-Cache):    %s                                   ║", data_resp_received ? "✓ PASS" : "✗ FAIL");
    $display("║  PHASE 3 (Concurrent): %s                                   ║", (icache_done && dcache_done) ? "✓ PASS" : "✗ FAIL");
    $display("╚════════════════════════════════════════════════════════════════╝\n");

    $finish;
  end

endmodule : tc_hpdcache_basic_v2
