// =============================================================================
// perf_report.sv
// Standalone CSV Report Generator (NO MODULE DEPENDENCIES)
//
// Purpose: Generate CSV report with cache performance metrics
// - Export performance data to CSV file
// - Simple stateless design (no module instantiation)
// - Can be called from testbench directly
//
// Output File: D:\UVM_CV32E40P\results\perf_report.csv
// =============================================================================
`timescale 1ns/1ps

module perf_report
import hpdcache_pkg::*;
(
    input logic clk_i,
    input logic rst_ni
);

    // =========================================================================
    // CSV REPORT GENERATION
    // =========================================================================

    task automatic generate_csv_report(
        input string test_name,
        input longint total_requests,
        input longint total_responses,
        input longint hit_count,
        input longint miss_count,
        input real hit_rate,
        input real avg_latency,
        input real hit_latency,
        input real miss_latency,
        input int p50_latency,
        input int p99_latency,
        input int max_latency,
        input int min_latency,
        input real throughput,
        input real mem_util,
        input longint total_cycles
    );

        integer fp_csv;
        string csv_file = "D:/UVM_CV32E40P/results/perf_report.csv";
        string header_line;
        string data_line;

        // Create results directory (best effort)
        $system("mkdir -p D:/UVM_CV32E40P/results");

        // Open CSV file for writing
        fp_csv = $fopen(csv_file, "w");
        if (fp_csv == 0) begin
            $display("[ERROR] Could not open CSV file: %s", csv_file);
            $display("[FALLBACK] Writing to stdout instead:");
        end

        // Write header row (first time only)
        header_line = "Test Name,Total Requests,Total Responses,Hit Count,Miss Count,Hit Rate (%),Avg Latency (cy),Hit Latency (cy),Miss Latency (cy),P50 Latency (cy),P99 Latency (cy),Max Latency (cy),Min Latency (cy),Throughput (req/cy),Memory Util (%),Test Duration (cy)";

        if (fp_csv != 0) begin
            $fwrite(fp_csv, "%s\n", header_line);
        end
        $display(header_line);

        // Format data row
        data_line = $sformatf(
            "%s,%0d,%0d,%0d,%0d,%.2f,%.2f,%.2f,%.2f,%0d,%0d,%0d,%0d,%.3f,%.1f,%0d",
            test_name,
            total_requests,
            total_responses,
            hit_count,
            miss_count,
            hit_rate,
            avg_latency,
            hit_latency,
            miss_latency,
            p50_latency,
            p99_latency,
            max_latency,
            min_latency,
            throughput,
            mem_util,
            total_cycles
        );

        if (fp_csv != 0) begin
            $fwrite(fp_csv, "%s\n", data_line);
            $fclose(fp_csv);
            $display("[SUCCESS] CSV report written to: %s", csv_file);
        end else begin
            $display("[FALLBACK] %s", data_line);
        end

    endtask : generate_csv_report

endmodule : perf_report
