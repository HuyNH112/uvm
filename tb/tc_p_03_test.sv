// TC-P-03: Prefetcher Hash Collision (TC 4.3 from testplan)
`ifndef TC_P_03_TEST_SV
`define TC_P_03_TEST_SV

class tc_p_03_test extends hpdcache_base_test;
    `uvm_component_utils(tc_p_03_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 500;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_hash_collision_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_hash_collision_seq::type_id::create("seq");
        seq.num_rounds = 8;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_P_03_TEST_SV
