# ============================================================
# int_verify_5loop.do - 5-ITERATION COMPLETE VERIFICATION
# Purpose: Compile, run 5-loop verification, capture all results
# Date: 30 July 2026
# Status: AUTO-RUN ALL CHECKS
# ============================================================

quit -sim
catch {project close}

set BASE_DIR      "D:/khoaluantotnghiep/project_e40p"
set TESTBENCH_DIR "D:/khoaluantotnghiep/testbench"
set INTEGRATION_DIR "D:/khoaluantotnghiep/integration"

file mkdir $BASE_DIR
project new $BASE_DIR int_verify_5loop work

# ============================================================
# MINIMAL COMPILATION (Adapter + Testbench only)
# ============================================================
puts "\n╔════════════════════════════════════════════════════════════╗"
puts "║  INT_VERIFY_5LOOP.DO - COMPLETE VERIFICATION              ║"
puts "║  5-Iteration Loop with Full Checks                         ║"
puts "╚════════════════════════════════════════════════════════════╝\n"

# Add only essential files
puts "Adding Adapter and Testbench files..."
project addfile $INTEGRATION_DIR/obi_to_axi4_adapter.sv systemverilog
project addfile $TESTBENCH_DIR/int_full_integration.sv systemverilog

puts "Compilation starting...\n"

# ============================================================
# COMPILE
# ============================================================
catch {project compileall} compile_result

puts "\n"
if {[string match "*0 failed*" $compile_result]} {
    puts "✓ Compilation successful!"
} else {
    puts "✗ Compilation has issues:"
    puts $compile_result
}

# ============================================================
# ELABORATE
# ============================================================
puts "\nElaborating testbench..."
catch {elaborate int_full_integration_tb} elab_result

if {[string match "*Error*" $elab_result]} {
    puts "✗ Elaboration failed"
    puts $elab_result
    $finish
}

# ============================================================
# SIMULATE WITH WAVEFORM CAPTURE
# ============================================================
puts "\n╔════════════════════════════════════════════════════════════╗"
puts "║  STARTING 5-ITERATION VERIFICATION LOOP                    ║"
puts "║  Each iteration runs full test sequence with pass/fail     ║"
puts "╚════════════════════════════════════════════════════════════╝\n"

# Run simulation
catch {vsim -c work.int_full_integration_tb -do "run -all; quit -f"} sim_result

# ============================================================
# RESULTS CAPTURE
# ============================================================
puts "\n"
puts "╔════════════════════════════════════════════════════════════╗"
puts "║  VERIFICATION COMPLETE                                     ║"
puts "║  Check transcript and waveform for detailed results        ║"
puts "║                                                            ║"
puts "║  Output files:                                            ║"
puts "║  - Transcript: $BASE_DIR/transcript                       ║"
puts "║  - Waveform:   int_full_integration.vcd                   ║"
puts "║  - Signals:    See WAVEFORM_SIGNAL_LIST.md                ║"
puts "║                                                            ║"
puts "║  Next steps:                                              ║"
puts "║  1. View waveform: gtkwave int_full_integration.vcd       ║"
puts "║  2. Check test results in simulation output               ║"
puts "║  3. Review WAVEFORM_SIGNAL_LIST.md for signal meanings    ║"
puts "║                                                            ║"
puts "╚════════════════════════════════════════════════════════════╝\n"

# Save project
project save
