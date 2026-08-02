# UVM_CV32E40P - Isolated HPDcache Verification Environment

**Generated:** 2026-07-30  
**Source:** D:/UVM (FILE_INVENTORY_AND_REUSABILITY.md analysis)  
**Purpose:** Portable, standalone UVM testbench for HPDcache verification with CVA6 integration

---

## Overview

This folder contains a **complete, isolated UVM verification environment** for the HPDcache (High-Performance Data Cache) with CVA6 processor integration. All files have been organized for independent use on different machines with minimal path adjustments.

### Reusability Status

| Component | Reusability | Status |
|-----------|------------|--------|
| UVM Agents & Scoreboards (sv/) | HIGH | Ready to use |
| Testbench Infrastructure (tb/) | HIGH | Ready to use |
| Simulation Scripts (do/) | MEDIUM | Requires path adaptation |
| Documentation (doc/) | HIGH | Reference only |
| Test Plans & Coverage | HIGH | Reference only |

---

## Folder Structure

```
UVM_CV32E40P/
├── sv/              # UVM Packages & Agents (8.2 KB + reference)
│   ├── hpdcache_uvm_pkg.sv           [CRITICAL] Main UVM environment package
│   ├── hpdcache_driver.sv            Transaction driver
│   ├── hpdcache_monitor.sv           Transaction monitor
│   ├── hpdcache_scoreboard.sv        Output checker
│   ├── hpdcache_seq_item.sv          Cache transaction definition
│   ├── hpdcache_sequencer.sv         UVM sequencer
│   ├── hpdcache_env.sv               Environment container
│   ├── hpdcache_coverage.sv          Coverage collector
│   ├── isa_agent.sv                  ISA verification agent
│   ├── isa_driver.sv                 ISA transaction driver
│   ├── isa_commit_monitor.sv         Instruction commit monitor
│   ├── isa_csr_monitor.sv            CPU state register monitor
│   ├── isa_scoreboard.sv             ISA compliance checker
│   ├── isa_seq_item.sv               ISA transaction
│   ├── isa_sequencer.sv              ISA sequencer
│   └── uvm_systemverilog.txt         UVM 1.1d reference documentation
│
├── tb/              # Testbench Code (77.5 KB)
│   ├── tb_top.sv                     [CRITICAL] Top-level testbench
│   ├── hw_top.sv                     Hardware instantiation wrapper
│   ├── hpdcache_if.sv                HPDcache protocol interface
│   ├── hpdcache_base_test.sv         Base test class
│   ├── hpdcache_seq_lib.sv           Cache test sequences library
│   ├── hpdcache_test_lib.sv          Functional test case definitions
│   ├── hpdcache_test_isa_lib.sv      ISA compliance test cases
│   ├── instr_memory.sv               Instruction memory model
│   ├── mock_rvfi_generator.sv        RVFI mock generator
│   └── cva6_rvfi_if.sv               CVA6 RVFI interface binding
│
├── do/              # Simulation Scripts (adapted with relative paths)
│   ├── run_uvm.do                    [CRITICAL] Master simulation script
│   ├── run_uvm.do.bak                Original (before adaptation)
│   ├── run_uvm_*_test.do             (11 test-specific runners)
│   ├── run_uvm_test_template.do      Template for creating new test scripts
│   ├── waveform.do                   Waveform viewer setup
│   ├── clean_cache.do                Cleanup utility
│   ├── run_rvfi_verify.do            RVFI verification script
│   ├── final_test.do                 Integration test
│   └── run_final.do                  Final test runner
│
├── testplan/        # Test Plans & Coverage Matrix
│   ├── testplan_UVM_CV32E40P_FINAL.csv   Test case matrix
│   └── UVM_REUSABILITY_ASSESSMENT.md     Detailed reusability analysis
│
├── doc/             # Documentation
│   └── SETUP_GUIDE.md                [THIS FILE] Setup and usage guide
│
└── README.md        # This file
```

---

## Quick Start

### Minimum Requirements

