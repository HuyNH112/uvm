# UVM_CV32E40P Setup & Installation Guide

**Date:** 2026-07-30  
**Purpose:** Step-by-step guide to set up and use the isolated UVM testbench environment

---

## Prerequisites

Before proceeding, ensure you have:

### Software Requirements

- **ModelSim/Questa** (version 23.3 or later)
  - Must include UVM 1.1d library
  - Installation: `C:/altera/23.3/questa_fse/` (or your installation path)

- **Tcl** (Tool Command Language)
  - Usually included with ModelSim/Questa
  - Required for running .do scripts

- **Git** (optional, but recommended for cloning RTL repos)

- **Text Editor** (for editing .do scripts and paths)
  - VSCode, Notepad++, or ModelSim's built-in editor

### Hardware Requirements

- Minimum 2GB RAM (4GB+ recommended)
- 500MB disk space for UVM_CV32E40P folder
- Additional 1-2GB for HPDcache and CVA6 RTL clones

---

## Installation Steps

### Step 1: Obtain RTL Source Files

You need to clone two external repositories:

#### Option A: Clone from Original Repositories

```bash
# Clone HPDcache repository
git clone https://github.com/microsoft/cv-hpdcache.git D:/my_work/hpdcache

# Clone CVA6 repository
git clone https://github.com/openhwgroup/cva6.git D:/my_work/cva6
```

#### Option B: Copy from Existing Installation

If you already have HPDcache and CVA6 cloned elsewhere, note their paths:

```
D:/existing/path/to/hpdcache
D:/existing/path/to/cva6
```

### Step 2: Create ModelSim Project

Launch ModelSim/Questa and create a new project:

```
1. File → New Project
2. Project Name: "UVM_CV32E40P"
3. Project Location: D:/UVM/UVM_CV32E40P
4. Create Library: "work"
5. Project File Location: D:/UVM/UVM_CV32E40P/UVM_CV32E40P.mpf
```

### Step 3: Add RTL Source Files to Project

In ModelSim project:

```
1. Project → Add to Project → Existing File
2. Navigate to HPDcache RTL folder
3. Add all files in order:
   - rtl/hpdcache_pkg.sv (FIRST)
   - rtl/hpdcache.sv
   - rtl/hpdcache_*_submodule.sv (in compilation order)
   
4. Add CVA6 RTL:
   - core/cva6.sv
   - core/cva6_*_modules.sv (in compilation order)
   
5. Save project
```

**Important:** RTL file compilation order matters! Packages must compile before modules that use them.

### Step 4: Update Simulation Script Paths

Edit `D:/UVM/UVM_CV32E40P/do/run_uvm.do`:

```tcl
# Find these lines (approximately line 23-24):
set HPDCACHE_INC   {D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include}
set CVA6_INC       {D:/khoaluantotnghiep/cva6-master/core/include}

# Replace with your actual paths:
set HPDCACHE_INC   {D:/my_work/hpdcache/rtl/include}
set CVA6_INC       {D:/my_work/cva6/core/include}
```

**Relative Path Alternative:** If RTL is close to UVM_CV32E40P:

```tcl
# Structure:
# D:/work/
#   ├── hpdcache/
#   ├── cva6/
#   └── UVM_CV32E40P/
#       └── do/run_uvm.do

# Then use:
set HPDCACHE_INC   {../../hpdcache/rtl/include}
set CVA6_INC       {../../cva6/core/include}
```

### Step 5: Update All Test Scripts

Do the same path update for other .do scripts:

```bash
# For each run_uvm_*_test.do file:
# - Edit lines setting HPDCACHE_INC and CVA6_INC
# - Update to your local paths
```

**Or use the template:** Copy `run_uvm_test_template.do` to create new test scripts with correct paths already set.

---

## Quick Test Run

### First-Time Verification

To verify everything is set up correctly:

```bash
cd D:/UVM/UVM_CV32E40P/do

# Launch ModelSim in command-line mode
vsim -do "run_uvm.do"

# Or in ModelSim GUI:
# File → Open → run_uvm.do (then click "Dofile" button)
```

### Expected Output

```
==========================================================
UVM_CV32E40P Testbench - Adapted Simulation Script
==========================================================
Test: core_basic_alu_ops
TB_DIR: ../tb
SV_DIR: ../sv
HPDCACHE_INC: D:/my_work/hpdcache/rtl/include
CVA6_INC: D:/my_work/cva6/core/include

=== Step 1: Compile RTL (via project) ===
[RTL compilation output...]

=== Step 2a: Compile HPDcache Interface ===
[Interface compilation...]

...

=== Step 6: Simulate core_basic_alu_ops ===
[UVM environment output]
UVM_INFO @ 0ns: [...]
```

