// =============================================================================
// isa_csr_monitor.sv
// ISA CSR Monitor: Observe exceptions and CSR writes (TC 1.3)
// =============================================================================
`ifndef ISA_CSR_MONITOR_SV
`define ISA_CSR_MONITOR_SV

class isa_csr_monitor extends uvm_monitor;
    `uvm_component_utils(isa_csr_monitor)
    
    virtual cva6_rvfi_if.monitor_mp vif;
    
    typedef struct {
        logic [3:0]  mcause;
        logic [63:0] mepc;
    } isa_exception_event;
    
    typedef struct {
        logic [11:0] csr_addr;
        logic [63:0] csr_wdata;
    } isa_csr_event;
    
    uvm_analysis_port #(isa_exception_event) ap_exception;
    uvm_analysis_port #(isa_csr_event)       ap_csr_write;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found")
        ap_exception = new("ap_exception", this);
        ap_csr_write = new("ap_csr_write", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk_i);
            if (vif.exception_valid) begin
                isa_exception_event evt;
                evt.mcause = vif.mcause;
                evt.mepc   = vif.mepc;
                ap_exception.write(evt);
                `uvm_info("EXCEPTION", $sformatf("mcause=%0d mepc=%016h", evt.mcause, evt.mepc), UVM_HIGH)
            end
            if (vif.csr_valid) begin
                isa_csr_event evt;
                evt.csr_addr = vif.csr_addr;
                evt.csr_wdata = vif.csr_wdata;
                ap_csr_write.write(evt);
                `uvm_info("CSR", $sformatf("addr=%03h data=%016h", evt.csr_addr, evt.csr_wdata), UVM_HIGH)
            end
        end
    endtask
    
endclass : isa_csr_monitor

`endif // ISA_CSR_MONITOR_SV