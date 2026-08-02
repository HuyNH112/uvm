// =============================================================================
// hpdcache_test_isa_lib.sv
// ISA Test Library — TC 1.1, 1.2, 1.3
// =============================================================================

class core_basic_alu_ops extends hpdcache_base_test;
    `uvm_component_utils(core_basic_alu_ops)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "TC 1.1: Basic ALU Operations (mock RVFI generator)", UVM_MEDIUM)

        // Mock generator injects 4 commit events:
        // [0] ADD x2, x0, 1    → x2 = 1
        // [1] ADD x3, x0, 2    → x3 = 2
        // [2] AND x6, x2, x3   → x6 = 0
        // [3] ECALL

        #200;  // Wait for mock generator to produce all commits

        `uvm_info("TEST", "TC 1.1 complete", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass : core_basic_alu_ops
