# cv32e40p_obi_adapter_if.sv - Type & Parameter Fixes

**Date:** 31 July 2026  
**File:** D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv  
**Errors Found:** 5 (grouped into 2 categories)  
**Status:** ✅ FIXED  

---

## Error Summary

### **Error Group 1: Unknown Types hpdcache_req_t & hpdcache_rsp_t (4 errors)**

**Lines affected:** 69, 73, 80, 83

```
** Error: D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv(69): 'hpdcache_req_t' is an unknown type.
** Error: D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv(73): 'hpdcache_rsp_t' is an unknown type.
** Error: D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv(80): 'hpdcache_req_t' is an unknown type.
** Error: D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv(83): 'hpdcache_rsp_t' is an unknown type.
```

### **Error Group 2: Illegal Value for Output Formal (1 error)**

**Line affected:** 230

```
** Error: D:/UVM_CV32E40P/tb/cv32e40p_obi_adapter_if.sv(230): Illegal value (1000) for output formal (timeout_cycles).
           Value must be assignable.
```

---

## Root Cause Analysis

### **Error Group 1: Type Visibility Issue**

**Problem:**
- Interface declares signals using types `hpdcache_req_t` and `hpdcache_rsp_t` (lines 69, 73, 80, 83)
- These types are defined in `hpdcache_uvm_pkg` (imported at line 23)
- But the interface definition (lines 25+) **cannot directly access types from file-level imports**
- Types need to be explicitly imported **inside the interface scope**

**Current code (BROKEN):**
```systemverilog
import hpdcache_uvm_pkg::*;        // Line 23: File-level import

interface cv32e40p_obi_adapter_if (
  input logic clk_i,
  input logic rst_ni
);
  // Interface scope doesn't inherit file-level type imports
  hpdcache_req_t hpd_core_req_o_0;  // ERROR: hpdcache_req_t unknown here!
```

**Why this happens:**
- Interface has its own scope (separate from file scope)
- File-level imports don't automatically cascade into interface scope
- Interface needs explicit `import` statements for types it uses

### **Error Group 2: Task Default Parameter Issue**

**Problem:**
- Line 230 declares: `task wait_obi_rsp(..., int timeout_cycles = 1000);`
- Task parameter uses `int` (output formal parameter type)
- Default value `1000` is not assignable to output parameter
- SystemVerilog requires task parameters with defaults to be `input` type

**Current code (BROKEN):**
```systemverilog
task wait_obi_rsp(bit req_type, 
                  output logic [31:0] rdata, 
                  output logic [2:0] rresp, 
                  int timeout_cycles = 1000);  // ERROR: int parameter can't have default!
```

**Why this happens:**
- Task parameters can be `input`, `output`, or `inout`
- Only `input` parameters can have default values
- `output` formal parameters are assignments, not declarations
- Default `1000` cannot be assigned to an `output` formal

---

## Fixes Applied

### **Fix 1: Add Type Imports Inside Interface Scope**

**File:** D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv  
**Lines:** 30-32 (NEW)

**Before:**
```systemverilog
interface cv32e40p_obi_adapter_if (
  input logic clk_i,
  input logic rst_ni
);

  // ===== OBI INSTRUCTION MASTER INTERFACE =====
```

**After:**
```systemverilog
interface cv32e40p_obi_adapter_if (
  input logic clk_i,
  input logic rst_ni
);

  // Import type definitions from UVM package
  import hpdcache_uvm_pkg::hpdcache_req_t;
  import hpdcache_uvm_pkg::hpdcache_rsp_t;

  // ===== OBI INSTRUCTION MASTER INTERFACE =====
```

**Why this works:**
- Explicit `import` statements inside interface scope
- Types `hpdcache_req_t` and `hpdcache_rsp_t` now available on lines 69, 73, 80, 83
- Interface can now declare signals using these types ✓

**Impact:**
- Resolves all 4 "unknown type" errors
- Types are explicitly available in interface namespace

---

### **Fix 2: Change Task Parameter to Input Type**

**File:** D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv  
**Line:** 234 (was 230, now shifted 4 lines down due to Fix 1)

**Before:**
```systemverilog
task wait_obi_rsp(bit req_type, output logic [31:0] rdata, output logic [2:0] rresp, int timeout_cycles = 1000);
                                                                                   ^^^^ int - output formal!
```

