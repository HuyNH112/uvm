// TC-D-02: DCache Write Buffer (TC 3.2 from testplan)
`ifndef TC_D_02_TEST_SV
`define TC_D_02_TEST_SV

class tc_d_02_test extends hpdcache_base_test;
    `uvm_component_utils(tc_d_02_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 500;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_store_load_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_store_load_seq::type_id::create("seq");
        seq.num_pairs = 8;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_D_02_TEST_SV
