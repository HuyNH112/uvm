// =============================================================================
// tb_top.sv
// Testbench Top-level — Option A fix: hw_top instantiated as submodule u_hw
// Hierarchical paths updated: hw_top.* → u_hw.*
// =============================================================================
`ifdef INCLUDE_HPDCACHE_CONFIG
  `include "hpdcache_config.svh"
`endif
`ifdef INCLUDE_HPDCACHE_TYPEDEF
  `include "hpdcache_typedef.svh"
`endif

import uvm_pkg::*;
`include "uvm_macros.svh"
import hpdcache_uvm_pkg::*;

// Test library includes (if available)
`ifdef INCLUDE_HPDCACHE_SEQ_LIB
  `include "hpdcache_seq_lib.sv"
`endif
`ifdef INCLUDE_HPDCACHE_BASE_TEST
  `include "hpdcache_base_test.sv"
`endif
`ifdef INCLUDE_HPDCACHE_TEST_LIB
  `include "hpdcache_test_lib.sv"
`endif

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
        // Note: RVFI interface disabled for Phase 1 (HPDcache-only verification)
        // Will be enabled in Phase 2 when CV32E40P core is integrated
        run_test("hpdcache_base_test");
    end

    // -------------------------------------------------------------------------
    // Watchdog
    // -------------------------------------------------------------------------
    initial begin
        repeat (WATCHDOG_CYCLES) @(posedge u_hw.clk_i);
        $display("[WATCHDOG] TIMEOUT after %0d cycles", WATCHDOG_CYCLES);
        $finish;
    end

endmodule : tb_top
