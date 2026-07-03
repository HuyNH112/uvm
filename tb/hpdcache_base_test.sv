`ifndef HPDCACHE_BASE_TEST_SV
`define HPDCACHE_BASE_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import hpdcache_pkg::*;
import hpdcache_uvm_pkg::*;

class hpdcache_base_test extends uvm_test;
    `uvm_component_utils(hpdcache_base_test)

    hpdcache_env       env;
    virtual hpdcache_if vif;

    function new(string name = "hpdcache_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = hpdcache_env::type_id::create("env", this);

        if (!uvm_config_db #(virtual hpdcache_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("TEST", "Khong the lay virtual interface 'vif' tu config_db!")
        end

        env.set_hpdcache_vif(vif);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_seq_item req;
        phase.raise_objection(this);

        `uvm_info("TEST", "=== BAT DAU HPDCACHE BASE TEST ===", UVM_LOW)

        for (int i = 0; i < 5; i++) begin
            req = hpdcache_seq_item::type_id::create("req");
            if (!req.randomize())
                `uvm_fatal("TEST", "Randomize that bai!")
            `uvm_info("TEST_ITEM",
                $sformatf("Lenh thu %0d: %s", i+1, req.convert2string()),
                UVM_LOW)
        end

        `uvm_info("TEST", "=== KET THUC BASE TEST ===", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : hpdcache_base_test

`endif