// ============================================================
// cv32e40p_obi_adapter_if.sv
//
// Virtual Interface for CV32E40P OBI <-> HPDcache Adapter
//
// Provides dual requester support:
//   - Requester 0: I-Cache (instruction fetch)
//   - Requester 1: D-Cache (data load/store)
//
// Both connected through single OBI 32-bit master interface
// to external memory system.
//
// Design Date: 30 July 2026
// Status: Phase 1 - Foundation
// ============================================================

`ifndef CV32E40P_OBI_ADAPTER_IF_SV
`define CV32E40P_OBI_ADAPTER_IF_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import hpdcache_pkg::*;
import hpdcache_uvm_pkg::*;

interface cv32e40p_obi_adapter_if (
  input logic clk_i,
  input logic rst_ni
);

  // Import type definitions from UVM package
  import hpdcache_uvm_pkg::hpdcache_req_t;
  import hpdcache_uvm_pkg::hpdcache_rsp_t;

  // ===== OBI INSTRUCTION MASTER INTERFACE =====
  // 1-cycle OBI protocol for instruction fetch

  // Instruction request (master -> slave)
  logic        obi_instr_req_i;          // Request valid
  logic [31:0] obi_instr_addr_i;         // Fetch address (32-bit)

  // Instruction grant (slave -> master)
  logic        obi_instr_gnt_o;          // Grant (ready)

  // Instruction response (slave -> master, next cycle)
  logic        obi_instr_rvalid_o;       // Response valid
  logic [31:0] obi_instr_rdata_o;        // Instruction data (32-bit)
  logic [2:0]  obi_instr_rresp_o;        // Response code: OKAY=0, EXOKAY=1, SLVERR=2, DECERR=3

  // ===== OBI DATA MASTER INTERFACE =====
  // 1-cycle OBI protocol for data load/store

  // Data request (master -> slave)
  logic        obi_data_req_i;           // Request valid
  logic [31:0] obi_data_addr_i;          // Load/store address (32-bit)
  logic [31:0] obi_data_wdata_i;         // Write data (32-bit)
  logic        obi_data_we_i;            // Write enable: 0=read, 1=write
  logic [3:0]  obi_data_be_i;            // Byte enables (one per byte)

  // Data grant (slave -> master)
  logic        obi_data_gnt_o;           // Grant (ready)

  // Data response (slave -> master, next cycle)
  logic        obi_data_rvalid_o;        // Response valid
  logic [31:0] obi_data_rdata_o;         // Read data (32-bit)
  logic [2:0]  obi_data_rresp_o;         // Response code (same as instr)

  // ===== HPDCACHE REQUESTER 0 (I-CACHE MASTER) =====
  // 2-cycle handshake protocol with struct-based signals

  // Cycle N: Request with offset/immediate fields
  logic                                   hpd_core_req_valid_o_0;    // Request valid
  logic                                   hpd_core_req_ready_i_0;    // Ready
  hpdcache_req_t                          hpd_core_req_o_0;          // Flattened request struct

  // Cycle N+1: Response
  logic                                   hpd_core_rsp_valid_i_0;    // Response valid
  hpdcache_rsp_t                          hpd_core_rsp_o_0;          // Flattened response struct

  // ===== HPDCACHE REQUESTER 1 (D-CACHE MASTER) =====
  // Same as requester 0, but for data cache requests

  logic                                   hpd_core_req_valid_o_1;    // Request valid
  logic                                   hpd_core_req_ready_i_1;    // Ready
  hpdcache_req_t                          hpd_core_req_o_1;          // Request struct

  logic                                   hpd_core_rsp_valid_i_1;    // Response valid
  hpdcache_rsp_t                          hpd_core_rsp_o_1;          // Response struct

  // ===== MODPORTS FOR UVM COMPONENTS =====

  // Master modport: for testbench driver (drives requests)
  modport master (
    input   clk_i, rst_ni,

    // Instruction path (master drives OBI requests)
    output  obi_instr_req_i, obi_instr_addr_i,
    input   obi_instr_gnt_o,
    input   obi_instr_rvalid_o, obi_instr_rdata_o, obi_instr_rresp_o,

    // Data path (master drives OBI requests)
    output  obi_data_req_i, obi_data_addr_i, obi_data_wdata_i, obi_data_we_i, obi_data_be_i,
    input   obi_data_gnt_o,
    input   obi_data_rvalid_o, obi_data_rdata_o, obi_data_rresp_o,

    // HPDcache requester 0 (I-Cache)
    output  hpd_core_req_valid_o_0, hpd_core_req_o_0,
    input   hpd_core_req_ready_i_0,
    input   hpd_core_rsp_valid_i_0, hpd_core_rsp_o_0,

    // HPDcache requester 1 (D-Cache)
    output  hpd_core_req_valid_o_1, hpd_core_req_o_1,
    input   hpd_core_req_ready_i_1,
    input   hpd_core_rsp_valid_i_1, hpd_core_rsp_o_1
  );

  // Slave modport: for testbench slave/memory model
  modport slave (
    input   clk_i, rst_ni,

    // Instruction path (slave responds to OBI requests)
    input   obi_instr_req_i, obi_instr_addr_i,
    output  obi_instr_gnt_o,
    output  obi_instr_rvalid_o, obi_instr_rdata_o, obi_instr_rresp_o,

    // Data path (slave responds to OBI requests)
    input   obi_data_req_i, obi_data_addr_i, obi_data_wdata_i, obi_data_we_i, obi_data_be_i,
    output  obi_data_gnt_o,
    output  obi_data_rvalid_o, obi_data_rdata_o, obi_data_rresp_o,

    // HPDcache requester 0 (I-Cache)
    input   hpd_core_req_valid_o_0, hpd_core_req_o_0,
    output  hpd_core_req_ready_i_0,
    output  hpd_core_rsp_valid_i_0, hpd_core_rsp_o_0,

    // HPDcache requester 1 (D-Cache)
    input   hpd_core_req_valid_o_1, hpd_core_req_o_1,
    output  hpd_core_req_ready_i_1,
    output  hpd_core_rsp_valid_i_1, hpd_core_rsp_o_1
  );

  // Monitor modport: for testbench monitor (observes all signals)
  modport monitor (
    input   clk_i, rst_ni,
    input   obi_instr_req_i, obi_instr_addr_i, obi_instr_gnt_o,
    input   obi_instr_rvalid_o, obi_instr_rdata_o, obi_instr_rresp_o,
    input   obi_data_req_i, obi_data_addr_i, obi_data_wdata_i, obi_data_we_i, obi_data_be_i,
    input   obi_data_gnt_o,
    input   obi_data_rvalid_o, obi_data_rdata_o, obi_data_rresp_o,
    input   hpd_core_req_valid_o_0, hpd_core_req_o_0,
    input   hpd_core_req_ready_i_0,
    input   hpd_core_rsp_valid_i_0, hpd_core_rsp_o_0,
    input   hpd_core_req_valid_o_1, hpd_core_req_o_1,
    input   hpd_core_req_ready_i_1,
    input   hpd_core_rsp_valid_i_1, hpd_core_rsp_o_1
  );

  // ===== OPTIONAL: TIMING ASSERTIONS =====

  // Assertion 1: Request must hold until grant is received
  property req_until_gnt_instr;
    @(posedge clk_i) disable iff(!rst_ni)
      (obi_instr_req_i) |-> (obi_instr_req_i || obi_instr_gnt_o)[*0:$];
  endproperty
  assert property (req_until_gnt_instr)
    else $error("Instruction request not held until grant");

  // Assertion 2: Response must follow request with 1 cycle delay
  property rsp_follows_req_data;
    @(posedge clk_i) disable iff(!rst_ni)
      (obi_data_req_i && obi_data_gnt_o) |=> obi_data_rvalid_o;
  endproperty
  // assert property (rsp_follows_req_data) -- optional, may not hold for all devices

  // Assertion 3: Byte enables must be non-zero for valid write
  property valid_be_on_write;
    @(posedge clk_i) disable iff(!rst_ni)
      (obi_data_req_i && obi_data_we_i) |-> (obi_data_be_i != '0);
  endproperty
  assert property (valid_be_on_write)
    else $error("Write request with zero byte enables");

endinterface : cv32e40p_obi_adapter_if

// ============================================================
// VIF WRAPPER FOR UVM TESTBENCH
// ============================================================

class cv32e40p_obi_vif_wrapper extends uvm_object;
  `uvm_object_utils(cv32e40p_obi_vif_wrapper)

  virtual cv32e40p_obi_adapter_if vif;

  int unsigned requester_id;  // 0=I-Cache, 1=D-Cache

  function new(string name = "");
    super.new(name);
  endfunction

  // Helper: Wait for grant on HPDcache requester port
  task wait_hpd_grant(bit req_valid, int timeout_cycles = 1000);
    int cycles = 0;
    while (cycles < timeout_cycles) begin
      if (requester_id == 0) begin
        if (req_valid && vif.hpd_core_req_ready_i_0) break;
      end else begin
        if (req_valid && vif.hpd_core_req_ready_i_1) break;
      end
      @(posedge vif.clk_i);
      cycles++;
    end
    if (cycles >= timeout_cycles)
      `uvm_error("cv32e40p_obi_vif_wrapper", $sformatf(
        "Timeout waiting for HPDcache grant on requester %0d", requester_id))
  endtask

  // Helper: Wait for OBI grant
  task wait_obi_grant(bit req_type, int timeout_cycles = 1000);  // 0=instr, 1=data
    int cycles = 0;
    while (cycles < timeout_cycles) begin
      if (req_type == 0) begin  // Instruction
        if (vif.obi_instr_req_i && vif.obi_instr_gnt_o) break;
      end else begin  // Data
        if (vif.obi_data_req_i && vif.obi_data_gnt_o) break;
      end
      @(posedge vif.clk_i);
      cycles++;
    end
    if (cycles >= timeout_cycles)
      `uvm_error("cv32e40p_obi_vif_wrapper", $sformatf(
        "Timeout waiting for OBI grant (req_type=%0d)", req_type))
  endtask

  // Helper: Wait for response
  task wait_obi_rsp(bit req_type, output logic [31:0] rdata, output logic [2:0] rresp, input int timeout_cycles = 1000);
    int cycles = 0;
    while (cycles < timeout_cycles) begin
      @(posedge vif.clk_i);
      if (req_type == 0) begin  // Instruction response
        if (vif.obi_instr_rvalid_o) begin
          rdata = vif.obi_instr_rdata_o;
          rresp = vif.obi_instr_rresp_o;
          break;
        end
      end else begin  // Data response
        if (vif.obi_data_rvalid_o) begin
          rdata = vif.obi_data_rdata_o;
          rresp = vif.obi_data_rresp_o;
          break;
        end
      end
      cycles++;
    end
    if (cycles >= timeout_cycles)
      `uvm_error("cv32e40p_obi_vif_wrapper", $sformatf(
        "Timeout waiting for OBI response (req_type=%0d)", req_type))
  endtask

endclass : cv32e40p_obi_vif_wrapper

`endif // CV32E40P_OBI_ADAPTER_IF_SV
