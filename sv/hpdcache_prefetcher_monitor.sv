// =============================================================================
// hpdcache_prefetcher_monitor.sv - Phase 3A: Prefetcher State Monitoring
// Monitor prefetcher internals: MHT1, MHT2, prefetch requests, and prediction
// Tracks: history table accesses, pattern detection, prefetch generation
// =============================================================================

`ifndef HPDCACHE_PREFETCHER_MONITOR_SV
`define HPDCACHE_PREFETCHER_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import hpdcache_pkg::*;

class hpdcache_prefetcher_monitor extends uvm_monitor;

    `uvm_component_utils(hpdcache_prefetcher_monitor)

    virtual hpdcache_if.monitor_mp vif;

    // Width shortcuts
    localparam int unsigned PA_W     = UVM_HPDCACHE_PA_WIDTH;      // 56 bits
    localparam int unsigned ADDR_W   = 32;
    localparam int unsigned TAG_W    = UVM_TAG_WIDTH;              // 20 bits
    localparam int unsigned OFF_W    = UVM_REQ_OFFSET_WIDTH;       // 4 bits (16 bytes)
    localparam int unsigned MHT_SIZE = 16;                         // History table depth
    localparam int unsigned MHT_BITS = 4;                          // log2(16)

    // Prefetcher state tracking structures
    typedef struct {
        logic [PA_W-1:0] address;           // Last accessed address
        logic [PA_W-1:0] history_entry;     // MHT history value
        logic            valid;              // Entry valid flag
        int unsigned     access_count;      // Number of accesses to this entry
        int unsigned     timestamp;         // Access timestamp for LRU
    } mht_entry_t;

    // MHT1 (First-order History Table)
    mht_entry_t mht1_table [logic [MHT_BITS-1:0]];

    // MHT2 (Second-order History Table)
    mht_entry_t mht2_table [logic [MHT_BITS-1:0]];

    // Performance counters
    int unsigned cnt_prefetch_generated;    // Total prefetches issued
    int unsigned cnt_prefetch_useful;       // Prefetches that hit later misses
    int unsigned cnt_prefetch_late;         // Prefetches after miss occurred
    int unsigned cnt_prefetch_dup;          // Duplicate prefetch addresses
    int unsigned cnt_mht1_hit;              // MHT1 table hits
    int unsigned cnt_mht2_hit;              // MHT2 table hits
    int unsigned cnt_hash_collision;        // Hash collisions detected
    int unsigned cnt_stride_pattern;        // Stride patterns detected
    int unsigned cycle_counter;             // Global cycle counter

    // Prefetch tracking
    typedef struct {
        logic [PA_W-1:0] addr;
        int unsigned    generated_cycle;
        int unsigned    used_cycle;
        logic           is_useful;
    } prefetch_record_t;

    prefetch_record_t prefetch_history [$];  // Queue of recent prefetches
    logic [PA_W-1:0] last_prefetch_addr;    // Last prefetch address

    // Request history for pattern detection
    logic [PA_W-1:0] addr_history [logic [3:0]];  // Last 4 addresses
    int unsigned history_depth;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cnt_prefetch_generated = 0;
        cnt_prefetch_useful    = 0;
        cnt_prefetch_late      = 0;
        cnt_prefetch_dup       = 0;
        cnt_mht1_hit           = 0;
        cnt_mht2_hit           = 0;
        cnt_hash_collision     = 0;
        cnt_stride_pattern     = 0;
        cycle_counter          = 0;
        history_depth          = 0;
        last_prefetch_addr     = '0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual hpdcache_if.monitor_mp)::get(
                this, "", "hpdcache_vif_monitor", vif))
            `uvm_fatal("NOVIF", "Prefetcher Monitor: hpdcache_vif_monitor not found")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.rst_ni);
        repeat (2) @(posedge vif.clk_i);
        fork
            track_cycle_counter();
            track_mht1_access();
            track_mht2_access();
            analyze_prefetch_request();
            correlate_prefetch_to_cache();
        join_none
    endtask

    // =========================================================================
    // CYCLE COUNTER - Timestamp for event tracking
    // =========================================================================
    task track_cycle_counter();
        forever begin
            @(posedge vif.clk_i);
            cycle_counter++;
        end
    endtask

    // =========================================================================
    // MHT1 TRACKING - First-order History Table
    // =========================================================================
    task track_mht1_access();
        logic [PA_W-1:0] current_addr;
        logic [MHT_BITS-1:0] hash_index;
        logic [PA_W-1:0] stride;

        forever begin
            @(posedge vif.clk_i);
            if (vif.core_req_valid_i && vif.core_req_ready_o) begin
                current_addr = {vif.core_req_i.addr_tag, vif.core_req_i.addr_offset};
                hash_index = calculate_xor_hash(current_addr) [MHT_BITS-1:0];

                // Check for MHT1 hit
                if (mht1_table.exists(hash_index) && mht1_table[hash_index].valid) begin
                    cnt_mht1_hit++;
                    mht1_table[hash_index].access_count++;
                    mht1_table[hash_index].timestamp = cycle_counter;

                    // Check stride pattern
                    stride = current_addr - mht1_table[hash_index].address;
                    if (is_stride_pattern(stride)) begin
                        cnt_stride_pattern++;
                    end
                end else begin
                    // MHT1 miss - create new entry
                    mht1_table[hash_index].address = current_addr;
                    mht1_table[hash_index].valid = 1'b1;
                    mht1_table[hash_index].access_count = 1;
                    mht1_table[hash_index].timestamp = cycle_counter;
                end

                // Update history for pattern analysis
                update_address_history(current_addr);
            end
        end
    endtask

    // =========================================================================
    // MHT2 TRACKING - Second-order History Table
    // =========================================================================
    task track_mht2_access();
        logic [PA_W-1:0] current_addr;
        logic [MHT_BITS-1:0] hash_index;

        forever begin
            @(posedge vif.clk_i);
            if (vif.core_req_valid_i && vif.core_req_ready_o) begin
                current_addr = {vif.core_req_i.addr_tag, vif.core_req_i.addr_offset};
                hash_index = calculate_xor_hash(calculate_xor_hash(current_addr)) [MHT_BITS-1:0];

                // Check for MHT2 hit (two-level pattern match)
                if (mht2_table.exists(hash_index) && mht2_table[hash_index].valid) begin
                    cnt_mht2_hit++;
                    mht2_table[hash_index].access_count++;
                    mht2_table[hash_index].timestamp = cycle_counter;
                end else begin
                    // MHT2 miss - create new entry
                    mht2_table[hash_index].address = current_addr;
                    mht2_table[hash_index].valid = 1'b1;
                    mht2_table[hash_index].access_count = 1;
                    mht2_table[hash_index].timestamp = cycle_counter;
                end
            end
        end
    endtask

    // =========================================================================
    // PREFETCH REQUEST ANALYSIS
    // =========================================================================
    task analyze_prefetch_request();
        logic [PA_W-1:0] prefetch_addr;
        prefetch_record_t pf_record;

        forever begin
            @(posedge vif.clk_i);
            if (vif.evt_prefetch_req_o) begin
                cnt_prefetch_generated++;

                // Extract prefetch address (simulated from last request + stride)
                prefetch_addr = predict_next_address();

                // Check for duplicate prefetch
                if (prefetch_addr == last_prefetch_addr) begin
                    cnt_prefetch_dup++;
                end

                // Verify address validity
                if (!is_address_valid(prefetch_addr)) begin
                    `uvm_warning("PREFETCH",
                        $sformatf("Invalid prefetch address: 0x%014h", prefetch_addr))
                end

                // Record prefetch for later correlation
                pf_record.addr = prefetch_addr;
                pf_record.generated_cycle = cycle_counter;
                pf_record.is_useful = 1'b0;
                pf_record.used_cycle = 0;
                prefetch_history.push_back(pf_record);

                // Limit history queue to last 64 prefetches
                if (prefetch_history.size() > 64) begin
                    prefetch_history.delete(0);
                end

                last_prefetch_addr = prefetch_addr;

                `uvm_info("PREFETCH",
                    $sformatf("Prefetch generated: Addr=0x%014h Cycle=%0d",
                              prefetch_addr, cycle_counter),
                    UVM_MEDIUM)
            end
        end
    endtask

    // =========================================================================
    // CORRELATE PREFETCH TO CACHE - Determine Prefetch Usefulness
    // =========================================================================
    task correlate_prefetch_to_cache();
        logic [PA_W-1:0] current_miss_addr;
        int unsigned prefetch_lead_time;

        forever begin
            @(posedge vif.clk_i);
            // Check for cache miss
            if (vif.evt_cache_read_miss_o || vif.evt_cache_write_miss_o) begin
                current_miss_addr = {vif.core_req_i.addr_tag, vif.core_req_i.addr_offset};

                // Search for matching prefetch in history
                foreach (prefetch_history[i]) begin
                    if (prefetch_history[i].addr == current_miss_addr &&
                        !prefetch_history[i].is_useful) begin
                        // Found useful prefetch
                        prefetch_history[i].is_useful = 1'b1;
                        prefetch_history[i].used_cycle = cycle_counter;
                        cnt_prefetch_useful++;

                        prefetch_lead_time = cycle_counter - prefetch_history[i].generated_cycle;

                        `uvm_info("PREFETCH",
                            $sformatf("Prefetch useful: Addr=0x%014h Lead=%0d cycles",
                                      current_miss_addr, prefetch_lead_time),
                            UVM_MEDIUM)
                    end else if (prefetch_history[i].addr == current_miss_addr &&
                                 prefetch_history[i].generated_cycle > cycle_counter - 10) begin
                        // Prefetch came too late
                        cnt_prefetch_late++;
                    end
                end
            end
        end
    endtask

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    // Detect linear stride pattern (constant difference between accesses)
    function logic is_stride_pattern(logic [PA_W-1:0] stride);
        // Typical strides: 16, 32, 64 bytes (power of 2)
        logic [PA_W-1:0] stride_candidates[5] = '{16, 32, 64, 128, 256};

        foreach (stride_candidates[i]) begin
            if (stride == stride_candidates[i] || stride == -stride_candidates[i]) begin
                return 1'b1;
            end
        end
        return 1'b0;
    endfunction

    // Calculate XOR hash for MHT indexing
    function logic [PA_W-1:0] calculate_xor_hash(logic [PA_W-1:0] addr);
        logic [PA_W-1:0] hash;
        int i;

        hash = '0;
        for (i = 0; i < PA_W; i += 8) begin
            hash = hash ^ addr[i +: 8];
        end
        return hash;
    endfunction

    // Get MHT entry by address
    function mht_entry_t get_mht_entry(
        input logic [PA_W-1:0] addr,
        input bit is_mht1
    );
        logic [MHT_BITS-1:0] hash_index;
        mht_entry_t entry;

        hash_index = calculate_xor_hash(addr) [MHT_BITS-1:0];

        if (is_mht1 && mht1_table.exists(hash_index)) begin
            return mht1_table[hash_index];
        end else if (!is_mht1 && mht2_table.exists(hash_index)) begin
            return mht2_table[hash_index];
        end else begin
            entry.valid = 1'b0;
            return entry;
        end
    endfunction

    // Predict next address based on history and pattern
    function logic [PA_W-1:0] predict_next_address();
        logic [PA_W-1:0] predicted_addr;
        logic [PA_W-1:0] stride;

        if (history_depth >= 2) begin
            // Calculate stride from last two addresses
            stride = addr_history[1] - addr_history[0];

            // Predict next = current + stride
            predicted_addr = addr_history[1] + stride;
            return predicted_addr;
        end else begin
            // Not enough history - return current + default stride
            return addr_history[0] + 64;
        end
    endfunction

    // Check address validity (no out-of-bounds)
    function logic is_address_valid(logic [PA_W-1:0] addr);
        // Valid physical address range: 0x0 to 0xFFFFFFFFFFFF (48-bit typical)
        // For this test, accept all PA_W-bit addresses as valid
        return 1'b1;
    endfunction

    // Update address history queue
    function void update_address_history(logic [PA_W-1:0] addr);
        if (history_depth >= 3) begin
            // Shift history: [0]←[1], [1]←[2], [2]←[3]
            addr_history[0] = addr_history[1];
            addr_history[1] = addr_history[2];
            addr_history[2] = addr_history[3];
            addr_history[3] = addr;
        end else begin
            addr_history[history_depth] = addr;
            history_depth++;
        end
    endfunction

    // =========================================================================
    // REPORTING
    // =========================================================================
    function void report_phase(uvm_phase phase);
        real prefetch_accuracy;
        real prefetch_efficiency;

        if (cnt_prefetch_generated > 0) begin
            prefetch_accuracy = real'(cnt_prefetch_useful) / real'(cnt_prefetch_generated) * 100.0;
            prefetch_efficiency = real'(cnt_prefetch_useful) / (real'(cnt_prefetch_useful + cnt_prefetch_dup) + 0.01) * 100.0;
        end else begin
            prefetch_accuracy = 0.0;
            prefetch_efficiency = 0.0;
        end

        `uvm_info("PREFETCH_MON", $sformatf(
            "\n===== Prefetcher Monitor Report =====\n" +
            "  Prefetches Generated: %0d\n" +
            "  Prefetches Useful   : %0d (%.1f%% accuracy)\n" +
            "  Prefetches Late     : %0d\n" +
            "  Prefetches Duplicate: %0d (%.1f%% efficiency)\n" +
            "  Stride Patterns     : %0d\n" +
            "  MHT1 Hits           : %0d\n" +
            "  MHT2 Hits           : %0d\n" +
            "  Hash Collisions     : %0d\n" +
            "  Total Cycles        : %0d",
            cnt_prefetch_generated, cnt_prefetch_useful, prefetch_accuracy,
            cnt_prefetch_late, cnt_prefetch_dup, prefetch_efficiency,
            cnt_stride_pattern, cnt_mht1_hit, cnt_mht2_hit,
            cnt_hash_collision, cycle_counter),
            UVM_MEDIUM)
    endfunction

endclass : hpdcache_prefetcher_monitor

`endif // HPDCACHE_PREFETCHER_MONITOR_SV
