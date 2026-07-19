class isa_seq_item extends uvm_sequence_item;
    `uvm_object_utils(isa_seq_item)
    
    // Minimal item for UVM 1.1d (no randomize)
    logic [63:0] reset_cycles;  // Number of cycles before releasing reset
    logic        halt;          // Signal to halt test
    
    function new(string name="isa_seq_item");
        super.new(name);
        reset_cycles = 0;
        halt = 0;
    endfunction
    
    function string convert2string();
        return $sformatf("reset_cycles=%0d halt=%0b", reset_cycles, halt);
    endfunction
endclass : isa_seq_item