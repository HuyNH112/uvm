// TC-INT-02: Hit-Under-Miss (TC 5.1 from testplan)
`ifndef TC_INT_02_TEST_SV
`define TC_INT_02_TEST_SV

class tc_int_02_test extends hpdcache_base_test;
    `uvm_component_utils(tc_int_02_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 600;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_hit_under_miss_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_hit_under_miss_seq::type_id::create("seq");
        seq.num_hits = 10;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_INT_02_TEST_SV
