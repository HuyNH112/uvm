// =============================================================================
// hpdcache_base_test.sv
// Base test: build env, get VIF từ config_db trong connect_phase (KHÔNG build_phase)
// UVM 1.1d: run_phase only, no reset_phase/main_phase
// =============================================================================
`ifndef HPDCACHE_BASE_TEST_SV
`define HPDCACHE_BASE_TEST_SV

class hpdcache_base_test extends uvm_test;

    `uvm_component_utils(hpdcache_base_test)

    hpdcache_env env;

    // Post-simulation drain time (cycles)
    int unsigned drain_cycles;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drain_cycles = 300;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = hpdcache_env::type_id::create("env", this);
    endfunction

    // connect_phase: set VIF cho driver và monitor từ config_db
    // CRITICAL: KHÔNG được gọi get() trong build_phase → SIGSEGV
    function void connect_phase(uvm_phase phase);
        virtual hpdcache_if.driver_mp  drv_vif;
        virtual hpdcache_if.monitor_mp mon_vif;

        if (!uvm_config_db #(virtual hpdcache_if.driver_mp)::get(
                this, "env.driver", "hpdcache_vif_driver", drv_vif))
            `uvm_fatal("NOVIF", "Base test: cannot get driver VIF")

        if (!uvm_config_db #(virtual hpdcache_if.monitor_mp)::get(
                this, "env.monitor", "hpdcache_vif_monitor", mon_vif))
            `uvm_fatal("NOVIF", "Base test: cannot get monitor VIF")

        // Forward xuống component
        uvm_config_db #(virtual hpdcache_if.driver_mp)::set(
            this, "env.driver", "hpdcache_vif_driver", drv_vif);
        uvm_config_db #(virtual hpdcache_if.monitor_mp)::set(
            this, "env.monitor", "hpdcache_vif_monitor", mon_vif);
    endfunction

    task run_phase(uvm_phase phase);
        hpdcache_rand_seq seq;
        phase.raise_objection(this);

        seq = hpdcache_rand_seq::type_id::create("smoke_seq");
        seq.num_trans = 5;
        seq.start(env.sequencer);

        // Drain: đợi DUT finish tất cả inflight transactions
        // FIX: dùng typed handle env.driver thay vì get_child() chain
        // get_child() → uvm_component (base) → compiler không thấy field vif
        repeat (drain_cycles) @(posedge env.driver.vif.clk_i);

        phase.drop_objection(this);
    endtask

    // Convenience: đợi N clock cycles qua vif
    task wait_cycles(input int unsigned n);
        repeat (n) @(posedge env.driver.vif.clk_i);
    endtask

endclass : hpdcache_base_test

`endif // HPDCACHE_BASE_TEST_SV