If you see UVM output and no "ERROR" messages, setup is successful!

---

## Running Tests

### Basic Test Execution

#### From Command Line

```bash
# Run default test
cd D:/UVM/UVM_CV32E40P/do
vsim -do "run_uvm.do"

# Run specific test
vsim -do "run_uvm.do hpdcache_hit_under_miss_test"

# Run test-specific script
vsim -do "run_uvm_mshr_stress_test.do"
```

#### From ModelSim GUI

```
1. File → Open → D:/UVM/UVM_CV32E40P/do/run_uvm.do
2. Modify settings if needed (edit top lines of script)
3. Tools → Dofile
4. Select run_uvm.do
5. Click "Dofile" button
```

#### Interactive Mode

```tcl
# In ModelSim Tcl console:
cd D:/UVM/UVM_CV32E40P/do
do run_uvm.do

# For a specific test:
do run_uvm.do my_custom_test
```

### Available Test Cases

See `testplan/testplan_UVM_CV32E40P_FINAL.csv` for full test list.

Quick reference (11 built-in tests):

1. `hpdcache_basic_test` - Basic read/write operations
2. `hpdcache_hit_under_miss_test` - Concurrent hit under miss
3. `hpdcache_mshr_stress_test` - 16 simultaneous cache misses
4. `hpdcache_wbuf_test` - Write buffer functionality
5. `hpdcache_cross_cacheline_test` - Cross-cacheline access
6. `hpdcache_hash_collision_test` - Hash table collisions
7. `hpdcache_pref_store_hazard_test` - Prefetch/store hazards
8. `hpdcache_axi_stall_test` - AXI stall handling
9. `hpdcache_domino_mht1_test` - MSHR domino effect 1
10. `hpdcache_domino_mht2_test` - MSHR domino effect 2
11. `hpdcache_rand_test` - Random transactions

---

## Capturing Waveforms

### Enable Waveform Logging

Edit `do/run_uvm.do` and add before `run -all`:

```tcl
log -r *
```

Or use the waveform script:

```tcl
do ../do/waveform.do
```

### View Waveforms

After simulation:

```
1. View → Wave Window (or Ctrl+W)
2. Right-click in Wave window
3. Add Wave... → Signals to add
4. Or: View → Zoom → Fit
```

### Waveform Configuration

File `do/waveform.do` contains pre-configured signal groups:

- Clock / Reset
- Core Requests
- Core Responses
- AXI Read Channel
- AXI Write Channel
- Performance Events

---

## Debugging Failed Simulations

### Common Errors & Solutions

#### Error: "Cannot find module hpdcache"

**Cause:** HPDcache RTL not compiled or incorrect path

**Solution:**
```tcl
# Check that hpdcache RTL is in ModelSim project
# Recompile RTL:
project compileall

# Verify path in run_uvm.do:
set HPDCACHE_INC {D:/my_work/hpdcache/rtl/include}
```

#### Error: "Cannot open file 'hpdcache_config.svh'"

**Cause:** HPDCACHE_INC path points to wrong directory

**Solution:**
```bash
# Verify file exists:
dir D:/my_work/hpdcache/rtl/include/hpdcache_config.svh

# Update path in run_uvm.do to match
```

#### Error: "Undefined package: hpdcache_uvm_pkg"

**Cause:** UVM package not compiled before use

**Solution:**
```tcl
# Ensure compile order in run_uvm.do:
# 1. Interfaces (hpdcache_if.sv)
# 2. UVM package (hpdcache_uvm_pkg.sv)
# 3. Testbench (tb_top.sv)
# Current order should be correct - don't modify
```

#### Warning: "No license for UVM"

**Cause:** ModelSim license doesn't include UVM

**Solution:**
```tcl
# Use built-in UVM (usually works):
# -L mtiUvm flag is already in run_uvm.do

# Alternative: Download UVM from OpenVera
# Add to compile command: -L <UVM_install_dir>
```

#### Simulation Hangs / Timeout

**Cause:** Testbench waiting for timeout, test has infinite loop, or stall

**Solution:**
```tcl
# Press Ctrl+C to interrupt
# Check test timeout settings in hpdcache_base_test.sv
# Verify UVM_TIMEOUT environment variable

# Increase timeout in run_uvm.do:
# Before: run -all
# Try: run 100ms
```

---

## Advanced Configuration

### Environment Variables

Set these for automatic path configuration:

#### Linux/WSL

```bash
export MODELSIM_PATH="/opt/questasim/bin"
export HPDCACHE_INC="$HOME/repos/hpdcache/rtl/include"
export CVA6_INC="$HOME/repos/cva6/core/include"
```

#### Windows (PowerShell)

