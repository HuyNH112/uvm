# Correct Compilation Method - DO NOT Compile Files Individually

**Date:** 31 July 2026  
**Issue:** Running individual `vlog` commands causes errors  
**Root Cause:** Missing UVM package context  
**Solution:** Use `.do` script with proper compilation order  

---

## THE PROBLEM WITH INDIVIDUAL vlog COMMANDS

When you run:
```bash
vlog -work work -vopt -sv -stats=none D:/UVM_CV32E40P/sv/hpdcache_performance_measurement.sv
```

This file is compiled **STANDALONE, WITHOUT:**
- `import uvm_pkg::*;` (UVM package not imported)
- `include "uvm_macros.svh"` (UVM macros not loaded)
- Package scope context

Result:
- `uvm_monitor` - **undefined** (in uvm_pkg)
- `uvm_component_utils` - **undefined** (in uvm_macros.svh)
- `uvm_analysis_imp_decl` - **undefined** (in uvm_macros.svh)

---

## WHY THESE FILES CANNOT BE COMPILED STANDALONE

### File: hpdcache_performance_measurement.sv

Line 7: `class hpdcache_performance_measurement extends uvm_monitor;`

**Problem:** `uvm_monitor` is in `uvm_pkg` package (built-in Questa)
- Not in your D:\UVM_CV32E40P folder
- Only available when uvm_pkg is imported
- Requires: `import uvm_pkg::*;` at package level

**This file can ONLY be compiled when:**
1. Inside hpdcache_uvm_pkg.sv package scope (via `include` directive)
2. OR after hpdcache_uvm_pkg.sv has been compiled (if standalone file imports the package)

**Current status:** Neither condition is met when compiled standalone.

---

### File: hpdcache_coverage.sv

Line 16: `uvm_analysis_imp_decl(_req)`

**Problem:** `uvm_analysis_imp_decl` is a UVM macro in uvm_macros.svh
- Not in your D:\UVM_CV32E40P folder
- Only available when included via `include "uvm_macros.svh"`
- Requires: UVM package context at file level

**This file can ONLY be compiled when:**
1. After hpdcache_uvm_pkg.sv has been compiled
2. With UVM macros already loaded in compile workspace
3. Standalone file must have: `import uvm_pkg::*;` and `include "uvm_macros.svh"`

---

## CORRECT COMPILATION METHOD

### DO NOT RUN individual vlog commands!

```bash
# ✗ WRONG - Compiles without UVM context
vlog -work work -sv hpdcache_performance_measurement.sv
vlog -work work -sv hpdcache_coverage.sv
```

### DO USE the .do script

```bash
# ✓ CORRECT - Compiles with proper order
cd D:/UVM_CV32E40P/project_uvm
source ../do/uvm_FIXED.do
```

OR manually in Questa:

```tcl
# Open Questa project with proper workspace
cd D:/UVM_CV32E40P/project_uvm

# Method 1: Using .do script
do ../do/uvm_FIXED.do

# Method 2: Manual commands (in order)
# Step 1: Compile all RTL (166 files)
vlog -work work -sv <all RTL files>

# Step 2: Compile UVM package ONLY
vlog -work work +acc -sv D:/UVM_CV32E40P/sv/hpdcache_uvm_pkg.sv
# ← This automatically includes and compiles all 9 component files

# Step 3: NOW compile standalone files (after package is available)
vlog -work work -sv D:/UVM_CV32E40P/sv/hpdcache_coverage.sv
vlog -work work -sv D:/UVM_CV32E40P/sv/instruction_decoder.sv
vlog -work work -sv D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv

# Step 4: Compile testbench
vlog -work work -sv D:/UVM_CV32E40P/tb/hw_top.sv
vlog -work work -sv D:/UVM_CV32E40P/tb/tb_top.sv

# Step 5: Compile tests
vlog -work work -sv D:/UVM_CV32E40P/tb/tc_*.sv

# Step 6: Elaborate
elaborates tb_top

# Step 7: Run simulation
vsim -c tb_top +UVM_TESTNAME=tc_i_01_test -do "run -all"
```

---

## COMPILATION WORKSPACE CONTEXT

### BEFORE Step 2 (Package compilation):
```
Compilation workspace:
├─ RTL files compiled ✓
└─ UVM package NOT YET compiled ✗
   → uvm_pkg NOT available
   → uvm_macros.svh NOT loaded
   → Result: hpdcache_coverage.sv → ERROR (uvm_analysis_imp_decl undefined)
```

### AFTER Step 2 (Package compilation):
```
Compilation workspace:
├─ RTL files compiled ✓
├─ UVM package compiled ✓
│  ├─ uvm_pkg imported ✓
│  ├─ uvm_macros.svh loaded ✓
│  └─ All 9 components compiled inside package scope ✓
│
└─ Ready to compile standalone files:
   ✓ hpdcache_coverage.sv (now has macro context)
   ✓ instruction_decoder.sv
   ✓ cv32e40p_obi_adapter_if.sv
```

---

## FILE-BY-FILE COMPILATION STATUS

### Cannot compile STANDALONE (must be inside package):
- ✗ hpdcache_seq_item.sv
- ✗ hpdcache_sequencer.sv
- ✗ hpdcache_driver.sv
- ✗ hpdcache_monitor.sv
- ✗ hpdcache_scoreboard.sv
- ✗ hpdcache_prefetcher_monitor.sv (now fixed with guards removed)
- ✗ hpdcache_performance_measurement.sv (now fixed with guards removed)
- ✗ hpdcache_env.sv

