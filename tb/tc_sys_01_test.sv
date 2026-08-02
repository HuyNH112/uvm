// TC-SYS-01: System Stall (TC 5.3 from testplan)
`ifndef TC_SYS_01_TEST_SV
`define TC_SYS_01_TEST_SV

class tc_sys_01_test extends hpdcache_base_test;
    `uvm_component_utils(tc_sys_01_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 500;
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_axi_stall_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_axi_stall_seq::type_id::create("seq");
        seq.num_trans = 20;
        seq.max_stall_cycles = 10;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // TC_SYS_01_TEST_SV
