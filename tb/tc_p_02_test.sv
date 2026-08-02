// TC-P-02: Prefetcher MHT2 (TC 4.2 from testplan)
`ifndef TC_P_02_TEST_SV
`define TC_P_02_TEST_SV

class tc_p_02_test extends hpdcache_base_test;
    `uvm_component_utils(tc_p_02_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 600;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_domino_mht2_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_domino_mht2_seq::type_id::create("seq");
        seq.num_train_rounds = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_P_02_TEST_SV
