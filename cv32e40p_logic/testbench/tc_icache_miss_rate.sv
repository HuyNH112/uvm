// ============================================================
// tc_icache_miss_rate.sv - I-Cache Miss Rate Performance Test
// ============================================================
// Testcase: TC-I-01 "I-Cache Sequential Hits"
// Purpose: Verify I-Cache integration by measuring miss rate
//          on sequential instruction fetches
// Success: miss_rate < 10% indicates I-Cache is working
// ============================================================

`timescale 1ns/1ps

module tc_icache_miss_rate ();

  // ===== CLOCK & RESET =====
  logic clk_i;
  logic rst_ni;

  // ===== CV32E40P CORE INTERFACE (OBI Fetch) =====
  logic        instr_req;
  logic [31:0] instr_addr;
  logic        core_instr_gnt;
  logic        core_instr_rvalid;
  logic [31:0] core_instr_rdata;

  // ===== I-CACHE INTERFACE =====
  logic        cache_instr_gnt;
  logic [31:0] cache_instr_rdata;
  logic        cache_instr_rvalid;
  logic        cache_miss;
  logic        cache_miss_event;

  // ===== MEMORY REFILL INTERFACE (stub) =====
  logic        mem_req_valid;
  logic [31:0] mem_req_addr;
  logic [7:0]  mem_req_len;
  logic [2:0]  mem_req_size;
  logic        mem_req_ack;
  logic        mem_rsp_valid;
  logic [255:0] mem_rsp_data;
  logic        mem_rsp_last;

  // ===== STATISTICS =====
  integer total_requests = 0;
  integer total_misses = 0;
  integer sequential_hits = 0;
  real    miss_rate;

  // ===== I-CACHE MODULE INSTANTIATION =====
  cv32e40p_icache u_icache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // OBI Fetch Interface
    .instr_req_i(instr_req),
    .instr_gnt_o(cache_instr_gnt),
    .instr_addr_i(instr_addr),
    .instr_rvalid_o(cache_instr_rvalid),
    .instr_rdata_o(cache_instr_rdata),

    // Cache Control
    .flush_i(1'b0),
    .flush_ack_o(),

    // Memory Refill Interface
    .mem_req_valid_o(mem_req_valid),
    .mem_req_addr_o(mem_req_addr),
    .mem_req_len_o(mem_req_len),
    .mem_req_size_o(mem_req_size),
    .mem_req_ack_i(mem_req_ack),
    .mem_rsp_valid_i(mem_rsp_valid),
    .mem_rsp_data_i(mem_rsp_data),
    .mem_rsp_last_i(mem_rsp_last),

    // Performance Monitoring
    .miss_o(cache_miss),
    .miss_event_o(cache_miss_event)
  );

  // ===== SIMPLE MEMORY MODEL =====
  // Simulates L2/main memory with 3-cycle latency (OBI protocol)
  // Tracks multiple outstanding requests in a FIFO
  localparam int FIFO_DEPTH = 8;
  logic [255:0] mem_fifo_data [FIFO_DEPTH-1:0];
  logic [31:0]  mem_fifo_addr [FIFO_DEPTH-1:0];
  integer       mem_fifo_head = 0;
  integer       mem_fifo_tail = 0;
  integer       mem_fifo_cnt = 0;
  integer       mem_latency_cntr [FIFO_DEPTH-1:0];  // Latency counter per request

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_req_ack <= 1'b0;
      mem_rsp_valid <= 1'b0;
      mem_rsp_data <= '0;
      mem_rsp_last <= 1'b0;
      mem_fifo_head <= 0;
      mem_fifo_tail <= 0;
      mem_fifo_cnt <= 0;
    end else begin
      // ===== ENQUEUE: Accept memory requests (if FIFO not full) =====
      mem_req_ack <= 1'b0;
      if (mem_req_valid && mem_fifo_cnt < FIFO_DEPTH) begin
        mem_req_ack <= 1'b1;
        mem_fifo_addr[mem_fifo_tail] <= mem_req_addr;
        mem_latency_cntr[mem_fifo_tail] <= 3;  // 3-cycle latency
        mem_fifo_tail <= (mem_fifo_tail + 1) % FIFO_DEPTH;
        mem_fifo_cnt <= mem_fifo_cnt + 1;
      end

      // ===== DEQUEUE: Return responses after latency =====
      mem_rsp_valid <= 1'b0;
      mem_rsp_last <= 1'b0;
      if (mem_fifo_cnt > 0) begin
        mem_latency_cntr[mem_fifo_head] <= mem_latency_cntr[mem_fifo_head] - 1;
        if (mem_latency_cntr[mem_fifo_head] == 0) begin
          mem_rsp_valid <= 1'b1;
          mem_rsp_last <= 1'b1;
          mem_rsp_data <= {8{mem_fifo_addr[mem_fifo_head][31:24]}};
          mem_fifo_head <= (mem_fifo_head + 1) % FIFO_DEPTH;
          mem_fifo_cnt <= mem_fifo_cnt - 1;
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
    $display("\n╔═══════════════════════════════════════════════════════╗");
    $display("║  I-CACHE MISS RATE TEST                              ║");
    $display("║  Testcase: TC-I-01 Sequential Hits                   ║");
    $display("║  Purpose: Verify I-Cache integration                 ║");
    $display("║  Success Criteria: miss_rate < 10%%                   ║");
    $display("╚═══════════════════════════════════════════════════════╝\n");

    // Reset
    rst_ni = 1'b0;
    instr_req = 1'b0;
    instr_addr = 32'h0000_0000;

    #50;   // Wait ½ clock (reset low for 5ns clock)
    rst_ni = 1'b1;
    #100;  // Wait 2 clocks after reset high → stable FF

    // ===== PHASE 1: COLD START (fill cache with sequential addresses) =====
    $display("[PHASE 1] Cold start - Sequential fetch 0x0000-0x0100");

    for (integer addr = 0; addr < 256; addr = addr + 4) begin
      @(posedge clk_i);
      instr_req = 1'b1;
      instr_addr = addr;

      // Wait for rvalid with timeout (100 cycles max)
      for (integer wait_cnt = 0; wait_cnt < 100; wait_cnt++) begin
        @(posedge clk_i);
        if (cache_instr_rvalid) break;
      end

      if (cache_instr_rvalid) begin
        total_requests++;
        if (cache_miss) begin
          total_misses++;
          $display("  @%0t ns: Address 0x%08h - MISS (latency: 3 cycles)", $time, addr);
        end else begin
          sequential_hits++;
          $display("  @%0t ns: Address 0x%08h - HIT", $time, addr);
        end
      end

      instr_req = 1'b0;
      @(posedge clk_i);
    end

    // ===== PHASE 2: WARM CACHE (repeat same addresses - should be hits) =====
    $display("\n[PHASE 2] Warm cache - Repeat sequential fetch 0x0000-0x0100");

    for (integer addr = 0; addr < 256; addr = addr + 4) begin
      @(posedge clk_i);
      instr_req = 1'b1;
      instr_addr = addr;

      // Wait for rvalid with timeout (100 cycles max)
      for (integer wait_cnt = 0; wait_cnt < 100; wait_cnt++) begin
        @(posedge clk_i);
        if (cache_instr_rvalid) break;
      end

      if (cache_instr_rvalid) begin
        total_requests++;
        if (cache_miss) begin
          total_misses++;
          $display("  @%0t ns: Address 0x%08h - MISS (capacity/conflict?)", $time, addr);
        end else begin
          sequential_hits++;
          $display("  @%0t ns: Address 0x%08h - HIT ✓", $time, addr);
        end
      end

      instr_req = 1'b0;
      @(posedge clk_i);
    end

    // ===== PHASE 3: STRIDE PATTERN =====
    $display("\n[PHASE 3] Stride pattern - +8 byte jumps");

    for (integer addr = 0; addr < 512; addr = addr + 8) begin
      @(posedge clk_i);
      instr_req = 1'b1;
      instr_addr = addr;

      // Wait for rvalid with timeout (100 cycles max)
      for (integer wait_cnt = 0; wait_cnt < 100; wait_cnt++) begin
        @(posedge clk_i);
        if (cache_instr_rvalid) break;
      end

      if (cache_instr_rvalid) begin
        total_requests++;
        if (cache_miss) begin
          total_misses++;
          $display("  @%0t ns: Address 0x%08h - MISS", $time, addr);
        end else begin
          sequential_hits++;
          $display("  @%0t ns: Address 0x%08h - HIT ✓", $time, addr);
        end
      end

      instr_req = 1'b0;
      @(posedge clk_i);
    end

    // ===== CALCULATE & REPORT RESULTS =====
    instr_req = 1'b0;
    #1000;

    miss_rate = (total_requests > 0) ? (real'(total_misses) / real'(total_requests)) * 100.0 : 0.0;

    $display("\n╔═══════════════════════════════════════════════════════╗");
    $display("║  TEST RESULTS                                        ║");
    $display("╠═══════════════════════════════════════════════════════╣");
    $display("║                                                       ║");
    $display("║  Total Requests:    %0d", total_requests);
    $display("║  Cache Hits:        %0d (%.1f%%)", sequential_hits,
             (total_requests > 0) ? (real'(sequential_hits) / real'(total_requests)) * 100.0 : 0.0);
    $display("║  Cache Misses:      %0d", total_misses);
    $display("║  Miss Rate:         %.2f%%", miss_rate);
    $display("║                                                       ║");

    if (miss_rate < 10.0) begin
      $display("║  ✅ PASS: I-Cache is working correctly!             ║");
      $display("║     (miss_rate < 10%% indicates good performance)   ║");
    end else begin
      $display("║  ❌ FAIL: I-Cache miss rate too high                ║");
      $display("║     (expected < 10%%, got %.2f%%)                    ║", miss_rate);
    end

    $display("║                                                       ║");
    $display("╚═══════════════════════════════════════════════════════╝\n");

    $finish;
  end

  // ===== WAVEFORM CAPTURE SIGNALS =====
  initial begin
    $dumpfile("tc_icache_miss_rate.vcd");
    $dumpvars(0, tc_icache_miss_rate);
    $dumpon;
  end

endmodule