```powershell
$env:MODELSIM_PATH = "C:\altera\23.3\questa_fse\bin"
$env:HPDCACHE_INC = "D:\my_work\hpdcache\rtl\include"
$env:CVA6_INC = "D:\my_work\cva6\core\include"
```

#### Windows (CMD)

```cmd
set MODELSIM_PATH=C:\altera\23.3\questa_fse\bin
set HPDCACHE_INC=D:\my_work\hpdcache\rtl\include
set CVA6_INC=D:\my_work\cva6\core\include
```

Then in Tcl script, read environment variables:

```tcl
if {[info exists env(HPDCACHE_INC)]} {
    set HPDCACHE_INC $env(HPDCACHE_INC)
}
if {[info exists env(CVA6_INC)]} {
    set CVA6_INC $env(CVA6_INC)
}
```

### Coverage Collection

To generate coverage reports:

```tcl
# Add to run_uvm.do before "run -all":
coverage save -assert -code_all -cumulativedb

# After simulation:
coverage report -cumulativedb
```

### Seed Management

Control test randomness:

```tcl
# Fixed seed (reproducible):
vsim ... -sv_seed 12345 ...

# Random seed (full exploration):
vsim ... -sv_seed random ...

# Query current seed:
# Check simulator output for "Seed = XXXXX"
```

---

## Performance Tuning

### Compilation Optimization

For faster compilation:

```tcl
# In run_uvm.do, modify vlog commands:
vlog -sv -work work \
    +optimize \
    +incdir+... \
    file.sv
```

### Simulation Optimization

For faster simulation:

```tcl
# Reduce visibility (less waveform data):
vsim -novopt ...        # No optimization
vsim -voptargs="+acc=n" # Minimal visibility

# Use elaborated simulation:
vsim -vopt ...  # Optimized elaboration
```

---

## Project Structure Best Practices

### Recommended Folder Layout

```
D:/work/
├── hpdcache/           # External RTL
│   ├── rtl/
│   │   ├── include/    # Header files
│   │   └── *.sv        # RTL modules
│   └── .git/
│
├── cva6/               # External RTL
│   ├── core/
│   │   ├── include/    # Header files
│   │   └── *.sv        # Core modules
│   └── .git/
│
└── UVM_CV32E40P/       # This testbench
    ├── sv/             # UVM packages
    ├── tb/             # Testbench
    ├── do/             # Simulation scripts
    ├── testplan/       # Test documentation
    ├── doc/            # Setup guides
    ├── work/           # Simulation artifacts (generated)
    ├── transcript      # Simulation log (generated)
    └── *.mpf           # ModelSim project (optional)
```

### Version Control

Recommended `.gitignore` for this repository:

```gitignore
# Simulation artifacts
work/
*.vcd
*.wdb
*.ucdb
transcript
vsim.wlf
output.log

# IDE files
.idea/
.vscode/
*.swp

# Temporary files
~$*
*.bak
*.tmp

# Build outputs
build/
dist/
```

---

## Troubleshooting Script Issues

### Script Permissions

If run_uvm.do won't execute:

```bash
# Windows - make sure file is not read-only
right-click run_uvm.do → Properties → uncheck "Read-only"

# Linux/WSL
chmod +x run_uvm.do
chmod 755 do/*.do
```

### Path Separators

On different systems, use correct path format:

```tcl
# Windows (with / or \\):
set TB_DIR {D:/UVM/tb}
# or
set TB_DIR {D:\\UVM\\tb}

# Linux/WSL:
set TB_DIR {/home/user/UVM/tb}

# Relative paths work on all systems:
set TB_DIR {../tb}
```

### Tcl Escaping

If paths have spaces, use braces:

```tcl
# Correct:
set TB_DIR {C:/Program Files/UVM/tb}

# Incorrect:
set TB_DIR C:/Program Files/UVM/tb    # Will fail!
```

---

## Next Steps

1. **Verify Setup:** Run first test to confirm configuration
2. **Explore Tests:** Try different test cases in testplan/
3. **Add Tests:** Use testplan/testplan_UVM_CV32E40P_FINAL.csv to plan new tests
4. **Extend:** Modify agents in sv/ for your specific needs
5. **Port:** Use UVM_REUSABILITY_ASSESSMENT.md to understand reusable components

---

## Support & Documentation

- **Setup Issues:** See "Troubleshooting" section above
- **Test Details:** See `testplan/testplan_UVM_CV32E40P_FINAL.csv`
- **Reusability:** See `testplan/UVM_REUSABILITY_ASSESSMENT.md`
- **UVM Reference:** See `sv/uvm_systemverilog.txt`
- **Main Guide:** See `README.md`

---

**Document Version:** 1.0  
**Last Updated:** 2026-07-30  
**Status:** Ready for deployment
