// ============================================================
// tc_hpdcache_basic.sv - HPDcache Stub Response Test
// ============================================================
// Purpose: Verify behavioral cache stub responds correctly
//          (Full HPDcache integration deferred)
//
// **IMPORTANT:**
//   This testcase uses STUB cache model (no real HPDcache RTL)
//   Real integration requires OBI ↔ HPDcache adapter:
//
//   CV32E40P (OBI):          Adapter:           HPDcache:
//   instr_req_o ──┐         ┌────────────┐      core_req_valid_i[0]
//   instr_gnt_i ──┼──────→ │   OBI ↔    │ ──→  core_req_ready_o[0]
//   instr_addr_o ─┤  Bridge │ HPDcache  │      core_rsp_valid_o[0]
//   instr_rdata_i ┤         │  Adapter   │ ←──  core_rsp_o[0]
//   data_req_o ──┤         │            │
//   data_gnt_i ───┴────────┴────────────┘
//
// Test Scenarios:
//   PHASE 1: I-Cache stub request → verify rsp_valid
//   PHASE 2: D-Cache stub request → verify rsp_valid
//   PHASE 3: Concurrent I/D requests → verify parallel response
//
// Success Criteria:
//   ✓ icache_rsp_valid = 1 → Stub cache responds
//   ✓ dcache_rsp_valid = 1 → Stub cache responds
//   ✓ Both respond with data → Stub model working
//
// Status: STUB TEST ONLY (Full HPDcache = Phase 2)
// Date: 29 July 2026
// ============================================================