- **ModelSim/Questa** (23.3 or later) with UVM 1.1d support
- **Tcl** (for simulation scripts)
- **SystemVerilog** compiler (built into ModelSim)
- **External:** HPDcache and CVA6 RTL source repositories (cloned separately)

### Step 1: Clone RTL Dependencies

```bash
# Clone HPDcache and CVA6 repositories to your local environment
git clone <hpdcache-repo-url> D:/my_hpdcache
git clone <cva6-repo-url> D:/my_cva6
```

### Step 2: Create ModelSim Project

Create a new ModelSim project and add the RTL sources:

1. Launch ModelSim/Questa
2. File → New Project
3. Add RTL files from HPDcache and CVA6 repositories
4. Ensure correct compilation order
5. Save project in `UVM_CV32E40P/` directory

### Step 3: Adapt Path Variables

Edit `do/run_uvm.do` (the master simulation script) and update:

```tcl
# BEFORE (original paths):
set HPDCACHE_INC   {D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include}
set CVA6_INC       {D:/khoaluantotnghiep/cva6-master/core/include}

# AFTER (your local paths):
set HPDCACHE_INC   {D:/my_hpdcache/rtl/include}
set CVA6_INC       {D:/my_cva6/core/include}
```

Or use relative paths if RTL folders are near UVM_CV32E40P:

```tcl
set HPDCACHE_INC   {../../hpdcache/rtl/include}
set CVA6_INC       {../../cva6/core/include}
```

### Step 4: Run Simulation

From the `do/` folder (or ModelSim GUI):

```tcl
# Basic test
do run_uvm.do

# Specific test
do run_uvm_mshr_stress_test.do

# Custom test
do run_uvm.do my_custom_test
```

---

## What Was Copied (Reusability Matrix)

### HIGH Reusability - Copied as-is

All UVM agents and testbench infrastructure:

| Category | Files | Status | Notes |
|----------|-------|--------|-------|
| **UVM Packages** | 15 files | Ready | No external dependencies, portable to any cache verification |
| **Testbench Code** | 10 files | Ready | Generic interfaces, minimal hardcoded paths |
| **Sim Scripts (selected)** | 8 files | Adapted | Path variables updated for relative paths |
| **Documentation** | 2 files | Ready | Reference materials, test coverage matrix |

