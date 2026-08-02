# compile_advanced.do
# Compile existing cv32e40p_icache project + tc_icache_advanced testbench
# Assumes: cv32e40p_icache RTL already compiled in work library

set TB_DIR {D:\khoaluantotnghiep\testbench}

echo "=== COMPILE ADVANCED I-CACHE TEST ==="
echo "Adding tc_icache_advanced.sv to existing work library..."

# Compile only the new testbench (RTL already exists in work/)
vcom -93 -work work ${TB_DIR}/tc_icache_advanced.sv

if {$?} then {
  echo "!!! Compilation FAILED !!!"
  quit -code 1
} else {
  echo "✓ Compilation SUCCESS"
  echo ""
  echo "Ready to simulate:"
  echo "  vsim -work work tc_icache_advanced"
}
