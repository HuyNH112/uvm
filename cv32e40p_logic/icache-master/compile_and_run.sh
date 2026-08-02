#!/bin/bash
# ============================================================
# compile_and_run.sh
#
# Compilation and simulation script for CV32E40P I-Cache
# Supports:
#   - Module compilation
#   - Testbench compilation
#   - Full simulation run
#   - Waveform generation
#
# Usage:
#   ./compile_and_run.sh [compile|simulate|all|clean]
#
# Design Date: July 27, 2026
# Status: ✅ COMPLETE
# ============================================================

set -e

# ===== CONFIGURATION =====
WORK_DIR="./work"
OUTPUT_DIR="./output"
QVERILOG="qverilog"
VSIM="vsim"
VLOG="vlog"

SOURCES=(
  "cv32e40p_icache_pkg.sv"
  "cv32e40p_icache_defines.vh"
  "cv32e40p_icache_tag_mem.sv"
  "cv32e40p_icache_data_mem.sv"
  "plru.sv"
  "plru_tree.sv"
  "cv32e40p_icache.sv"
  "tb_icache.sv"
)

# ===== FUNCTIONS =====
compile() {
  echo "╔════════════════════════════════════════════════════╗"
  echo "║     COMPILING CV32E40P I-CACHE MODULES              ║"
  echo "╚════════════════════════════════════════════════════╝"

  # Create work directory
  if [ ! -d "$WORK_DIR" ]; then
    echo "Creating work directory: $WORK_DIR"
    mkdir -p "$WORK_DIR"
  fi

  # Compile sources
  echo ""
  echo "Compiling SystemVerilog sources..."
  $VLOG -sv +incdir+. ${SOURCES[@]}

  if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Compilation PASSED"
  else
    echo ""
    echo "✗ Compilation FAILED"
    exit 1
  fi
}

simulate() {
  echo ""
  echo "╔════════════════════════════════════════════════════╗"
  echo "║      RUNNING CV32E40P I-CACHE SIMULATION            ║"
  echo "╚════════════════════════════════════════════════════╝"
  echo ""

  if [ ! -d "$WORK_DIR" ]; then
    echo "Work directory not found. Please compile first:"
    echo "  ./compile_and_run.sh compile"
    exit 1
  fi

  # Create output directory
  mkdir -p "$OUTPUT_DIR"

  # Run simulation
  echo "Starting simulation..."
  $VSIM -c \
    -work "$WORK_DIR" \
    -do "vcd file ./output/waveform.vcd; vcd add -r /*; run -all; quit" \
    tb_icache

  if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Simulation PASSED"
    echo "Waveforms saved to: ./output/waveform.vcd"
  else
    echo ""
    echo "✗ Simulation FAILED"
    exit 1
  fi
}

clean() {
  echo "╔════════════════════════════════════════════════════╗"
  echo "║         CLEANING BUILD ARTIFACTS                    ║"
  echo "╚════════════════════════════════════════════════════╝"
  echo ""

  if [ -d "$WORK_DIR" ]; then
    echo "Removing work directory: $WORK_DIR"
    rm -rf "$WORK_DIR"
  fi

  if [ -d "$OUTPUT_DIR" ]; then
    echo "Removing output directory: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
  fi

  echo "✓ Clean complete"
}

# ===== MAIN =====
case "${1:-all}" in
  compile)
    compile
    ;;
  simulate)
    simulate
    ;;
  all)
    compile
    simulate
    ;;
  clean)
    clean
    ;;
  *)
    echo "Usage: $0 [compile|simulate|all|clean]"
    echo ""
    echo "  compile   - Compile all modules"
    echo "  simulate  - Run simulation (requires compilation)"
    echo "  all       - Compile and simulate (default)"
    echo "  clean     - Remove build artifacts"
    exit 1
    ;;
esac

echo ""
echo "Done."