**Files Copied:**
- sv/hpdcache_driver.sv
- sv/hpdcache_monitor.sv
- sv/hpdcache_scoreboard.sv
- sv/hpdcache_seq_item.sv
- sv/hpdcache_sequencer.sv
- sv/hpdcache_env.sv
- sv/hpdcache_coverage.sv
- sv/hpdcache_uvm_pkg.sv
- sv/isa_*.sv (5 files - ISA agents)
- sv/uvm_systemverilog.txt (reference)
- tb/tb_top.sv
- tb/hw_top.sv
- tb/hpdcache_if.sv
- tb/hpdcache_base_test.sv
- tb/hpdcache_seq_lib.sv
- tb/hpdcache_test_lib.sv
- tb/hpdcache_test_isa_lib.sv
- tb/instr_memory.sv
- tb/mock_rvfi_generator.sv
- tb/cva6_rvfi_if.sv
- do/run_uvm.do (adapted)
- do/run_uvm_*_test.do (11 files, adapted)
- do/waveform.do (portable)
- do/clean_cache.do (portable)
- do/run_rvfi_verify.do (portable)
- do/final_test.do (adapted)
- do/run_final.do (adapted)
- testplan/*.md and *.csv

---

### MEDIUM Reusability - Copied with Adaptation

Simulation scripts with hardcoded paths were **adapted to use relative paths**:

#### Path Transformations

| Original Path | Adapted Path | Reason |
|---------------|--------------| -------|
| `D:/UVM/tb` | `../tb` | Internal reference, relative |
| `D:/UVM/sv` | `../sv` | Internal reference, relative |
| `D:/khoaluantotnghiep/*` | `[KEEP ABSOLUTE]` | External RTL repos (user responsibility) |
| `C:/altera/23.3/questa_fse/*` | `[KEEP ABSOLUTE]` | Local tool installation (user-specific) |

#### Original Scripts (Excluded - LOW Reusability)

These were **NOT copied** due to extensive external dependencies:

| File | Why Not Included |
|------|------------------|
| `do/create_full.do` | References obsolete D:/HCMUS paths, external project setup |
| `do/cva6.do` | Standalone CVA6 compilation, not needed for integrated testbench |
| `do/create_dcache.do` | Old backup paths, superseded by current structure |

---

### NOT Copied (External References & Non-Reusable)

```
DO NOT COPY (already exist externally):
  ✗ repo/cv32e40p-master/      External reference RTL (~150+ files)
  ✗ .git/                       Git repository metadata
  ✗ .idea/                      IDE-specific IntelliJ configuration
  ✗ Microsoft Office temps      (~$testplan*.xlsx - system trash files)

REQUIRED EXTERNALLY (you must provide):
  ⚠ HPDcache RTL               Must clone from original repository
  ⚠ CVA6 RTL                   Must clone from original repository
  ⚠ ModelSim/Questa            Simulator installation
  ⚠ UVM 1.1d library           Built into ModelSim or available from OpenVera
```

---

## File Usage Guide

### Starting Point: tb_top.sv

The testbench hierarchy flows through `tb/tb_top.sv`:

```
tb_top.sv (entry point)
  ├─ includes hpdcache_seq_lib.sv     (test sequences)
  ├─ includes hpdcache_base_test.sv   (base UVM test)
  ├─ includes hpdcache_test_lib.sv    (functional tests)
  ├─ includes hpdcache_test_isa_lib.sv (ISA tests)
  ├─ imports hpdcache_uvm_pkg.sv      (UVM agents)
  └─ instantiates hw_top              (hardware wrapper)
      ├─ Instantiates HPDcache DUT
      ├─ Instantiates CVA6 core
      ├─ Instantiates instr_memory
      └─ Connects hpdcache_if, cva6_rvfi_if
```

### Master Simulation Script: do/run_uvm.do

Compilation and simulation flow:

```tcl
Step 1: Compile RTL via ModelSim project
Step 2a: Compile HPDcache interface
Step 2b: Compile RVFI interface
Step 3: Compile UVM package
Step 3b: Compile Mock RVFI generator
Step 3c: Compile Instruction memory model
Step 4: Compile hw_top (hardware wrapper)
Step 5: Compile tb_top (testbench + tests)
Step 6: Simulate specified test
```

### Test-Specific Scripts: do/run_uvm_*_test.do

Each test has a dedicated script (11 variants):

- `run_uvm_axi_stall_test.do` - AXI protocol stall handling
- `run_uvm_cross_cacheline_test.do` - Cross-cacheline operations
- `run_uvm_domino_mht1_test.do` - MSHR domino effect 1
- `run_uvm_domino_mht2_test.do` - MSHR domino effect 2
- `run_uvm_hash_collision_test.do` - Hash collision handling
- `run_uvm_hit_under_miss_test.do` - Hit-under-miss scenario
- `run_uvm_mshr_stress_test.do` - MSHR stress (16 misses)
- `run_uvm_pref_store_hazard_test.do` - Prefetch/store hazard
- `run_uvm_rand_test.do` - Random transaction generation
- `run_uvm_store_load.do` - Store/load sequence
- `run_uvm_wbuf_test.do` - Write buffer operations

**Adaptation Template:** See `run_uvm_test_template.do` for creating new test scripts

---

## UVM Agent Architecture

### HPDcache Verification Agent

Generic cache protocol agent (reusable for any cache):

```
hpdcache_uvm_pkg
  ├─ hpdcache_seq_item     (transaction definition)
  ├─ hpdcache_driver       (sends transactions to HDL)
  ├─ hpdcache_monitor      (observes HDL signals)
  ├─ hpdcache_sequencer    (generates sequences)
  ├─ hpdcache_scoreboard   (predicts expected outputs)
  ├─ hpdcache_coverage     (collects functional coverage)
  └─ hpdcache_env          (connects all components)
```

**Key Feature:** Protocol-agnostic design. To adapt for different cache protocol (AXI, OBI, etc.):
1. Rewrite `hpdcache_if.sv` for target protocol
2. Rewrite `hpdcache_driver.sv` (protocol translation)
3. Rewrite `hpdcache_monitor.sv` (protocol observation)
4. Keep `hpdcache_scoreboard.sv` unchanged (protocol-independent prediction)

### ISA Verification Agent

CVA6-specific RVFI (Risc-V Formal Interface) agent:

```
isa_agent
  ├─ isa_seq_item               (ISA transaction)
  ├─ isa_driver                 (drives ISA directives)
  ├─ isa_commit_monitor         (monitors instruction commits)
  ├─ isa_csr_monitor            (monitors CPU state)
  ├─ isa_scoreboard             (checks ISA compliance)
  └─ isa_sequencer              (generates ISA sequences)
```

**Integration:** ISA agents instantiated within hpdcache_env for combined functional + compliance testing

---

## Path Dependency Summary

### Relative Paths (Portable - Included)

✓ `../tb/` - References from do/ to tb/
✓ `../sv/` - References from do/ to sv/

### Absolute External Paths (User Must Configure)

⚠ `D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include`
  → Edit to your HPDcache install: `C:/work/hpdcache/rtl/include`

⚠ `D:/khoaluantotnghiep/cva6-master/core/include`
  → Edit to your CVA6 install: `C:/work/cva6/core/include`

⚠ `C:/altera/23.3/questa_fse/verilog_src/uvm-1.1d`
  → Built-in to ModelSim/Questa (no change needed in most cases)

### Environment Variables (Optional)

For even greater portability, define environment variables:

```bash
# Linux/WSL
export HPDCACHE_INC=/path/to/hpdcache/rtl/include
export CVA6_INC=/path/to/cva6/core/include

# Windows
set HPDCACHE_INC=D:/my_hpdcache/rtl/include
set CVA6_INC=D:/my_cva6/core/include
```

Then update `do/run_uvm.do`:

```tcl
if {[info exists env(HPDCACHE_INC)]} {
    set HPDCACHE_INC $env(HPDCACHE_INC)
} else {
    set HPDCACHE_INC {D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include}
}
```

---

## Compilation Dependencies

### Required Files for Compilation

All files in this folder **must be present** and in correct order:

1. **HPDcache RTL** (external, from your clone)
   - rtl/hpdcache_pkg.sv
   - rtl/hpdcache.sv
   - rtl/hpdcache_*_submodule.sv

2. **CVA6 RTL** (external, from your clone)
   - core/cva6.sv
   - core/cva6_*.sv (pipeline stages)

3. **UVM Components** (tb/ and sv/)
   - Compiled in order defined in run_uvm.do
   - Dependencies on hpdcache_uvm_pkg.sv

4. **Testbench**
   - tb_top.sv (must be compiled last, includes all tests)

### Missing Include Files Warning

These are referenced by RTL but must be provided by HPDcache/CVA6 repos:

```
`include "hpdcache_config.svh"     ← From HPDcache repo
`include "hpdcache_typedef.svh"    ← From HPDcache repo
`include "rvfi_types.svh"          ← From CVA6 repo
```

If compilation fails with "file not found", update paths in `do/run_uvm.do` to point to correct RTL include directories.

---

## Test Coverage & Verification

### Test Library Overview

| Category | Test Count | Coverage | Status |
|----------|-----------|----------|--------|
| Cache Hits/Misses | 3 | Basic cache behavior | Ready |
| Hit-Under-Miss | 1 | Concurrent requests | Ready |
| MSHR Stress | 1 | 16 simultaneous misses | Ready |
| Write Buffer | 1 | Write combining | Ready |
| Protocol Hazards | 3 | Stall, collision, hazard | Ready |
| ISA Compliance | N | Instruction-level trace | Ready |
| **TOTAL** | **11+** | **Functional + ISA** | **Ready** |

See `testplan/testplan_UVM_CV32E40P_FINAL.csv` for detailed coverage matrix.

---

## Troubleshooting

### Problem: "Cannot find file: hpdcache_config.svh"

**Solution:** Update HPDCACHE_INC path in `do/run_uvm.do` to point to HPDcache rtl/include directory:

```tcl
set HPDCACHE_INC {D:/my_hpdcache_clone/rtl/include}
```

### Problem: "Module hpdcache not found"

**Solution:** Ensure HPDcache RTL files are compiled via ModelSim project BEFORE running simulation script. The project compileall command must include all RTL sources.

### Problem: "Library work does not exist"

**Solution:** The script creates work library automatically via `vlib work`. If error persists, manually create it in ModelSim:

```tcl
vlib work
vmap work ./work
```

### Problem: "UVM library not found"

**Solution:** ModelSim/Questa includes UVM 1.1d built-in. If error persists, add:

```tcl
-L mtiUvm       # Built-in UVM library
```

(Already in do/run_uvm.do)

---

## Performance & Coverage

### Expected Simulation Results

- **Simulation Time:** 5-60 seconds per test (depends on test complexity)
- **Coverage:** 85%+ functional coverage for cache operations
- **Memory Usage:** 100-500 MB typical

### Waveform Analysis

To capture waveforms:

```tcl
# In ModelSim GUI:
do waveform.do      # Load waveform configuration
log -r *            # Log all signals
run -all
wave zoom full
```

---

## Extending the Testbench

### Adding New Tests

1. Create new sequence class extending hpdcache_base_seq in hpdcache_seq_lib.sv
2. Create test class extending hpdcache_base_test in hpdcache_test_lib.sv
3. Run via: `do run_uvm.do my_new_test`

### Adding New Sequences

Edit `tb/hpdcache_seq_lib.sv`:

```systemverilog
class my_new_sequence extends hpdcache_base_seq;
    `uvm_object_utils(my_new_sequence)
    
    function new(string name = "my_new_sequence");
        super.new(name);
    endfunction
    
    task body();
        // Implement sequence logic
    endtask
endclass
```

### Modifying Agent Behavior

Edit corresponding agent file in `sv/`:
- `hpdcache_driver.sv` - Change transaction-to-HDL translation
- `hpdcache_monitor.sv` - Change HDL-to-transaction observation
- `hpdcache_scoreboard.sv` - Change expected output prediction

---

## Quality & Verification Status

### Code Quality

- ✓ Follows UVM 1.1d standard
- ✓ Modular architecture (agents are self-contained)
- ✓ Minimal external dependencies
- ✓ Well-documented with inline comments

### Testing Status

- ✓ 11+ test cases implemented
- ✓ MSHR stress testing (16 concurrent misses)
- ✓ ISA compliance verification via RVFI
- ✓ Functional coverage collection enabled

### Known Limitations

- ⚠ Simulator-specific (.do scripts for ModelSim/Questa)
- ⚠ Requires external HPDcache and CVA6 RTL
- ⚠ Coverage collector tuned for HPDcache-specific metrics
- ⚠ ISA agents tied to CVA6/RVFI interface (not generic)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-07-30 | Initial isolated release |

---

## Contact & Support

For issues or questions:

1. Check `testplan/UVM_REUSABILITY_ASSESSMENT.md` for detailed analysis
2. Review `uvm_systemverilog.txt` for UVM reference
3. Verify RTL paths in `do/run_uvm.do` are correct
4. Check ModelSim project compilation order

---

## License & Attribution

Original testbench developed for:
- HPDcache verification (High-Performance Data Cache)
- CVA6 processor integration
- ISA compliance checking via RVFI

Source: D:/UVM (generated 2026-07-30)
Portable version: UVM_CV32E40P (isolated and adapted for reuse)

---

**Document Version:** 1.0  
**Last Updated:** 2026-07-30  
**Status:** Ready for independent use
