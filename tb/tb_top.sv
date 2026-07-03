`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

import hpdcache_pkg::*;
import hpdcache_uvm_pkg::*;

`include "tb/hpdcache_base_test.sv"
`include "tb/hpdcache_test_lib.sv"

module tb_top;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk_i;
    logic rst_ni;

    initial clk_i = 1'b0;
    always #2.5 clk_i = ~clk_i;  // 200 MHz

    initial begin
        rst_ni = 1'b0;
        repeat (10) @(posedge clk_i);
        rst_ni = 1'b1;
        `uvm_info("TOP", "Reset released", UVM_LOW)
    end

    // -------------------------------------------------------------------------
    // Interface instantiation
    // -------------------------------------------------------------------------
    hpdcache_if hpdcache_vif (
        .clk_i  (clk_i),
        .rst_ni (rst_ni)
    );

    // -------------------------------------------------------------------------
    // Hardware top: DUT + memory model
    // -------------------------------------------------------------------------
    hw_top u_hw_top (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .hpdcache_vif (hpdcache_vif)
    );

    // -------------------------------------------------------------------------
    // UVM startup
    // -------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual hpdcache_if)::set(null, "uvm_test_top.*", "vif", hpdcache_vif);
        run_test();
    end

    // -------------------------------------------------------------------------
    // Global watchdog
    // -------------------------------------------------------------------------
    initial begin
        #500000;
        `uvm_fatal("TOP", "WATCHDOG: Simulation timeout!")
    end

endmodule : tb_top