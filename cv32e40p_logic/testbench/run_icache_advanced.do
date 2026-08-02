#!/usr/bin/env modelsim.sh
# run_icache_advanced.do
# Compile & simulate advanced I-Cache test (target: >90% miss rate)

set WORK_DIR [pwd]
set RTL_DIR {D:\khoaluantotnghiep\rtl}
set TB_DIR  {D:\khoaluantotnghiep\testbench}
set SIM_DIR {D:\khoaluantotnghiep\sim}

# Create work library
vlib work
vmap work work

# =========================================================================
# COMPILE PHASE
# =========================================================================
echo "=== COMPILING ADVANCED I-CACHE TEST ==="

# Compile RTL (cv32e40p_icache)
vcom -v93 -work work ${RTL_DIR}/cv32e40p_icache.sv

# Compile testbench (tc_icache_advanced.sv)
vcom -v93 -work work ${TB_DIR}/tc_icache_advanced.sv

if {$?} then {
  echo "!!! Compilation FAILED !!!"
  quit -code 1
} else {
  echo "=== Compilation SUCCESSFUL ==="
}

# =========================================================================
# SIMULATE PHASE
# =========================================================================
echo "=== RUNNING SIMULATION ==="

vsim -work work tc_icache_advanced -voptargs="+acc"

echo "=== SIMULATION COMPLETE ==="
echo "Output: tc_icache_advanced.vcd"
