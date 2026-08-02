quit -sim
set BreakOnAssertion 0
set BreakOnWarning 0
set NumericStdNoWarnings 1
set StdArithNoWarnings 1

# Simulate in non-GUI mode first
vsim -c -work work int02_minimal_proof_tb
run -all
exit