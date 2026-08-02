# ============================================================
# run_icache_test.do - Run I-Cache Miss Rate Test
# ============================================================

# Disable GUI dialogs for batch mode
quit -sim
set BreakOnAssertion 0
set BreakOnWarning 0

# Simulate the testbench in batch mode (no dialogs)
vsim -c -batch tc_icache_miss_rate -do "
  run -all
  quit -sim
"

exit
