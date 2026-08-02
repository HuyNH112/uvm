// TC-D-03: DCache Coherency (TC 2.3 from testplan)
`ifndef TC_D_03_TEST_SV
`define TC_D_03_TEST_SV

class tc_d_03_test extends hpdcache_base_test;
    `uvm_component_utils(tc_d_03_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 400;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_cross_cacheline_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_cross_cacheline_seq::type_id::create("seq");
        seq.num_accesses = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_D_03_TEST_SV