**Reason:** Extend UVM base classes (uvm_sequence_item, uvm_monitor, uvm_driver, etc.) which are undefined outside package scope.

### Can compile STANDALONE (but ONLY after package):
- ⚠ hpdcache_coverage.sv - Uses uvm_analysis_imp_decl macro (needs uvm_pkg context)
- ✓ instruction_decoder.sv - Module, can compile anytime (but semantically after package)
- ⚠ cv32e40p_obi_adapter_if.sv - Uses uvm_object_utils macro (needs uvm_pkg context)

---

## STEP-BY-STEP: HOW TO FIX COMPILATION

### Current Status:
You're running individual `vlog` commands → Errors

### Step 1: Stop running individual vlog commands
Don't compile files one by one. The order and context matter.

### Step 2: Use the .do script
```bash
# In Questa, navigate to project_uvm directory
cd D:/UVM_CV32E40P/project_uvm

# Run the fixed script (compile -all is automatic)
source ../do/uvm_FIXED.do
```

### Step 3: Wait for completion
The script compiles 181 files in the correct order with proper context.

### Step 4: Check results
```
Expected output:
✓ Compilation successful!
✓ No "undefined class" errors
✓ No "undefined macro" errors
```

### Step 5: Elaborate and simulate
```tcl
elaborates tb_top
vsim -c tb_top +UVM_TESTNAME=tc_i_01_test -do "run -all"
```

---

## WHY THE .do SCRIPT WORKS

The `.do` script (uvm_FIXED.do) implements the **correct compilation order:**

```
Compilation Order:
├─ Step 1: Compile 166 RTL files (provides hpdcache_pkg, cv32e40p_pkg, etc.)
├─ Step 2: Compile hpdcache_uvm_pkg.sv ONLY
│         ├─ Package imports uvm_pkg
│         ├─ Package includes uvm_macros.svh
│         └─ Package includes 9 component files (all get context) ✓
├─ Step 3: Compile hpdcache_coverage.sv (now uvm_macros is loaded)
├─ Step 4: Compile instruction_decoder.sv
├─ Step 5: Compile cv32e40p_obi_adapter_if.sv (now uvm_macros is loaded)
├─ Step 6: Compile hw_top.sv (all dependencies ready)
├─ Step 7: Compile tb_top.sv (all dependencies ready)
└─ Step 8: Compile 11 test files (env is defined)

Result: All files have required context at compile time ✓
```

---

## SUMMARY: DO's AND DON'Ts

### ✓ DO:
- ✓ Use the `.do` script for compilation
- ✓ Compile RTL first (hpdcache_pkg, cv32e40p_pkg, etc.)
- ✓ Compile hpdcache_uvm_pkg.sv second
- ✓ Compile standalone files third (after package)
- ✓ Let the script manage order and context

### ✗ DON'T:
- ✗ Run individual `vlog` commands for UVM files
- ✗ Compile hpdcache_performance_measurement.sv standalone
- ✗ Compile hpdcache_coverage.sv standalone (before package)
- ✗ Compile component files separately from package
- ✗ Expect files to work without proper compilation order

---

## COMPILATION COMMAND REFERENCE

### For Each File Type:

**RTL Module:**
```bash
vlog -work work -sv module.sv
# Can compile standalone (no UVM dependencies)
```

**UVM Component (inside package):**
```bash
# WRONG: vlog -work work -sv hpdcache_driver.sv
# RIGHT: Inside hpdcache_uvm_pkg.sv via `include
```

**UVM Standalone (coverage, adapter):**
```bash
# ONLY after package is compiled:
vlog -work work -sv hpdcache_coverage.sv  # After hpdcache_uvm_pkg.sv
vlog -work work -sv cv32e40p_obi_adapter_if.sv  # After hpdcache_uvm_pkg.sv
```

**Test files:**
```bash
# ONLY after all other files:
vlog -work work -sv tc_i_01_test.sv
```

---

## EXPECTED SUCCESS OUTPUT

After running `source ../do/uvm_FIXED.do`:

```
╔═══════════════════════════════════════════════════════════════════╗
║      UVM VERIFICATION FRAMEWORK FOR CV32E40P + L1 CACHE          ║
║      FIXED COMPILATION ORDER - Components in package only        ║
╚═══════════════════════════════════════════════════════════════════╝

=== PHASE 1: INCLUDES & TYPEDEFS ===
=== PHASE 2: CV32E40P CORE RTL ===
=== PHASE 3: I-CACHE ===
... (all phases compile successfully)
=== PHASE 14: UVM TEST SUITE ===

╔═══════════════════════════════════════════════════════════════════╗
║  COMPILATION SETUP SUMMARY (FIXED)                               ║
║  STATUS: ✅ READY FOR COMPILATION & SIMULATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

AUTO-STARTING COMPILATION (compile -all)...
✓ Compilation successful!
   Next: Elaborate the testbench
   elaborates tb_top
   Then: Start simulation with test selection
   vsim -c tb_top +UVM_TESTNAME=tc_i_01_test -do "run -all"
```

---

## NEXT ACTION

1. **Delete all individual `vlog` commands** you've been running
2. **Use the .do script:** `source D:/UVM_CV32E40P/do/uvm_FIXED.do`
3. **Wait for completion**
4. **Run elaboration and simulation**

Do NOT try to compile individual files anymore - the context and order are critical.

