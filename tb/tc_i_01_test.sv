// TC-I-01: ICache Sequential Fetch (TC 2.1 from testplan)
`ifndef TC_I_01_TEST_SV
`define TC_I_01_TEST_SV

class tc_i_01_test extends hpdcache_base_test;
    `uvm_component_utils(tc_i_01_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 400;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_rand_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_rand_seq::type_id::create("seq");
        seq.num_trans = 20;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_I_01_TEST_SV
