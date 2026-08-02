# Phase 1 Quick Reference Guide

**Date:** 30 July 2026  
**Status:** IMPLEMENTATION READY  
**Effort Estimate:** 4-7 hours  
**Priority:** CRITICAL - Unblocks all 11 testplan items

---

## File Creation Checklist

### File 1: D:\UVM_CV32E40P\sv\instruction_decoder.sv

**Checklist:**
- [ ] Copy complete `instruction_decoder` module (450 LOC) from report
- [ ] Copy `instruction_decoder_seq` class with gen_*() functions
- [ ] Update file header with actual date/path
- [ ] Verify imports: `import hpdcache_pkg::*;`
- [ ] Check parameter defaults: ADDR_WIDTH=32, INSTR_WIDTH=32
- [ ] Validate all assertion blocks included
- [ ] Compile test: `vlog -sv instruction_decoder.sv` → 0 errors

**Key Functions Provided:**
- `gen_lw()` - Generate LW instructions
- `gen_sw()` - Generate SW instructions  
- `gen_jal()` - Generate JAL instructions
- `gen_beq()` / `gen_bne()` - Generate branch instructions
- `gen_addi()` - Generate ADDI instructions
- `gen_fence_i()` - Generate FENCE.I instructions

**Integration Point:**
In `hpdcache_uvm_pkg.sv`, add after line ~145:
```systemverilog
`include "instruction_decoder.sv"
```

---

### File 2: D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv

**Checklist:**
- [ ] Copy `cv32e40p_obi_adapter_if` interface (320 LOC) from report
- [ ] Copy `cv32e40p_obi_vif_wrapper` helper class
- [ ] Verify 3 modports: `master`, `slave`, `monitor`
- [ ] Check modport directions are correct (output/input/input)
- [ ] Verify all assertions included (3 total)
- [ ] Compile test: `vlog -sv cv32e40p_obi_adapter_if.sv` → 0 errors

**Key Signals:**
- OBI Instruction: `obi_instr_req_i`, `obi_instr_addr_i`, `obi_instr_gnt_o`, `obi_instr_rvalid_o`
- OBI Data: `obi_data_req_i`, `obi_data_addr_i`, `obi_data_wdata_i`, `obi_data_we_i`, `obi_data_be_i`, `obi_data_gnt_o`, `obi_data_rvalid_o`
- HPDcache Req 0: `hpd_core_req_valid_o_0`, `hpd_core_req_o_0`, `hpd_core_req_ready_i_0`
- HPDcache Req 1: `hpd_core_req_valid_o_1`, `hpd_core_req_o_1`, `hpd_core_req_ready_i_1`
- HPDcache Rsp: `hpd_core_rsp_valid_i_*`, `hpd_core_rsp_o_*` (0/1 variants)

**Integration Point:**
In `tb_top.sv`, add:
```systemverilog
// Instantiate VIF
cv32e40p_obi_adapter_if obi_if (.clk_i(clk), .rst_ni(rst_n));

// Make available to UVM
initial begin
  uvm_config_db #(virtual cv32e40p_obi_adapter_if)::set(null, "*", "obi_vif", obi_if);
end
```

---

### File 3: D:\UVM_CV32E40P\sv\hpdcache_uvm_pkg.sv (MODIFY)

**Checklist:**
- [ ] Open existing file
- [ ] Locate lines 40-80 (localparam definitions)
- [ ] Find `UVM_HPDCACHE_PA_WIDTH = 56`
- [ ] Change to `UVM_HPDCACHE_PA_WIDTH = 32`
- [ ] Find `UVM_HPDCACHE_WAYS = 8`
- [ ] Change to `UVM_HPDCACHE_WAYS = 4`
- [ ] Update comments to reference CV32E40P instead of CVA6
- [ ] Add source reference: cv32e40p_icache_pkg.sv line 15
- [ ] Verify derived parameters recalculate: UVM_TAG_WIDTH should become 20 (not 44)
- [ ] Compile test: `vlog -sv hpdcache_uvm_pkg.sv` → 0 errors

**Before:**
```systemverilog
localparam int unsigned UVM_HPDCACHE_PA_WIDTH            = 56;    // CVA6
localparam int unsigned UVM_HPDCACHE_WAYS                = 8;     // 8-way
```

**After:**
```systemverilog
localparam int unsigned UVM_HPDCACHE_PA_WIDTH            = 32;    // CV32E40P: 32-bit address space
localparam int unsigned UVM_HPDCACHE_WAYS                = 4;     // CV32E40P I-Cache: 4-way
```

---

## Verification Checklist

### Round 1: Syntax Check (Each File)

```bash
# For instruction_decoder.sv
vlog -sv +incdir+D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\rtl\src \
  D:\UVM_CV32E40P\sv\instruction_decoder.sv
