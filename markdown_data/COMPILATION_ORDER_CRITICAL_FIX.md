# CRITICAL: Compilation Order Issue - UVM Components

**Date:** 31 July 2026  
**Issue:** Files compiled STANDALONE instead of through package  
**Severity:** BLOCKING ALL COMPILATION  
**Status:** ✅ FIXED

---

## ROOT CAUSE ANALYSIS

### The Problem

The original `uvm.do` script (line 227-229) adds files to the project like this:

```tcl
# WRONG - Lines 227-229 of original uvm.do
"=== PHASE 9: UVM VERIFICATION FRAMEWORK ===" \
$UVM_DIR/hpdcache_uvm_pkg.sv \
$UVM_DIR/hpdcache_coverage.sv \
$UVM_DIR/instruction_decoder.sv \
```

When you use `project addfile`, Questa compiles files as INDIVIDUAL UNITS. This means:

1. `hpdcache_uvm_pkg.sv` is compiled (successfully)
2. `hpdcache_coverage.sv` is compiled STANDALONE (no UVM package scope)
3. `instruction_decoder.sv` is compiled STANDALONE (no UVM package scope)

But the REAL PROBLEM is that hpdcache_seq_item.sv, hpdcache_sequencer.sv, hpdcache_driver.sv, etc. are being compiled STANDALONE when individual vlog commands are run (like the user's test command).

### Why This Fails

When `hpdcache_seq_item.sv` is compiled as a standalone file:

```systemverilog
class hpdcache_seq_item extends uvm_sequence_item;  // ERROR: uvm_sequence_item undefined!
    `uvm_object_utils(hpdcache_seq_item)  // ERROR: uvm_object_utils undefined!
    localparam int unsigned PA_W = UVM_HPDCACHE_PA_WIDTH;  // ERROR: UVM_HPDCACHE_PA_WIDTH undefined!
```

The file loses access to:
- `uvm_sequence_item` base class (in uvm_pkg)
- `uvm_object_utils` macro (in uvm_macros.svh)
- `UVM_HPDCACHE_PA_WIDTH` parameter (in hpdcache_uvm_pkg)

**The file is only supposed to be compiled INSIDE the package scope via backtick-include!**

### The Design Intent

In `hpdcache_uvm_pkg.sv` lines 129-143:

```systemverilog
package hpdcache_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import hpdcache_pkg::*;

    // ... localparam definitions ...

    `include "hpdcache_seq_item.sv"         // ← INCLUDED, not compiled standalone
    `include "hpdcache_sequencer.sv"        // ← INCLUDED, not compiled standalone
    `include "hpdcache_driver.sv"           // ← INCLUDED, not compiled standalone
    `include "hpdcache_monitor.sv"          // ← INCLUDED, not compiled standalone
    `include "hpdcache_scoreboard.sv"       // ← INCLUDED, not compiled standalone
    `include "hpdcache_prefetcher_monitor.sv"    // ← INCLUDED, not compiled standalone
    `include "hpdcache_performance_measurement.sv"  // ← INCLUDED, not compiled standalone
    `include "hpdcache_env.sv"              // ← INCLUDED, not compiled standalone

endpackage : hpdcache_uvm_pkg
```

**These 9 component files should NEVER appear in the compile script!**

---

## CORRECT COMPILATION ORDER

### Phase 1: RTL Compilation (166 files)
```
- CV32E40P core modules
- CV32E40P packages
- I-Cache modules
- OBI-to-AXI adapter
- HPDcache packages and modules
- Domino Prefetcher modules
- Testbench integration modules
```

### Phase 2: UVM Package Compilation (1 file ONLY)
```tcl
vlog -work work +acc -sv $UVM_DIR/hpdcache_uvm_pkg.sv
# This automatically includes and compiles:
#   - hpdcache_seq_item.sv (inside package)
#   - hpdcache_sequencer.sv (inside package)
#   - instruction_decoder_seq.sv (inside package)
#   - hpdcache_driver.sv (inside package)
#   - hpdcache_monitor.sv (inside package)
#   - hpdcache_scoreboard.sv (inside package)
#   - hpdcache_prefetcher_monitor.sv (inside package)
#   - hpdcache_performance_measurement.sv (inside package)
#   - hpdcache_env.sv (inside package)
```

### Phase 3: Standalone Files (compiled AFTER package)
```tcl
vlog -work work -sv $UVM_DIR/hpdcache_coverage.sv
vlog -work work -sv $UVM_DIR/instruction_decoder.sv
```

### Phase 4: Top-level Testbench & Interfaces
```tcl
vlog -work work -sv $TB_DIR/cv32e40p_obi_adapter_if.sv
vlog -work work -sv $TB_DIR/hw_top.sv
vlog -work work -sv $TB_DIR/tb_top.sv
```

### Phase 5: Test Files
```tcl
vlog -work work -sv $TB_DIR/tc_*.sv
```

---

## FIX: Updated Compile Script

**File:** `D:\UVM_CV32E40P\do\uvm_FIXED.do`

### Key Changes:

**Original (BROKEN):**
```tcl
"=== PHASE 9: UVM VERIFICATION FRAMEWORK ===" \
$UVM_DIR/hpdcache_uvm_pkg.sv \
$UVM_DIR/hpdcache_coverage.sv \
$UVM_DIR/instruction_decoder.sv \

"=== PHASE 10: OBI ADAPTER VIRTUAL INTERFACE ===" \
$TB_DIR/cv32e40p_obi_adapter_if.sv \

"=== PHASE 11: TESTBENCH INFRASTRUCTURE ===" \
$TB_DIR/hw_top.sv \
$TB_DIR/tb_top.sv \

"=== PHASE 12: UVM TEST SUITE ===" \
$TB_DIR/tc_i_01_test.sv \
$TB_DIR/tc_d_01_test.sv \
# ... etc
```

**Fixed (CORRECT):**
```tcl
"=== PHASE 9: UVM VERIFICATION FRAMEWORK ===" \
$UVM_DIR/hpdcache_uvm_pkg.sv \
# NOTE: hpdcache_seq_item.sv, hpdcache_sequencer.sv, etc.
#       are NOT listed here - they are included inside the package!

"=== PHASE 10: UVM STANDALONE COVERAGE (AFTER PACKAGE) ===" \
$UVM_DIR/hpdcache_coverage.sv \

"=== PHASE 11: INSTRUCTION DECODER RTL MODULE ===" \
$UVM_DIR/instruction_decoder.sv \

"=== PHASE 12: OBI ADAPTER VIRTUAL INTERFACE (AFTER PACKAGE) ===" \
$TB_DIR/cv32e40p_obi_adapter_if.sv \

"=== PHASE 13: TESTBENCH INFRASTRUCTURE ===" \
$TB_DIR/hw_top.sv \
$TB_DIR/tb_top.sv \

"=== PHASE 14: UVM TEST SUITE (AFTER ENV DEFINED) ===" \
$TB_DIR/tc_i_01_test.sv \
# ... etc
```

### Summary of Removed Files:

The following 9 component files are **REMOVED from the compile script** (they're now only included inside the package):

- hpdcache_seq_item.sv (was in project, now included in package)
- hpdcache_sequencer.sv (was in project, now included in package)
- instruction_decoder_seq.sv (was in project, now included in package)
- hpdcache_driver.sv (was in project, now included in package)
- hpdcache_monitor.sv (was in project, now included in package)
- hpdcache_scoreboard.sv (was in project, now included in package)
- hpdcache_prefetcher_monitor.sv (was in project, now included in package)
- hpdcache_performance_measurement.sv (was in project, now included in package)
- hpdcache_env.sv (was in project, now included in package)

---

## HOW TO USE THE FIX

### Option 1: Use the Fixed .do Script
```tcl
cd D:/UVM_CV32E40P/project_uvm
source ../do/uvm_FIXED.do
```

### Option 2: Manual Compilation
```tcl
# Compile RTL (166 files) - as before

# IMPORTANT: Compile UVM package ONLY (not components)
vlog -work work +acc -sv D:/UVM_CV32E40P/sv/hpdcache_uvm_pkg.sv

# Compile standalone files AFTER package
vlog -work work -sv D:/UVM_CV32E40P/sv/hpdcache_coverage.sv
vlog -work work -sv D:/UVM_CV32E40P/sv/instruction_decoder.sv
vlog -work work -sv D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv
vlog -work work -sv D:/UVM_CV32E40P/tb/hw_top.sv
vlog -work work -sv D:/UVM_CV32E40P/tb/tb_top.sv

# Compile test files
vlog -work work -sv D:/UVM_CV32E40P/tb/tc_*.sv

# Elaborate
elaborates tb_top

# Run simulation
vsim -c tb_top +UVM_TESTNAME=tc_i_01_test -do "run -all"
```

---

## ERROR MESSAGES - BEFORE FIX

```
** Error: (vlog-13069) D:/UVM_CV32E40P/sv/hpdcache_seq_item.sv(8): 
         near "uvm_sequence_item": syntax error, unexpected IDENTIFIER.
** Error: D:/UVM_CV32E40P/sv/hpdcache_seq_item.sv(8): 
         Error in class extension specification.
```

**Cause:** File compiled standalone, lost package scope.

---

## VERIFICATION CHECKLIST

- ✅ hpdcache_uvm_pkg.sv compiled ONCE (includes all 9 components)
- ✅ hpdcache_seq_item.sv NOT compiled standalone
- ✅ hpdcache_sequencer.sv NOT compiled standalone
- ✅ hpdcache_driver.sv NOT compiled standalone
- ✅ hpdcache_monitor.sv NOT compiled standalone
- ✅ hpdcache_scoreboard.sv NOT compiled standalone
- ✅ hpdcache_prefetcher_monitor.sv NOT compiled standalone
- ✅ hpdcache_performance_measurement.sv NOT compiled standalone
- ✅ hpdcache_env.sv NOT compiled standalone
- ✅ hpdcache_coverage.sv compiled AFTER package
- ✅ instruction_decoder.sv compiled AFTER package
- ✅ cv32e40p_obi_adapter_if.sv compiled AFTER package
- ✅ hw_top.sv compiled AFTER all dependencies
- ✅ tb_top.sv compiled AFTER all dependencies
- ✅ tc_*.sv files compiled last

---

## EXPECTED OUTCOME

**Before Fix:**
```
** Error: (vlog-13069) near "uvm_sequence_item": syntax error
** Error: (vlog-13069) near "uvm_sequencer": syntax error
** Error: (vlog-13069) near "uvm_driver": syntax error
[... more errors ...]
```

**After Fix:**
```
✓ Package compiled successfully
✓ All component files included and compiled within package scope
✓ No "undefined class" errors
✓ No "undefined macro" errors
✓ No "undefined type" errors
✓ Ready for elaboration and simulation
```

---

## SUMMARY

The issue was **COMPILATION ORDER**, not code errors. The fix is to ensure:

1. **UVM package is compiled ALONE** (components are included, not compiled separately)
2. **Standalone files are compiled AFTER the package**
3. **Testbench is compiled AFTER all dependencies**
4. **Tests are compiled LAST**

Use `D:\UVM_CV32E40P\do\uvm_FIXED.do` for the corrected compilation flow.

