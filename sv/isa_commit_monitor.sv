// =============================================================================
// isa_commit_monitor.sv
// ISA Commit Monitor: Observe CVA6 RVFI (TC 1.1–1.3)
// =============================================================================
`ifndef ISA_COMMIT_MONITOR_SV
`define ISA_COMMIT_MONITOR_SV

class isa_commit_monitor extends uvm_monitor;
    `uvm_component_utils(isa_commit_monitor)
    
    virtual cva6_rvfi_if.monitor_mp vif;
    
    typedef struct {
        logic [63:0] pc;
        logic [31:0] instr;
        logic [4:0]  rd_addr;
        logic [63:0] rd_wdata;
    } isa_commit_event;
    
    uvm_analysis_port #(isa_commit_event) ap_commit;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found")
        ap_commit = new("ap_commit", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk_i);
            if (vif.commit_valid) begin
                isa_commit_event evt;
                evt.pc       = vif.commit_pc;
                evt.instr    = vif.commit_instr;
                evt.rd_addr  = vif.commit_rd_addr;
                evt.rd_wdata = vif.commit_rd_wdata;
                ap_commit.write(evt);
                `uvm_info("COMMIT", $sformatf("PC=%016h INSTR=%08h", evt.pc, evt.instr), UVM_HIGH)
            end
        end
    endtask
    
endclass : isa_commit_monitor

`endif // ISA_COMMIT_MONITOR_SV