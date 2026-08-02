# Migration Guide: D:\UVM → D:\UVM_CV32E40P

**Status:** PRIMARY WORKING DIRECTORY MIGRATION  
**Date:** 2026-07-26  
**Scope:** All active CV32E40P UVM verification work moves to D:\UVM_CV32E40P

---

## 📌 KEY CHANGES

### Before (OLD)
```
D:\UVM\                    (mixed files, lots of external deps)
├── sv/                    (UVM packages)
├── tb/                    (testbench)
├── do/                    (scripts with D:\UVM hardcoded paths)
├── testplan/              (test definitions)
├── repo/                  (external RTL - NOT copied)
└── cva6/                  (old CVA6 project - NOT copied)
```

### After (NEW - PRIMARY) ✅
```
D:\UVM_CV32E40P\           (clean, portable, standalone)
├── sv/                    (15 UVM packages)
├── tb/                    (10 testbench files)
├── do/                    (21 scripts - paths ADAPTED)
├── testplan/              (test plans)
├── doc/                   (setup guides)
└── [Root docs]            (README, completion summaries)
```

---

## 🔄 PATH MIGRATION

### Simulation Script Paths

**Old paths (D:\UVM):**
```tcl
set TB_DIR {D:/UVM/tb}
set SV_DIR {D:/UVM/sv}
set HPDCACHE_INC {D:/khoaluantotnghiep/cv-hpdcache-master/rtl/include}
set CVA6_INC {D:/khoaluantotnghiep/cva6-master/core/include}
```

**New paths (D:\UVM_CV32E40P):**
```tcl
set TB_DIR {../tb}              # Relative: UVM_CV32E40P/do/ → ../tb/
set SV_DIR {../sv}              # Relative: UVM_CV32E40P/do/ → ../sv/
set HPDCACHE_INC {../repo/cv-hpdcache-master/rtl/include}
set CVA6_INC {../repo/cva6-master/core/include}
```

### File References

**Old:**
- `+incdir+D:/UVM/tb` → **New:** `+incdir+../tb`
- `+incdir+D:/UVM/sv` → **New:** `+incdir+../sv`
- `$TB_DIR/file.sv` → Works as-is (variable already defined)

---

## 📂 WHAT TO DO

### 1. **Update .do Scripts** (Required)

