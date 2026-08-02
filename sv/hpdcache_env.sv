// =============================================================================
// hpdcache_env.sv - Phase 3: Complete UVM Environment with Monitoring
// UVM Environment: sequencer + driver + monitor + scoreboard + Phase 3A/B monitors
// Added: Prefetcher monitoring (A8), Performance measurement (A9)
// =============================================================================

class hpdcache_env extends uvm_env;

    `uvm_component_utils(hpdcache_env)

    // Phase 1: Single HPDcache agent
    hpdcache_sequencer  sequencer;
    hpdcache_driver     driver;
    hpdcache_monitor    monitor;
    hpdcache_scoreboard scoreboard;

    // Phase 2: Dual agent support
    // Agent 0: ICache (Instruction Cache) — Requester 0 (fetch requests)
    hpdcache_sequencer  icache_sequencer;
    hpdcache_driver     icache_driver;

    // Agent 1: DCache (Data Cache) — Requester 1 (load/store requests)
    hpdcache_sequencer  dcache_sequencer;
    hpdcache_driver     dcache_driver;

    // Phase 3A: Prefetcher monitoring component
    hpdcache_prefetcher_monitor prefetcher_monitor;

    // Phase 3B: Performance measurement component
    hpdcache_performance_measurement perf_measurement;

    // Shared monitor & scoreboard (observe both agents on single OBI interface)
    // monitor and scoreboard created in build_phase

    // Configuration for dual agent mode
    bit enable_dual_agents = 1'b0;  // Set via config_db if needed

    // Configuration for Phase 3 monitoring
    bit enable_prefetcher_monitoring = 1'b1;  // Enable prefetcher monitor
    bit enable_performance_measurement = 1'b1;  // Enable performance monitor

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Check if dual agent mode is enabled via config_db
        if (!uvm_config_db #(bit)::get(this, "", "enable_dual_agents", enable_dual_agents))
            enable_dual_agents = 1'b0;

        // Check Phase 3 monitoring flags
        if (!uvm_config_db #(bit)::get(this, "", "enable_prefetcher_monitoring", enable_prefetcher_monitoring))
            enable_prefetcher_monitoring = 1'b1;

        if (!uvm_config_db #(bit)::get(this, "", "enable_performance_measurement", enable_performance_measurement))
            enable_performance_measurement = 1'b1;

        if (!enable_dual_agents) begin
            // Phase 1: Single agent (traditional)
            sequencer  = hpdcache_sequencer::type_id::create("sequencer",  this);
            driver     = hpdcache_driver::type_id::create("driver",        this);
            monitor    = hpdcache_monitor::type_id::create("monitor",      this);
            scoreboard = hpdcache_scoreboard::type_id::create("scoreboard",this);
        end else begin
            // Phase 2: Dual agents
            // ICache Agent
            icache_sequencer = hpdcache_sequencer::type_id::create("icache_sequencer", this);
            icache_driver    = hpdcache_driver::type_id::create("icache_driver",      this);

            // DCache Agent
            dcache_sequencer = hpdcache_sequencer::type_id::create("dcache_sequencer", this);
            dcache_driver    = hpdcache_driver::type_id::create("dcache_driver",      this);

            // Shared monitor & scoreboard
            monitor    = hpdcache_monitor::type_id::create("monitor",      this);
            scoreboard = hpdcache_scoreboard::type_id::create("scoreboard",this);

            `uvm_info("ENV", "Dual Agent Mode ENABLED (ICache + DCache)", UVM_MEDIUM)
        end

        // Phase 3A: Instantiate Prefetcher Monitor
        if (enable_prefetcher_monitoring) begin
            prefetcher_monitor = hpdcache_prefetcher_monitor::type_id::create("prefetcher_monitor", this);
            `uvm_info("ENV", "Prefetcher Monitor instantiated (A8)", UVM_MEDIUM)
        end

        // Phase 3B: Instantiate Performance Measurement Monitor
        if (enable_performance_measurement) begin
            perf_measurement = hpdcache_performance_measurement::type_id::create("perf_measurement", this);
            `uvm_info("ENV", "Performance Measurement instantiated (A9)", UVM_MEDIUM)
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (!enable_dual_agents) begin
            // Phase 1: Traditional single-agent connections
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.ap_req.connect(scoreboard.fifo_req.analysis_export);
            monitor.ap_rsp.connect(scoreboard.fifo_rsp.analysis_export);
        end else begin
            // Phase 2: Dual-agent connections with request multiplexing
            // Both agents connect to shared monitor (same OBI interface)
            // Request routing via agent ID (sid field in seq_item)
            //   icache_driver.sid = 0 (Req 0)
            //   dcache_driver.sid = 1 (Req 1)

            // ICache Agent connections
            icache_driver.seq_item_port.connect(icache_sequencer.seq_item_export);

            // DCache Agent connections
            dcache_driver.seq_item_port.connect(dcache_sequencer.seq_item_export);

            // Shared monitor observes both agents
            // Monitor will correlate responses by sid field
            monitor.ap_req.connect(scoreboard.fifo_req.analysis_export);
            monitor.ap_rsp.connect(scoreboard.fifo_rsp.analysis_export);

            `uvm_info("ENV", "Dual Agent Connections: ICache (Req0) + DCache (Req1) → Monitor → Scoreboard",
                      UVM_MEDIUM)
        end

        // Phase 3A: Prefetcher Monitor connections
        // Prefetcher monitor observes OBI interface independently
        if (enable_prefetcher_monitoring && prefetcher_monitor != null) begin
            `uvm_info("ENV", "Prefetcher Monitor connected to OBI interface", UVM_MEDIUM)
        end

        // Phase 3B: Performance Measurement Monitor connections
        // Performance measurement observes OBI interface independently
        if (enable_performance_measurement && perf_measurement != null) begin
            `uvm_info("ENV", "Performance Measurement connected to OBI interface", UVM_MEDIUM)
        end
    endfunction

    // Note: Request routing handled via UVM sequences in base_test.sv
    // Sequencers configured with:
    //   - icache_sequencer: for I-Cache requests (SID=0)
    //   - dcache_sequencer: for D-Cache requests (SID=1)
    //   - sequencer: unified sequencer for Phase 1 (HPDcache-only)

endclass : hpdcache_env