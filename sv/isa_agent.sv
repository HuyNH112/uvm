class isa_agent extends uvm_agent;
    `uvm_component_utils(isa_agent)
    
    isa_sequencer       sequencer;
    isa_driver          driver;
    isa_commit_monitor  commit_mon;
    isa_csr_monitor     csr_mon;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer   = isa_sequencer::type_id::create("sequencer", this);
        driver      = isa_driver::type_id::create("driver", this);
        commit_mon  = isa_commit_monitor::type_id::create("commit_mon", this);
        csr_mon     = isa_csr_monitor::type_id::create("csr_mon", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
    
endclass : isa_agent