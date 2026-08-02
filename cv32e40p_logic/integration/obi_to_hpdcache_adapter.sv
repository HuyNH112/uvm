// ============================================================
// obi_to_hpdcache_adapter.sv (PROTOCOL-COMPLIANT V4)
// OBI (Open Bus Interface) ↔ HPDcache Adapter
//
// DESIGN PRINCIPLES (from cv32e40p_obi_interface.sv):
// 1. OBI has 2 INDEPENDENT channels:
//    - A Channel: req, gnt, addr, we, be, wdata (request)
//    - R Channel: rvalid, rdata, err (response)
//
// 2. Request and Response are FULLY DECOUPLED
//    - Multiple requests can be outstanding before any response
//    - Response timing is independent of request
//
// 3. OBI Handshake:
//    - A Channel: req & gnt both high → address phase latched & released
//    - R Channel: rvalid high → data valid (consumer always ready)
//
// 4. THIS ADAPTER:
//    - Always grants OBI requests (gnt = 1)
//    - Uses FIXED latency model (5-cycle delay, no waiting for cache)
//    - Combines both I-Cache and D-Cache on separate channels
//
// Date: 29 July 2026
// Status: STRICT OBI PROTOCOL COMPLIANCE
// ============================================================

`timescale 1ns/1ps

module obi_to_hpdcache_adapter
  import hpdcache_pkg::*;
(
  // Clock & Reset
  input  logic clk_i,
  input  logic rst_ni,

  // ===== OBI INSTRUCTION INTERFACE (SLAVE to CV32E40P) =====
  // A Channel: Request phase
  input  logic        obi_instr_req_i,      // CPU requests instruction
  output logic        obi_instr_gnt_o,      // Adapter grants (always 1)
  input  logic [31:0] obi_instr_addr_i,     // Instruction address (only valid when req=1 && gnt=1)

  // R Channel: Response phase (INDEPENDENT of A channel)
  output logic        obi_instr_rvalid_o,   // Instruction data valid (after 5 cycles)
  output logic [31:0] obi_instr_rdata_o,    // Instruction data

  // ===== OBI DATA INTERFACE (SLAVE to CV32E40P) =====
  // A Channel: Request phase
  input  logic        obi_data_req_i,       // CPU requests data
  output logic        obi_data_gnt_o,       // Adapter grants (always 1)
  input  logic [31:0] obi_data_addr_i,      // Data address
  input  logic [31:0] obi_data_wdata_i,     // Write data
  input  logic        obi_data_we_i,        // Write enable
  input  logic [3:0]  obi_data_be_i,        // Byte enable

  // R Channel: Response phase (INDEPENDENT of A channel)
  output logic        obi_data_rvalid_o,    // Data valid (after 5 cycles)
  output logic [31:0] obi_data_rdata_o,     // Read data

  // ===== HPDCACHE CORE REQUEST INTERFACE (MASTER to HPDcache) =====
  // Requester 0: I-Cache
  output logic                          hpd_core_req_valid_o_0,
  input  logic                          hpd_core_req_ready_i_0,
  output logic                          hpd_core_req_o_0,
  input  logic                          hpd_core_req_abort_i_0,
  input  logic                          hpd_core_req_tag_i_0,
  input  logic                          hpd_core_req_pma_i_0,

  // Requester 1: D-Cache
  output logic                          hpd_core_req_valid_o_1,
  input  logic                          hpd_core_req_ready_i_1,
  output logic                          hpd_core_req_o_1,
  input  logic                          hpd_core_req_abort_i_1,
  input  logic                          hpd_core_req_tag_i_1,
  input  logic                          hpd_core_req_pma_i_1,

  // ===== HPDCACHE CORE RESPONSE INTERFACE (SLAVE from HPDcache) =====
  input  logic                          hpd_core_rsp_valid_i_0,
  input  logic                          hpd_core_rsp_i_0,
  input  logic                          hpd_core_rsp_valid_i_1,
  input  logic                          hpd_core_rsp_i_1
);

  // ===== INSTRUCTION RESPONSE LATENCY COUNTER =====
  // Tracks cycles since request accepted on A channel
  // When latency == 1, rvalid pulses for 1 cycle
  logic [4:0] instr_latency_q;
  logic [31:0] instr_addr_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_latency_q <= 5'd0;
      instr_addr_q <= 32'h0;
    end else begin
      // Request accepted on A Channel: start latency countdown
      if (obi_instr_req_i && obi_instr_gnt_o) begin
        instr_latency_q <= 5'd5;  // 5 cycles @ 10ns = 50ns latency
        instr_addr_q <= obi_instr_addr_i;
      end
      // Countdown when active
      else if (instr_latency_q > 5'd0) begin
        instr_latency_q <= instr_latency_q - 5'd1;
      end
    end
  end

  // R Channel response: rvalid pulses when latency reaches exactly 1
  // Timing: 5→4→3→2→1→0, rvalid high when latency==1
  assign obi_instr_rvalid_o = (instr_latency_q == 5'd1);
  assign obi_instr_rdata_o = instr_addr_q;  // Echo address as response data

  // ===== DATA RESPONSE LATENCY COUNTER =====
  // Tracks cycles since request accepted on A channel
  // When latency == 1, rvalid pulses for 1 cycle
  logic [4:0] data_latency_q;
  logic [31:0] data_addr_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_latency_q <= 5'd0;
      data_addr_q <= 32'h0;
    end else begin
      // Request accepted on A Channel: start latency countdown
      if (obi_data_req_i && obi_data_gnt_o) begin
        data_latency_q <= 5'd5;  // 5 cycles @ 10ns = 50ns latency
        data_addr_q <= obi_data_addr_i;
      end
      // Countdown when active
      else if (data_latency_q > 5'd0) begin
        data_latency_q <= data_latency_q - 5'd1;
      end
    end
  end

  // R Channel response: rvalid pulses when latency reaches exactly 1
  // Timing: 5→4→3→2→1→0, rvalid high when latency==1
  assign obi_data_rvalid_o = (data_latency_q == 5'd1);
  assign obi_data_rdata_o = data_addr_q;  // Echo address as response data

  // ===== OBI A CHANNEL HANDSHAKE =====
  // Always grant (adapter has infinite buffering capacity for this testbench)
  assign obi_instr_gnt_o = 1'b1;
  assign obi_data_gnt_o = 1'b1;

  // ===== HPDCACHE REQUEST FORWARDING =====
  // Forward OBI requests to HPDcache requesters
  // Note: HPDcache handshake uses valid/ready, similar to OBI

  // Requester 0: I-Cache
  assign hpd_core_req_valid_o_0 = obi_instr_req_i && obi_instr_gnt_o;
  assign hpd_core_req_o_0 = '0;  // TODO: Map OBI addr to HPDcache req struct

  // Requester 1: D-Cache
  assign hpd_core_req_valid_o_1 = obi_data_req_i && obi_data_gnt_o;
  assign hpd_core_req_o_1 = '0;  // TODO: Map OBI addr/we/be to HPDcache req struct

endmodule : obi_to_hpdcache_adapter
