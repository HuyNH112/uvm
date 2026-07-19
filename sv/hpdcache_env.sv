// =============================================================================
// hpdcache_env.sv
// UVM Environment: sequencer + driver + monitor + scoreboard
// =============================================================================
`ifndef HPDCACHE_ENV_SV
`define HPDCACHE_ENV_SV

class hpdcache_env extends uvm_env;

    `uvm_component_utils(hpdcache_env)

    hpdcache_sequencer  sequencer;
    hpdcache_driver     driver;
    hpdcache_monitor    monitor;
    hpdcache_scoreboard scoreboard;

    isa_agent          isa_agt;        // NEW
    isa_scoreboard     isa_sb;         // NEW

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer  = hpdcache_sequencer::type_id::create("sequencer",  this);
        driver     = hpdcache_driver::type_id::create("driver",        this);
        monitor    = hpdcache_monitor::type_id::create("monitor",      this);
        scoreboard = hpdcache_scoreboard::type_id::create("scoreboard",this);
        
        isa_agt     = isa_agent::type_id::create("isa_agt", this);              // NEW
        isa_sb      = isa_scoreboard::type_id::create("isa_sb", this);          // NEW
    endfunction

    function void connect_phase(uvm_phase phase);
        // Driver ← Sequencer
        driver.seq_item_port.connect(sequencer.seq_item_export);
        // Monitor → Scoreboard
        monitor.ap_req.connect(scoreboard.fifo_req.analysis_export);
        monitor.ap_rsp.connect(scoreboard.fifo_rsp.analysis_export);
        
        // NEW: ISA connections
        isa_agt.commit_mon.ap_commit.connect(isa_sb.fifo_commit.analysis_export);
        isa_agt.csr_mon.ap_exception.connect(isa_sb.fifo_exception.analysis_export);
    endfunction

endclass : hpdcache_env

`endif // HPDCACHE_ENV_SV