**After:**
```systemverilog
task wait_obi_rsp(bit req_type, output logic [31:0] rdata, output logic [2:0] rresp, input int timeout_cycles = 1000);
                                                                                       ^^^^^ input - can have default!
```

**Why this works:**
- `input` parameters are allowed to have default values
- `timeout_cycles` is used as a read-only counter limit (not written to)
- `input` modifier is semantically correct
- Default value `1000` is now assignable ✓

**Impact:**
- Resolves "Illegal value for output formal" error
- Task signature is semantically correct

---

## Detailed Analysis

### **Scope Hierarchy in SystemVerilog**

```
File Scope
├─ import hpdcache_uvm_pkg::*;  ← Types imported here
├─ interface cv32e40p_obi_adapter_if (...)
│  ├─ Interface Scope (SEPARATE)
│  │  ├─ import hpdcache_uvm_pkg::*;  ← Types must be imported here too!
│  │  └─ logic hpdcache_req_t signal;  ← Now accessible ✓
│  └─ endinterface
└─ class cv32e40p_obi_vif_wrapper
   └─ extends uvm_object; ← Different scope again!
```

**Key Principle:** Each scope needs explicit imports for types it uses. File-level imports don't automatically cascade into nested scopes.

### **Task Parameter Directive Rules**

| Directive | Behavior | Default Value? | Usage |
|-----------|----------|---|---|
| `input` | Read-only parameter | ✅ **YES** | Input arguments |
| `output` | Assignment target | ✗ **NO** | Output return values |
| `inout` | Both read & write | ✗ **NO** | Bidirectional |
| (none) | Defaults to `input` | ✅ **YES** | (if none specified) |

**For timeout_cycles:**
- Used as: `while (cycles < timeout_cycles)` — read-only
- Has default: `= 1000` — needs input directive
- Solution: `input int timeout_cycles = 1000` ✓

---

## Verification

### **Fix 1: Type Availability**

**Before:**
```systemverilog
hpdcache_req_t hpd_core_req_o_0;  // ERROR: type unknown in interface scope
```

**After:**
```systemverilog
// Inside interface scope:
import hpdcache_uvm_pkg::hpdcache_req_t;
hpdcache_req_t hpd_core_req_o_0;  // ✓ Type available, compiles
```

### **Fix 2: Task Parameter Declaration**

**Before:**
```systemverilog
task wait_obi_rsp(..., int timeout_cycles = 1000);  // ERROR: int is output formal
```

**After:**
```systemverilog
task wait_obi_rsp(..., input int timeout_cycles = 1000);  // ✓ input allows default
```

---

## Expected Compilation Results

### **Before Fix:**
```
** Error: (vlog-2163) 'hpdcache_req_t' is an unknown type
** Error: (vlog-2163) 'hpdcache_rsp_t' is an unknown type
** Error: Illegal value (1000) for output formal (timeout_cycles)
Total: 5 compilation errors
```

### **After Fix:**
```
✓ Interface compiles successfully
✓ Types hpdcache_req_t and hpdcache_rsp_t are available
✓ Task parameter timeout_cycles has valid default
Total: 0 compilation errors in cv32e40p_obi_adapter_if.sv
```

---

## Files Modified

**D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv**

| Change | Line | Type | Details |
|--------|------|------|---------|
| Add type imports | 30-32 | ADD | Two import statements for hpdcache_req_t and hpdcache_rsp_t |
| Fix parameter directive | 234 | EDIT | Change `int timeout_cycles` to `input int timeout_cycles` |

---

## Summary

| Aspect | Details |
|--------|---------|
| **Error Type 1** | Unknown types in interface scope |
| **Root Cause 1** | Types imported at file level, not inherited by interface |
| **Fix 1** | Add explicit import statements inside interface |
| **Error Type 2** | Illegal value for output formal parameter |
| **Root Cause 2** | Default values only allowed on input parameters |
| **Fix 2** | Change parameter directive to `input` |
| **Total Errors Fixed** | 5 (4 type errors + 1 parameter error) |
| **Files Modified** | 1 (cv32e40p_obi_adapter_if.sv) |
| **Status** | ✅ FIXED |

---

## Key Learnings

1. **Scope Isolation:** File-level imports don't cascade into interface scopes. Interfaces need explicit imports.

2. **Task Parameters:** Only `input` parameters can have default values. Use `input` for read-only parameters with defaults.

3. **Type Visibility:** When using custom types in interfaces, explicitly import them in the interface scope.