`timescale 1ns/1ps

module tc_hpdcache_basic ();

  // ===== CLOCK & RESET =====
  logic clk_i;
  logic rst_ni;

  // ===== I-CACHE INTERFACE (Request/Response) =====
  logic        icache_req_valid;
  logic [31:0] icache_req_addr;
  logic        icache_rsp_valid;
  logic [31:0] icache_rsp_data;

  // ===== D-CACHE INTERFACE (Request/Response) =====
  logic        dcache_req_valid;
  logic [31:0] dcache_req_addr;
  logic        dcache_rsp_valid;
  logic [31:0] dcache_rsp_data;

  // ===== TEST COUNTERS =====
  integer icache_requests = 0;
  integer icache_responses = 0;
  integer dcache_requests = 0;
  integer dcache_responses = 0;
  integer test_result = 0;  // 0=PASS, 1=FAIL

  // ===== SIMPLE HPDCACHE STUB =====
  // Minimal behavioral model: returns data 50ns after request
  logic [31:0] icache_req_addr_q;
  logic [31:0] dcache_req_addr_q;
  logic icache_pending = 0;
  logic dcache_pending = 0;
  integer icache_latency_cnt = 0;
  integer dcache_latency_cnt = 0;

  // I-Cache response (50ns latency = 5 clock cycles @ 10ns)
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      icache_rsp_valid <= 1'b0;
      icache_rsp_data <= '0;
      icache_req_addr_q <= '0;
      icache_pending <= 1'b0;
      icache_latency_cnt <= 0;
    end else begin
      icache_rsp_valid <= 1'b0;

      // Accept new request
      if (icache_req_valid && !icache_pending) begin
        icache_req_addr_q <= icache_req_addr;
        icache_pending <= 1'b1;
        icache_latency_cnt <= 5;  // 5 cycles @ 10ns = 50ns latency
      end

      // Count down latency
      if (icache_pending && icache_latency_cnt > 0) begin
        icache_latency_cnt <= icache_latency_cnt - 1;
        if (icache_latency_cnt == 1) begin
          icache_rsp_valid <= 1'b1;
          icache_rsp_data <= {8{icache_req_addr_q[31:24]}};  // Dummy: echo addr[31:24]
          icache_pending <= 1'b0;
        end
      end
    end
  end

  // D-Cache response (50ns latency = 5 clock cycles @ 10ns)
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dcache_rsp_valid <= 1'b0;
      dcache_rsp_data <= '0;
      dcache_req_addr_q <= '0;
      dcache_pending <= 1'b0;
      dcache_latency_cnt <= 0;
    end else begin
      dcache_rsp_valid <= 1'b0;

      // Accept new request
      if (dcache_req_valid && !dcache_pending) begin
        dcache_req_addr_q <= dcache_req_addr;
        dcache_pending <= 1'b1;
        dcache_latency_cnt <= 5;  // 5 cycles @ 10ns = 50ns latency
      end

      // Count down latency
      if (dcache_pending && dcache_latency_cnt > 0) begin
        dcache_latency_cnt <= dcache_latency_cnt - 1;
        if (dcache_latency_cnt == 1) begin
          dcache_rsp_valid <= 1'b1;
          dcache_rsp_data <= {8{dcache_req_addr_q[31:16]}};  // Dummy: echo addr[31:16]
          dcache_pending <= 1'b0;
        end
      end
    end
  end

  // ===== CLOCK GENERATION =====
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 10ns period (100 MHz)
  end

  // ===== TEST STIMULUS =====
  initial begin
    // Declarations (must be at beginning of procedural block)
    integer wait_cnt_p1, wait_cnt_p2, wait_cnt_p3;
    integer icache_done_p3, dcache_done_p3;

    $display("\n╔════════════════════════════════════════════════════════════════╗");
    $display("║  HPDCACHE STUB RESPONSE TEST (NOT FULL HPDCACHE)              ║");
    $display("║  Testcase: TC-D-01 Stub Cache Response Verification           ║");
    $display("║  Purpose: Verify behavioral stub responds (Phase 1)            ║");
    $display("║  Note: Real HPDcache requires OBI adapter (Phase 2)            ║");
    $display("║  Success: Both stub caches return valid data                  ║");
    $display("╚════════════════════════════════════════════════════════════════╝\n");

    // ===== RESET =====
    rst_ni = 1'b0;
    icache_req_valid = 1'b0;
    dcache_req_valid = 1'b0;
    icache_req_addr = 32'h0000_0000;
    dcache_req_addr = 32'h0000_0000;

    #50;  // Wait ½ clock cycle
    rst_ni = 1'b1;
    #100;  // Wait 2 clocks after reset

    // ===== PHASE 1: I-CACHE REQUEST =====
    $display("[PHASE 1] I-Cache Request → Verify Response");
    $display("  Sending instruction fetch request @ time %0t ns", $time);

    @(posedge clk_i);
    icache_req_valid = 1'b1;
    icache_req_addr = 32'h0000_0100;
    icache_requests++;

    $display("  @%0t ns: icache_req_valid=1, addr=0x%08h", $time, icache_req_addr);

    // Wait for I-Cache response with timeout (200 cycles max)
    for (wait_cnt_p1 = 0; wait_cnt_p1 < 200; wait_cnt_p1++) begin
      @(posedge clk_i);
      if (icache_rsp_valid) begin
        icache_responses++;
        $display("  @%0t ns: ✓ icache_rsp_valid=1, data=0x%08h (ICACHE WORKING)", $time, icache_rsp_data);
        break;
      end
    end

    if (icache_rsp_valid == 0) begin
      $display("  @%0t ns: ✗ icache_rsp_valid=0 after timeout (ICACHE FAILED)", $time);
      test_result = 1;
    end

    icache_req_valid = 1'b0;
    @(posedge clk_i);

    // ===== PHASE 2: D-CACHE REQUEST =====
    $display("\n[PHASE 2] D-Cache Request → Verify Response");
    $display("  Sending data read request @ time %0t ns", $time);

    @(posedge clk_i);
    dcache_req_valid = 1'b1;
    dcache_req_addr = 32'h1000_0000;
    dcache_requests++;

    $display("  @%0t ns: dcache_req_valid=1, addr=0x%08h", $time, dcache_req_addr);

    // Wait for D-Cache response with timeout (200 cycles max)
    for (wait_cnt_p2 = 0; wait_cnt_p2 < 200; wait_cnt_p2++) begin
      @(posedge clk_i);
      if (dcache_rsp_valid) begin
        dcache_responses++;
        $display("  @%0t ns: ✓ dcache_rsp_valid=1, data=0x%08h (DCACHE WORKING)", $time, dcache_rsp_data);
        break;
      end
    end

    if (dcache_rsp_valid == 0) begin
      $display("  @%0t ns: ✗ dcache_rsp_valid=0 after timeout (DCACHE FAILED)", $time);
      test_result = 1;
    end

    dcache_req_valid = 1'b0;
    @(posedge clk_i);

    // ===== PHASE 3: CONCURRENT I/D REQUESTS =====
    $display("\n[PHASE 3] Concurrent I-Cache & D-Cache Requests");
    $display("  Testing parallel cache access @ time %0t ns", $time);

    icache_done_p3 = 0;
    dcache_done_p3 = 0;

    @(posedge clk_i);
    icache_req_valid = 1'b1;
    dcache_req_valid = 1'b1;
    icache_req_addr = 32'h0000_0200;
    dcache_req_addr = 32'h2000_0000;

    $display("  @%0t ns: Both icache_req_valid=1 & dcache_req_valid=1", $time);

    // Wait for both responses with timeout
    for (wait_cnt_p3 = 0; wait_cnt_p3 < 200; wait_cnt_p3++) begin
      @(posedge clk_i);
      if (icache_rsp_valid && !icache_done_p3) begin
        icache_done_p3 = 1;
        $display("  @%0t ns: ✓ icache_rsp_valid=1, data=0x%08h", $time, icache_rsp_data);
      end
      if (dcache_rsp_valid && !dcache_done_p3) begin
        dcache_done_p3 = 1;
        $display("  @%0t ns: ✓ dcache_rsp_valid=1, data=0x%08h", $time, dcache_rsp_data);
      end
      if (icache_done_p3 && dcache_done_p3) break;
    end

    if (!icache_done_p3 || !dcache_done_p3) begin
      $display("  @%0t ns: ✗ Timeout waiting for concurrent responses", $time);
      test_result = 1;
    end

    icache_req_valid = 1'b0;
    dcache_req_valid = 1'b0;
    @(posedge clk_i);

    // ===== FINAL REPORT =====
    #1000;

    $display("\n╔════════════════════════════════════════════════════════════════╗");
    $display("║  TEST RESULTS                                                  ║");
    $display("╠════════════════════════════════════════════════════════════════╣");
    $display("║                                                                ║");
    $display("║  I-Cache Requests:     %0d", icache_requests);
    $display("║  I-Cache Responses:    %0d", icache_responses);
    $display("║                                                                ║");
    $display("║  D-Cache Requests:     %0d", dcache_requests);
    $display("║  D-Cache Responses:    %0d", dcache_responses);
    $display("║                                                                ║");

    if ((icache_responses > 0) && (dcache_responses > 0) && (test_result == 0)) begin
      $display("║  ✅ PASS: STUB CACHE WORKING (Phase 1 complete)               ║");
      $display("║     (Both I-Cache & D-Cache stub respond with data)          ║");
      $display("║                                                                ║");
      $display("║  Next Phase: Create OBI ↔ HPDcache adapter                    ║");
      $display("║     - Map CV32E40P OBI ports to HPDcache generic interface   ║");
      $display("║     - Compile full HPDcache RTL (11K LOC)                    ║");
      $display("║     - Run integration test                                   ║");
    end else begin
      $display("║  ❌ FAIL: STUB CACHE NOT RESPONDING                           ║");
      if (icache_responses == 0) $display("║     I-Cache stub did not respond               ║");
      if (dcache_responses == 0) $display("║     D-Cache stub did not respond               ║");
    end

    $display("║                                                                ║");
    $display("╚════════════════════════════════════════════════════════════════╝\n");

    $finish;
  end

  // ===== WAVEFORM CAPTURE =====
  initial begin
    $dumpfile("tc_hpdcache_basic.vcd");
    $dumpvars(0, tc_hpdcache_basic);
    $dumpon;
  end

endmodule
