`ifndef HPDCACHE_ENV_SV
`define HPDCACHE_ENV_SV

// ============================================================================
// hpdcache_env.sv
// UVM environment for HPDcache testbench (cv32a6_imac_sv32, 1 requester)
// Scope: hpdcache_agent (sequencer + driver + monitor) + scoreboard + coverage
// axi_agent (memory side) = passive SV stub — wired in hw_top/tb_top
// ============================================================================

class hpdcache_env extends uvm_env;
    `uvm_component_utils(hpdcache_env)

    // =========================================================================
    // Sub-components
    // =========================================================================

    // --- HPDcache core-side agent ---
    hpdcache_sequencer  m_sequencer;
    hpdcache_driver     m_driver;
    hpdcache_monitor    m_monitor;

    // --- Scoreboard ---
    hpdcache_scoreboard m_scoreboard;

    // --- Coverage collector ---
    hpdcache_coverage   m_coverage;

    // =========================================================================
    // Constructor
    // =========================================================================
    function new(string name = "hpdcache_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build phase: instantiate all components
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_sequencer  = hpdcache_sequencer::type_id::create("m_sequencer", this);
        m_driver     = hpdcache_driver::type_id::create("m_driver",     this);
        m_monitor    = hpdcache_monitor::type_id::create("m_monitor",   this);
        m_scoreboard = hpdcache_scoreboard::type_id::create("m_scoreboard", this);
        m_coverage   = hpdcache_coverage::type_id::create("m_coverage", this);

        // Monitor active: xoá inflight TID qua sequencer
        m_monitor.set_is_active();
        m_monitor.m_sequencer = m_sequencer;

        `uvm_info(get_full_name(), "Build phase complete.", UVM_LOW)
    endfunction

    // =========================================================================
    // Connect phase: wire analysis ports
    // =========================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Driver ↔ Sequencer
        m_driver.seq_item_port.connect(m_sequencer.seq_item_export);

        // Monitor → Scoreboard
        m_monitor.ap_hpdcache_req.connect(m_scoreboard.af_hpdcache_req.analysis_export);
        m_monitor.ap_hpdcache_rsp.connect(m_scoreboard.af_hpdcache_rsp.analysis_export);

        // Monitor → Coverage
        m_monitor.ap_hpdcache_req.connect(m_coverage.analysis_export_req);
        m_monitor.ap_hpdcache_rsp.connect(m_coverage.analysis_export_rsp);

        `uvm_info(get_full_name(), "Connect phase complete.", UVM_LOW)
    endfunction

    // =========================================================================
    // API: set virtual interface — called from tb_top before run_test()
    // =========================================================================
    function void set_hpdcache_vif(virtual hpdcache_if vif);
        m_driver.set_hpdcache_vif(vif);
        m_monitor.set_hpdcache_vif(vif);
    endfunction

endclass : hpdcache_env

`endif // HPDCACHE_ENV_SV