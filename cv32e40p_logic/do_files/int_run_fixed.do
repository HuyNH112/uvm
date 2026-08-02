# ============================================================
# int_run_fixed.do - Run fixed integration test
# Date: 30 July 2026
# ============================================================

puts "\n"
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  INT_RUN_FIXED.DO - RUNNING FIXED INTEGRATION TEST            ║"
puts "║  Timing fixes: fork/wait for responses instead of repeat()    ║"
puts "║  Monitor fixes: pulse checks at correct latency values        ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

cd D:/khoaluantotnghiep/project_e40p

# Close previous project
catch {project close}
file mkdir work

# Create new project
project new . int_run_fixed work

# Add files
puts "Adding RTL files..."
project addfile D:/khoaluantotnghiep/integration/obi_to_axi4_adapter.sv systemverilog
project addfile D:/khoaluantotnghiep/testbench/int_full_integration.sv systemverilog

# Compile
puts "Compiling..."
catch {project compileall} compile_result
puts $compile_result

# Elaborate
puts "Elaborating..."
catch {elaborate int_full_integration_tb} elab_result
if {[string match "*Error*" $elab_result]} {
    puts "✗ Elaboration failed"
    puts $elab_result
    exit
} else {
    puts "✓ Elaboration successful"
}

# Run simulation
puts "Running simulation with fixed timing..."
vsim -c work.int_full_integration_tb -do "run -all; exit"

puts ""
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  SIMULATION COMPLETE                                           ║"
puts "║  Check int_full_integration.vcd for waveform analysis          ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

project save