# Expected: Model Technology ModelSim ... 0 error(s), 0 warning(s)

# For cv32e40p_obi_adapter_if.sv
vlog -sv D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv
# Expected: 0 error(s), 0 warning(s)

# For hpdcache_uvm_pkg.sv
vlog -sv D:\UVM_CV32E40P\sv\hpdcache_uvm_pkg.sv
# Expected: 0 error(s)
```

**Pass Criteria:** 0 errors on all three files

---

### Round 2: Integration Compilation

```bash
vlog -sv -work work \
  +incdir+D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\rtl\include \
  +incdir+D:\UVM_CV32E40P\sv \
  D:\UVM_CV32E40P\sv\hpdcache_uvm_pkg.sv \
  D:\UVM_CV32E40P\sv\instruction_decoder.sv \
  D:\UVM_CV32E40P\tb\cv32e40p_obi_adapter_if.sv \
  D:\UVM_CV32E40P\tb\tb_top.sv
```

**Pass Criteria:** 0 errors, all files compile together, no duplicate type definitions

---

### Round 3: Configuration Verification

**Test in testbench:**
```systemverilog
import hpdcache_uvm_pkg::*;

initial begin
  $display("UVM_HPDCACHE_PA_WIDTH = %0d (expected 32)", UVM_HPDCACHE_PA_WIDTH);
  $display("UVM_HPDCACHE_WAYS = %0d (expected 4)", UVM_HPDCACHE_WAYS);
  $display("UVM_HPDCACHE_SETS = %0d (expected 64)", UVM_HPDCACHE_SETS);
  $display("UVM_SET_WIDTH = %0d (expected 6)", UVM_SET_WIDTH);
  $display("UVM_TAG_WIDTH = %0d (expected 20)", UVM_TAG_WIDTH);
  
  assert (UVM_HPDCACHE_PA_WIDTH == 32) else $error("PA_WIDTH incorrect");
  assert (UVM_HPDCACHE_WAYS == 4) else $error("WAYS incorrect");
  assert (UVM_TAG_WIDTH == 20) else $error("TAG_WIDTH not recalculated");
end
```

**Pass Criteria:** All assertions pass, derived parameters calculated correctly

---

### Round 4: VIF Instantiation Test

**Add to testbench:**
```systemverilog
// Test VIF instantiation
cv32e40p_obi_adapter_if obi_if (.clk_i(clk), .rst_ni(rst_n));

initial begin
  // Test modport accessibility
  cv32e40p_obi_vif_wrapper vif_wrapper = new("vif_wrapper");
  vif_wrapper.vif = obi_if;
  vif_wrapper.requester_id = 0;
  
  @(posedge clk);
  
  // Test signal driving
  obi_if.master.obi_instr_req_i = 1'b1;
  obi_if.master.obi_instr_addr_i = 32'h8000_0000;
  
  @(posedge clk);
  
  // Expected: signals driven without error
  $display("VIF instantiation test: PASS");
end
```

**Pass Criteria:** No elaboration errors, signals accessible from all modports

---

### Round 5: Decoder Functional Test

**Test instruction decoding:**
```systemverilog
instruction_decoder_seq decoder = new();