All `.do` files in `D:\UVM_CV32E40P\do\` have been path-adapted, but verify:

**Check:** `run_uvm.do`, `run_uvm_*_test.do`
```bash
grep -n "D:/" do/*.do        # Should return 0 matches (no hardcoded D:/)
grep -n "\.\./" do/*.do       # Should show relative paths (../tb, ../sv)
```

**If needed, manually fix:**
```tcl
# BEFORE (hardcoded)
set TB_DIR {D:/UVM/tb}

# AFTER (relative)
set TB_DIR {../tb}
```

### 2. **External RTL Repos** (Manual Setup)

Clone to `D:\UVM_CV32E40P\repo\`:
```bash
cd D:\UVM_CV32E40P\repo\

# Clone HPDcache
git clone https://github.com/openhw/cv-hpdcache.git cv-hpdcache-master

# Clone CVA6
git clone https://github.com/openhw/cva6.git cva6-master
```

**Then update .do scripts:**
```tcl
set HPDCACHE_INC {../repo/cv-hpdcache-master/rtl/include}
set CVA6_INC {../repo/cva6-master/core/include}
```

### 3. **ModelSim Project** (New Setup)

**Create ModelSim project in D:\UVM_CV32E40P:**
```bash
cd D:\UVM_CV32E40P
vsim -newproject project

# Add library mappings
vmap work ./work
vmap mtiUvm ./work
```

**Or use the provided script:**
```bash
cd D:\UVM_CV32E40P\do
vsim -do "source ../do/run_uvm.do"
```

### 4. **Verify Paths** (Quick Check)

```bash
# From D:\UVM_CV32E40P\do\ directory:
cd D:\UVM_CV32E40P\do

# Check if relative paths work
ls ../tb              # Should list testbench files
ls ../sv              # Should list sv/ files
cat ../testplan/*.csv # Should show test definitions
```

---

## 🚀 QUICK START

### Run First Test (TC-I-01 - Phase 1 Baseline)

```bash
cd D:\UVM_CV32E40P
vsim -batch -do "source do/run_uvm.do tc_i_01_seq_fetch_test"
```

**Expected output:**
```
UVM_INFO @ 0: [TEST] TC-I-01: Sequential Fetch
...
UVM_INFO @ 5000: [ISA_SCOREBOARD] PASS=8 FAIL=0
UVM_INFO @ 5000: [SB] TEST PASSED!
```

### Run All Phase 1 Tests

```bash
vsim -batch -do "source do/run_final.do"
```

**Expected:**
- TC-I-01: PASS (8 hits)
- TC-I-03: PASS (4 misses)
- TC-INT-01: PASS (32 commits)

---

## 📋 CHECKLIST: MIGRATION COMPLETE

- [ ] **Paths verified** — No D:\UVM hardcoded in do/*.do
- [ ] **Relative paths working** — ../tb, ../sv resolve correctly
- [ ] **External repos cloned** — HPDcache, CVA6 in repo/
- [ ] **ModelSim project created** — vsim can find libraries
- [ ] **Phase 1 tests run** — TC-I-01, TC-I-03, TC-INT-01 PASS
- [ ] **Documentation reviewed** — README.md, SETUP_GUIDE.md read

---

## 📁 FILE LOCATIONS

### New Primary Directory
```
D:\UVM_CV32E40P\
├── sv/              ← UVM packages (read from here now)
├── tb/              ← Testbench code (read from here now)
├── do/              ← Simulation scripts (execute from here)
├── testplan/        ← Test definitions (reference from here)
├── doc/             ← Documentation (read from here)
└── README.md        ← Start here for overview
```

### Old Directory (Reference Only)
```
D:\UVM\             ← REFERENCE ONLY - Do NOT modify
├── FILE_INVENTORY_AND_REUSABILITY.md (reference)
├── SUMMARY_UVM_FINAL.md (reference)
├── QUESTA_25_3_UVM_ANALYSIS.md (reference)
└── repo/           ← External RTL (do not copy)
```

**Note:** Keep D:\UVM as reference archive. All working files now in D:\UVM_CV32E40P.

---

## 🔗 DEPENDENCIES & INTEGRATION

### Within D:\UVM_CV32E40P

All internal dependencies are relative:
- ✅ `sv/` files → import each other (no hardcoded paths)
- ✅ `tb/` files → include `sv/` (via +incdir+../sv)
- ✅ `do/` scripts → reference tb/, sv/ (via ../tb, ../sv)

### External Dependencies

Must be cloned/installed:
- 🔴 HPDcache RTL → D:\UVM_CV32E40P\repo\cv-hpdcache-master\
- 🔴 CVA6 RTL → D:\UVM_CV32E40P\repo\cva6-master\
- 🔴 UVM 1.1d → Questa built-in (mtiUvm library)
- 🔴 QuestaSim 2023.3+ → Already installed (C:\altera\)

---

## ⚠️ CRITICAL WARNINGS

### DO NOT
- ❌ Modify D:\UVM\ files (keep as archive)
- ❌ Mix paths between D:\UVM and D:\UVM_CV32E40P
- ❌ Hardcode D:\ paths in new .do scripts (use relative)
- ❌ Copy files from D:\UVM without path adaptation

### DO
- ✅ Work entirely in D:\UVM_CV32E40P\
- ✅ Use relative paths (../) in all scripts
- ✅ Update external RTL paths after cloning
- ✅ Keep D:\UVM as read-only reference

---

## 📞 TROUBLESHOOTING

### Path Errors in vsim
```
Error: Cannot find file "D:/UVM/tb/tb_top.sv"
```
**Solution:** Edit do/run_uvm.do, replace D:/UVM/ with ../

### Missing testplan files
```
Cannot open: D:/UVM/testplan/testplan_UVM_CV32E40P_FINAL.csv
```
**Solution:** Use ../testplan/testplan_UVM_CV32E40P_FINAL.csv (relative)

### External RTL not found
```
vlog-7 Cannot open include file: cv-hpdcache-master/rtl/include
```
**Solution:** Clone HPDcache to D:\UVM_CV32E40P\repo\ and update HPDCACHE_INC path

### UVM library not found
```
vlog-7 Cannot find package: uvm_pkg
```
**Solution:** Run `vmap mtiUvm ./work` in D:\UVM_CV32E40P

---

## 📝 NEXT PHASE

### Phase 2 Development (Decoder + Tests)

All Phase 2 work happens in D:\UVM_CV32E40P:

```
D:\UVM_CV32E40P\sv\
├── instruction_decoder.sv    ← NEW (implement here)
└── prefetcher_monitor.sv     ← NEW (implement here)

D:\UVM_CV32E40P\do\
└── run_phase2_tests.do       ← NEW (test runners)
```

### Architecture Reference

For understanding architecture:
- Read: `D:\UVM\SUMMARY_UVM_FINAL.md` (in old folder)
- Implement: `D:\UVM_CV32E40P\sv\instruction_decoder.sv` (in new folder)
- Test: Run from `D:\UVM_CV32E40P\do\` (in new folder)

---

## ✅ COMPLETION SUMMARY

| Item | Status | Location |
|------|--------|----------|
| **Primary Working Directory** | ✅ Set | D:\UVM_CV32E40P\ |
| **Paths Adapted** | ✅ Done | All .do scripts relative |
| **Files Copied** | ✅ 56 files | sv/, tb/, do/, testplan/, doc/ |
| **External Repos** | 🔴 Manual | Clone to repo/ subdirectory |
| **Phase 1 Tests** | ✅ Ready | Run from do/run_final.do |
| **Documentation** | ✅ Complete | README.md, SETUP_GUIDE.md |

---

**Migration Status: COMPLETE** ✅

All CV32E40P UVM verification work is now centralized in **D:\UVM_CV32E40P**.

**Start here:** `D:\UVM_CV32E40P\README.md`

**For setup:** `D:\UVM_CV32E40P\doc\SETUP_GUIDE.md`

**Archive reference:** `D:\UVM\` (read-only)

---

**Date:** 2026-07-26  
**Primary Developer:** Huy Nguyen  
**Email:** nguyenhoanghuynt73@gmail.com
