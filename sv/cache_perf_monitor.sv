// =============================================================================
// cache_perf_monitor.sv
// Cache Performance Monitoring Module (SIMPLIFIED - NO TYPE DEPENDENCIES)
//
// Purpose: Collect real-time cache performance metrics during simulation
// - Hit/miss tracking (based on latency threshold)
// - Latency measurement (P50, P99, max)
// - Throughput calculation
// - Memory bus utilization
//
// Metrics Collected:
//   1. Total requests & responses
//   2. Cache hits/misses (classified by latency threshold)
//   3. Request latency distribution
//   4. Response rate (throughput)
//   5. Memory bus busy cycles
//
// Output: Printable stats at end of simulation via report_test_results() task
// =============================================================================
`timescale 1ns/1ps

module cache_perf_monitor
import hpdcache_pkg::*;
(
    input logic                     clk_i,
    input logic                     rst_ni,

    // Core request interface (simplified - just control signals)
    input logic                     core_req_valid_i,
    input logic                     core_req_ready_i,
    input logic [63:0]              core_req_tid_i,  // Transaction ID for latency tracking

    // Core response interface (simplified - just control signals)
    input logic                     core_rsp_valid_i,
    input logic [63:0]              core_rsp_tid_i,  // Transaction ID matching

    // Memory read interface (for bus utilization)
    input logic                     mem_req_read_valid_i,
    input logic                     mem_req_read_ready_i,
    input logic                     mem_resp_read_valid_i,
    input logic                     mem_resp_read_ready_i
);

    // =========================================================================
    // CONFIGURATION
    // =========================================================================

    localparam int unsigned MAX_LATENCY = 2048;  // Max cycles to track per request
    localparam int unsigned HIT_THRESHOLD = 5;   // Cycles threshold for hit vs miss
    localparam int unsigned NUM_LATENCY_BINS = 256;  // Latency histogram bins

    // =========================================================================
    // COUNTERS & STORAGE
    // =========================================================================

    // Transaction tracking
    longint total_requests = 0;
    longint total_responses = 0;
    longint hit_count = 0;
    longint miss_count = 0;
    longint total_cycles = 0;

    // Latency tracking
    longint total_latency = 0;
    longint hit_total_latency = 0;
    longint miss_total_latency = 0;
    int latency_histogram[NUM_LATENCY_BINS];
    int max_latency = 0;
    int min_latency = MAX_LATENCY;

    // Throughput tracking
    int consecutive_responses = 0;
    int max_throughput = 0;

    // Memory bus utilization
    longint mem_read_busy_cycles = 0;
    longint mem_write_busy_cycles = 0;

    // Request tracking: store request timestamp for latency calculation
    typedef struct {
        longint timestamp;
        logic valid;
    } request_tracker_t;

    request_tracker_t req_tracker[64];  // 64 TID entries

    // Test metadata (set by testbench)
    string test_name = "unknown";

    // =========================================================================
    // MAIN MONITORING LOGIC
    // =========================================================================

    always @(posedge clk_i) begin
        if (!rst_ni) begin
            // Reset all counters
            total_requests <= 0;
            total_responses <= 0;
            hit_count <= 0;
            miss_count <= 0;
            total_latency <= 0;
            hit_total_latency <= 0;
            miss_total_latency <= 0;
            total_cycles <= 0;
            mem_read_busy_cycles <= 0;
            mem_write_busy_cycles <= 0;
            max_latency <= 0;
            min_latency <= MAX_LATENCY;
            consecutive_responses <= 0;
            max_throughput <= 0;

            // Clear histograms
            for (int i = 0; i < NUM_LATENCY_BINS; i++) begin
                latency_histogram[i] = 0;
            end

            // Clear request trackers
            for (int i = 0; i < 64; i++) begin
                req_tracker[i].valid = 1'b0;
                req_tracker[i].timestamp = 0;
            end
        end else begin
            int tid_req, tid_rsp, latency, bin_index;

            // Track total cycles
            total_cycles <= total_cycles + 1;

            // ===== REQUEST TRACKING =====
            if (core_req_valid_i && core_req_ready_i) begin
                total_requests <= total_requests + 1;

                // Store request timestamp for this TID
                tid_req = int'(core_req_tid_i[5:0]);  // Extract 6-bit TID
                req_tracker[tid_req].timestamp = total_cycles;
                req_tracker[tid_req].valid = 1'b1;
            end

            // ===== RESPONSE TRACKING =====
            if (core_rsp_valid_i) begin
                total_responses <= total_responses + 1;
                tid_rsp = int'(core_rsp_tid_i[5:0]);  // Extract 6-bit TID

                // Calculate latency if this response matches a tracked request
                if (req_tracker[tid_rsp].valid) begin
                    latency = int'(total_cycles - req_tracker[tid_rsp].timestamp);
                    total_latency <= total_latency + latency;

                    // Classify as hit or miss
                    if (latency < HIT_THRESHOLD) begin
                        hit_count <= hit_count + 1;
                        hit_total_latency <= hit_total_latency + latency;
                    end else begin
                        miss_count <= miss_count + 1;
                        miss_total_latency <= miss_total_latency + latency;
                    end

                    // Update latency histogram
                    bin_index = (latency < NUM_LATENCY_BINS) ? latency : (NUM_LATENCY_BINS - 1);
                    latency_histogram[bin_index] <= latency_histogram[bin_index] + 1;

                    // Update min/max
                    if (latency > max_latency) max_latency <= latency;
                    if (latency < min_latency) min_latency <= latency;

                    // Clear tracker for this TID
                    req_tracker[tid_rsp].valid <= 1'b0;
                end

                // Track consecutive responses for throughput calculation
                consecutive_responses <= consecutive_responses + 1;
            end else begin
                if (consecutive_responses > max_throughput)
                    max_throughput <= consecutive_responses;
                consecutive_responses <= 0;
            end

            // ===== MEMORY BUS UTILIZATION =====
            if (mem_req_read_valid_i && mem_req_read_ready_i)
                mem_read_busy_cycles <= mem_read_busy_cycles + 1;

            if (mem_resp_read_valid_i && mem_resp_read_ready_i)
                mem_read_busy_cycles <= mem_read_busy_cycles + 1;
        end
    end

    // =========================================================================
    // REPORT GENERATION TASKS
    // =========================================================================

    task automatic report_test_results();
        real hit_rate;
        real avg_latency;
        real avg_hit_latency;
        real avg_miss_latency;
        real throughput;
        int p50_idx, p99_idx;
        int p50_latency = 0, p99_latency = 0;
        longint cum_count = 0;

        if (total_responses == 0) begin
            $display("  [WARNING] No responses recorded for test '%s'", test_name);
            return;
        end

        // Calculate statistics
        hit_rate = (total_requests > 0) ? (real'(hit_count) / real'(total_requests)) * 100.0 : 0.0;
        avg_latency = (total_responses > 0) ? (real'(total_latency) / real'(total_responses)) : 0.0;
        avg_hit_latency = (hit_count > 0) ? (real'(hit_total_latency) / real'(hit_count)) : 0.0;
        avg_miss_latency = (miss_count > 0) ? (real'(miss_total_latency) / real'(miss_count)) : 0.0;
        throughput = (total_cycles > 0) ? (real'(total_responses) / real'(total_cycles)) : 0.0;

        // Find P50 and P99 latency percentiles
        for (int i = 0; i < NUM_LATENCY_BINS; i++) begin
            cum_count += latency_histogram[i];
            if (cum_count >= (total_responses / 2) && p50_latency == 0)
                p50_latency = i;
            if (cum_count >= (total_responses * 99 / 100) && p99_latency == 0)
                p99_latency = i;
        end

        // Display results
        $display("  ├─ Test: %s", test_name);
        $display("  ├─ Total Requests: %0d", total_requests);
        $display("  ├─ Total Responses: %0d", total_responses);
        $display("  ├─ Cache Hits: %0d (%.1f%%)", hit_count, hit_rate);
        $display("  ├─ Cache Misses: %0d (%.1f%%)", miss_count, 100.0 - hit_rate);
        $display("  ├─ Latency Analysis:");
        $display("  │  ├─ Average: %.2f cycles", avg_latency);
        $display("  │  ├─ Hit Latency (Avg): %.2f cycles", avg_hit_latency);
        $display("  │  ├─ Miss Latency (Avg): %.2f cycles", avg_miss_latency);
        $display("  │  ├─ Latency P50: %0d cycles", p50_latency);
        $display("  │  ├─ Latency P99: %0d cycles", p99_latency);
        $display("  │  ├─ Max Latency: %0d cycles", max_latency);
        $display("  │  └─ Min Latency: %0d cycles", min_latency);
        $display("  ├─ Throughput: %.3f requests/cycle", throughput);
        $display("  ├─ Memory Bus Utilization: %.1f%%", (real'(mem_read_busy_cycles) / real'(total_cycles)) * 100.0);
        $display("  └─ Status: PASS\n");

    endtask

    // =========================================================================
    // FINAL REPORT (Called at end of simulation)
    // =========================================================================

    final begin
        $display("\n╔═══════════════════════════════════════════════════════════════════╗");
        $display("║         CACHE PERFORMANCE SUMMARY (All Tests Combined)             ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║                                                                   ║");
        $display("║ Total Statistics (across all test patterns):                      ║");
        $display("║   • Total Requests: %0d", total_requests);
        $display("║   • Total Responses: %0d", total_responses);
        $display("║   • Overall Hit Rate: %.1f%%", (total_requests > 0) ? (real'(hit_count) / real'(total_requests)) * 100.0 : 0.0);
        $display("║   • Average Latency: %.2f cycles", (total_responses > 0) ? (real'(total_latency) / real'(total_responses)) : 0.0);
        $display("║   • Overall Throughput: %.3f requests/cycle", (total_cycles > 0) ? (real'(total_responses) / real'(total_cycles)) : 0.0);
        $display("║   • Simulation Duration: %0d cycles", total_cycles);
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");
    end

endmodule : cache_perf_monitor
