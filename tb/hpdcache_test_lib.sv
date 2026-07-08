// =============================================================================
// hpdcache_test_lib.sv — 14 Tests (khớp UVM_HPDcache_11TCs.md)
// =============================================================================
`ifndef HPDCACHE_TEST_LIB_SV
`define HPDCACHE_TEST_LIB_SV

// =============================================================================
// hpdcache_rand_test — num_trans=20
// =============================================================================
class hpdcache_rand_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_rand_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 400;
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

// =============================================================================
// hpdcache_store_load_test — TC 3.1/3.2, num_pairs=8
// =============================================================================
class hpdcache_store_load_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_store_load_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 500;
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

// =============================================================================
// hpdcache_cross_cacheline_test — TC 3.3, num_accesses=4
// =============================================================================
class hpdcache_cross_cacheline_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_cross_cacheline_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 400;
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

// =============================================================================
// hpdcache_domino_mht1_test — TC 4.1, num_train_rounds=4
// =============================================================================
class hpdcache_domino_mht1_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_domino_mht1_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 600;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_domino_mht1_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_domino_mht1_seq::type_id::create("seq");
        seq.num_train_rounds = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_domino_mht2_test — TC 4.2, num_train_rounds=4
// =============================================================================
class hpdcache_domino_mht2_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_domino_mht2_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 600;
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

// =============================================================================
// hpdcache_hash_collision_test — TC 4.3, num_rounds=8
// =============================================================================
class hpdcache_hash_collision_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_hash_collision_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 500;
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

// =============================================================================
// hpdcache_mshr_stress_test — TC 4.4, num_miss=16
// =============================================================================
class hpdcache_mshr_stress_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_mshr_stress_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 800;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_mshr_stress_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_mshr_stress_seq::type_id::create("seq");
        seq.num_miss = 16;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_hit_under_miss_test — TC 5.1, num_hits=10
// =============================================================================
class hpdcache_hit_under_miss_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_hit_under_miss_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 600;
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

// =============================================================================
// hpdcache_pref_store_hazard_test — TC 5.2, num_rounds=4
// =============================================================================
class hpdcache_pref_store_hazard_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_pref_store_hazard_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 500;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_pref_store_hazard_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_pref_store_hazard_seq::type_id::create("seq");
        seq.num_rounds = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_axi_stall_test — TC 5.3, num_trans=20
// =============================================================================
class hpdcache_axi_stall_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_axi_stall_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 500;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_axi_stall_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_axi_stall_seq::type_id::create("seq");
        seq.num_trans        = 20;
        seq.max_stall_cycles = 10;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_stride_test — num_accesses=16
// =============================================================================
class hpdcache_stride_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_stride_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 600;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_stride_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_stride_seq::type_id::create("seq");
        seq.num_accesses = 16;
        seq.stride_bytes  = 64;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_wbuf_test — num_pairs=4
// =============================================================================
class hpdcache_wbuf_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_wbuf_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 400;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_wbuf_forwarding_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_wbuf_forwarding_seq::type_id::create("seq");
        seq.num_pairs = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// hpdcache_domino_test — num_patterns=4
// =============================================================================
class hpdcache_domino_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_domino_test)
    function new(string name, uvm_component parent);
        super.new(name, parent); drain_cycles = 600;
    endfunction
    task run_phase(uvm_phase phase);
        hpdcache_domino_training_seq seq;
        phase.raise_objection(this);
        seq = hpdcache_domino_training_seq::type_id::create("seq");
        seq.num_patterns = 4;
        seq.start(env.sequencer);
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);
        phase.drop_objection(this);
    endtask
endclass

`endif // HPDCACHE_TEST_LIB_SV