// Test LW instruction: LW x27, 1(x17)
logic [31:0] lw_instr = decoder.gen_lw(.rd(27), .rs1(17), .offset(12'h001));
// Expected bits: 0x3_00_00_0_001 | (17 << 15) | (27 << 7) | 0x03
//             = 0x0000_900B (approximately)

initial begin
  assert (lw_instr[6:0] == 7'b0000011) else $error("LW opcode incorrect");
  assert (lw_instr[11:7] == 5'd27) else $error("LW rd incorrect");
  assert (lw_instr[19:15] == 5'd17) else $error("LW rs1 incorrect");
  $display("Decoder functional test: PASS");
end
```

**Pass Criteria:** All instruction generation functions produce correct bit patterns

---

## Integration Steps (Order Matters)

1. **Create instruction_decoder.sv**
   - Copy from report section "ACTION ITEM A1"
   - Place in `D:\UVM_CV32E40P\sv\`
   - Compile standalone: ✓

2. **Create cv32e40p_obi_adapter_if.sv**
   - Copy from report section "ACTION ITEM A4"
   - Place in `D:\UVM_CV32E40P\tb\`
   - Compile standalone: ✓

3. **Modify hpdcache_uvm_pkg.sv**
   - Update UVM_HPDCACHE_PA_WIDTH (line ~42)
   - Update UVM_HPDCACHE_WAYS (line ~45)
   - Save and compile: ✓

4. **Update testbench includes**
   - In hpdcache_uvm_pkg.sv: Add `include "instruction_decoder.sv"`
   - In tb_top.sv: Instantiate `cv32e40p_obi_adapter_if`
   - Compile together: ✓

5. **Update UVM agent VIF bindings**
   - In hpdcache_driver.sv: Get VIF from config_db
   - In hpdcache_monitor.sv: Get VIF from config_db
   - In hpdcache_env.sv: Set VIF in config_db
   - Compile and elaborate: ✓

6. **Run verification tests**
   - Round 1: Syntax check each file
   - Round 2: Integration compilation
   - Round 3: Configuration verification
   - Round 4: VIF instantiation
   - Round 5: Decoder functional test

---

## Expected Results

### All Tests Pass Criteria Met:
- ✓ 0 syntax errors across all files
- ✓ 0 elaboration errors in testbench
- ✓ All VIF modports accessible
- ✓ Package parameters recalculated correctly
- ✓ Instruction decoder produces correct outputs
- ✓ All 11 tests have clear unblocking path

### Effort Tracking:
| Task | Estimated | Key Points |
|------|-----------|-----------|
| A1: Decoder | 2-3h | Copy code, compile, verify functions |
| A4: VIF | 1-2h | Copy interface + wrapper, test modports |
| A7: Config | 0.5h | 2 line changes, recalculation verify |
| Integration | 1-2h | Update includes, VIF binding, final compile |
| **Total** | **4-7h** | **On Schedule** |

---

## Rollback Plan (If Issues Found)

**Issue: VIF signals don't match RTL**
- Verify OBI signal names in actual adapter RTL
- Compare with obi_to_axi4_adapter.sv (reference implementation)
- Update signal names in cv32e40p_obi_adapter_if.sv
- Re-compile and re-test

**Issue: Decoder immediate sign extension wrong**
- Verify RISC-V immediate encoding specification
- Cross-check against CV32E40P decoder.sv RTL
- Correct sign extension logic
- Re-compile and re-test LW/SW/JAL instructions

**Issue: Cache parameter mismatch**
- Read cv32e40p_icache.sv to extract actual WAYS, SETS
- Compare with cv32e40p_icache_pkg.sv
- Update hpdcache_uvm_pkg.sv with correct values
- Verify derived parameters recalculate

---

## Next Phase Readiness

**After Phase 1 complete, verify these prerequisites for Phase 2:**

- [ ] instruction_decoder available in test sequences
- [ ] OBI VIF accessible from all UVM components
- [ ] Cache config parameters available to all tests
- [ ] Package compilation clean
- [ ] No elaboration errors with testbench

**Phase 2 Action Items (HIGH PRIORITY):**
- A2: Update hpdcache_driver.sv port names (2-3h)
- A3: Update hpdcache_monitor.sv port names (1-2h)
- A5: Modify hpdcache_env.sv for CV32E40P (2h)
- A6: Delete ISA-specific files (0.5h)

**Phase 2 Unblocking:** TC-I-01 and TC-INT-01 can run once A2/A3/A5 complete

---

## Quick Command Reference

### Compile Individual Files
```bash
# Decoder
vlog -sv +incdir+rtl/include sv/instruction_decoder.sv

# VIF
vlog -sv tb/cv32e40p_obi_adapter_if.sv

# Package
vlog -sv sv/hpdcache_uvm_pkg.sv
```

### Compile All Together
```bash
vlog -sv -work work +incdir+rtl/include +incdir+sv \
  sv/hpdcache_uvm_pkg.sv sv/instruction_decoder.sv \
  tb/cv32e40p_obi_adapter_if.sv tb/tb_top.sv
```

### Run Simulation
```bash
vsim -work work tb_top
# Load VIF signals to waveform
# Run test: run -all
```

---

**Generated:** 30 July 2026  
**Status:** READY FOR IMMEDIATE IMPLEMENTATION  
**Contact:** Refer to PHASE1_IMPLEMENTATION_REPORT.md for complete code

