// =============================================================================
// tb_top.sv
// Testbench Top-level — Option A fix: hw_top instantiated as submodule u_hw
// Hierarchical paths updated: hw_top.* → u_hw.*
// =============================================================================
`include "hpdcache_config.svh"
`include "hpdcache_typedef.svh"

import uvm_pkg::*;
`include "uvm_macros.svh"
import hpdcache_uvm_pkg::*;

`include "hpdcache_seq_lib.sv"
`include "hpdcache_base_test.sv"
`include "hpdcache_test_lib.sv"

module tb_top;

    import uvm_pkg::*;
    import hpdcache_uvm_pkg::*;

    localparam int unsigned WATCHDOG_CYCLES = 20000;

    // -------------------------------------------------------------------------
    // hw_top instantiation — port-less (clock/reset generated internally)
    // -------------------------------------------------------------------------
    hw_top u_hw ();

    // -------------------------------------------------------------------------
    // UVM config_db + run_test
    // -------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual hpdcache_if.driver_mp)::set(
            null,
            "uvm_test_top.env.driver",
            "hpdcache_vif_driver",
            u_hw.dut_if.driver_mp
        );

        uvm_config_db #(virtual hpdcache_if.monitor_mp)::set(
            null,
            "uvm_test_top.env.monitor",
            "hpdcache_vif_monitor",
            u_hw.dut_if.monitor_mp
        );

        run_test("hpdcache_base_test");
    end

    // -------------------------------------------------------------------------
    // Watchdog
    // -------------------------------------------------------------------------
    initial begin
        repeat (WATCHDOG_CYCLES) @(posedge u_hw.clk);
        $display("[WATCHDOG] TIMEOUT after %0d cycles", WATCHDOG_CYCLES);
        $finish;
    end

endmodule : tb_top
