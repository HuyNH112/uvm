class isa_sequencer extends uvm_sequencer #(isa_seq_item);
    `uvm_component_utils(isa_sequencer)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
endclass : isa_sequencer