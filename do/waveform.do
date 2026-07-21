# =============================================================================
# waveform.do — Optional Waveform Configuration for STEP 3
# =============================================================================
# Purpose: Add waveforms for debugging (call AFTER elaboration in vsim)
# Usage: do waveform.do (when vsim is running interactively)
# =============================================================================

echo "\n>>> Loading waveform configuration for STEP 3...\n"

# Clock & Reset
add wave -divider "╔════════ CLOCK / RESET ════════╗"
add wave /tb_top/u_hw/clk
add wave /tb_top/u_hw/rst_n

# CVA6 RVFI Monitoring (ISA verification)
add wave -divider "╔════════ CVA6 RVFI (ISA Agent) ════════╗"
add wave /tb_top/u_hw/rvfi_vif/commit_valid
add wave -radix hex /tb_top/u_hw/rvfi_vif/commit_pc
add wave -radix hex /tb_top/u_hw/rvfi_vif/commit_instr
add wave -radix hex /tb_top/u_hw/rvfi_vif/commit_rd_addr
add wave /tb_top/u_hw/rvfi_vif/commit_rd_we
add wave -radix hex /tb_top/u_hw/rvfi_vif/commit_rd_wdata
add wave /tb_top/u_hw/rvfi_vif/exception_valid
add wave -radix hex /tb_top/u_hw/rvfi_vif/mcause
add wave -radix hex /tb_top/u_hw/rvfi_vif/mepc

# HPDcache Core Interface
add wave -divider "╔════════ HPDCACHE CORE REQ/RSP ════════╗"
add wave /tb_top/u_hw/dut_if/core_req_valid_i
add wave /tb_top/u_hw/dut_if/core_req_ready_o
add wave -radix hex /tb_top/u_hw/dut_if/core_req_i
add wave /tb_top/u_hw/dut_if/core_rsp_valid_o
add wave -radix hex /tb_top/u_hw/dut_if/core_rsp_o

# AXI Memory Interface (Read)
add wave -divider "╔════════ AXI READ ════════╗"
add wave /tb_top/u_hw/dut_if/mem_req_read_valid_o
add wave /tb_top/u_hw/dut_if/mem_req_read_ready_i
add wave -radix hex /tb_top/u_hw/dut_if/mem_req_read_addr_o
add wave -radix hex /tb_top/u_hw/dut_if/mem_req_read_id_o
add wave /tb_top/u_hw/dut_if/mem_resp_read_valid_i
add wave /tb_top/u_hw/dut_if/mem_resp_read_ready_o

# AXI Memory Interface (Write)
add wave -divider "╔════════ AXI WRITE ════════╗"
add wave /tb_top/u_hw/dut_if/mem_req_write_valid_o
add wave /tb_top/u_hw/dut_if/mem_req_write_ready_i
add wave /tb_top/u_hw/dut_if/mem_req_write_addr_o
add wave /tb_top/u_hw/dut_if/mem_resp_write_valid_i
add wave /tb_top/u_hw/dut_if/mem_resp_write_ready_o

# Performance Events
add wave -divider "╔════════ PERF EVENTS ════════╗"
add wave /tb_top/u_hw/dut_if/evt_cache_read_miss_o
add wave /tb_top/u_hw/dut_if/evt_cache_write_miss_o
add wave /tb_top/u_hw/dut_if/evt_prefetch_req_o
add wave /tb_top/u_hw/dut_if/evt_stall_o
add wave /tb_top/u_hw/dut_if/wbuf_empty_o

echo ">>> Waveform configuration loaded"
echo ">>> Run: run -all; wave zoom full\n"
