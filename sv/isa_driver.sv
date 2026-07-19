class isa_driver extends uvm_driver #(isa_seq_item);
    `uvm_component_utils(isa_driver)
    
    virtual cva6_rvfi_if.monitor_mp vif;  // Read-only (monitor side only)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found")
    endfunction
    
    task run_phase(uvm_phase phase);
        // Note: reset is handled by hw_top.sv initial block
        // This driver mainly waits for sequence commands (not used in run_phase-only mode)
        forever begin
            isa_seq_item item;
            seq_item_port.get_next_item(item);
            `uvm_info("DRV", $sformatf("Item: %s", item.convert2string()), UVM_MEDIUM)
            seq_item_port.item_done();
        end
    endtask
    
endclass : isa_driver