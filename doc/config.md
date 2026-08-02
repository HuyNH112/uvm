# CV32E40P Cache & Memory Configuration

**Date:** 30 July 2026  
**Version:** 1.0  
**Scope:** ICache, DCache (HPDCache), and CV32E40P Integration  

---

## 1. CV32E40P Core Configuration

### Overview
CV32E40P is a 32-bit RISC-V processor (rv32imcb) with configurable caches and memory subsystem.

### Top-Level Parameters
| Parameter | Value | Source |
|-----------|-------|--------|
| **Instruction Address Width** | 32 bits | OBI interface (CV32E40P external) |
| **Data Address Width (OBI)** | 32 bits | OBI load/store interface |
| **Data Width (OBI)** | 32 bits | 1 word per transaction |
| **Byte Enables** | 4 bits | Load/store granularity |
| **Physical Address Width** | 56 bits | Via HPDCache wrapper |

### Core Features
- Configurable FPU (0 = disabled)
- Configurable PULP ISA (conditional)
- Configurable Cluster Support (conditional)
- Configurable Performance Counters (MHPMCOUNTER)

### Reference
- **File:** D:\UVM_CV32E40P\cv32e40p_logic\cv32e40p-master\rtl\cv32e40p_top.sv
- **Lines:** 1–150 (top-level module, parameter definitions)

---

## 2. ICache Configuration

### Cache Hierarchy
- **Type:** Instruction Cache
- **Location:** Integrated in CV32E40P core
- **Purpose:** Cache instruction fetches from OBI interface

### Physical Organization
| Parameter | Value | Calculation |
|-----------|-------|-------------|
| **Number of Sets** | 64 | - |
| **Number of Ways** | 4 | 4-way set-associative |
| **Cache Line Size** | 64 bytes | 8 words × 8 bytes/word |
| **Words per Line** | 4 | (64 bytes) ÷ (16 bytes/word in fetch width) |
| **Word Width** | 64 bits | Internal data path |
| **Total Cache Size** | 16 KB | 64 sets × 4 ways × 64 bytes |

### Address Decomposition (32-bit)
| Field | Width | LSB:MSB | Purpose |
|-------|-------|---------|---------|
| **Offset** | 6 bits | [5:0] | Byte offset within line (log₂(64)) |
| **Index** | 6 bits | [11:6] | Set index (log₂(64)) |
| **Tag** | 20 bits | [31:12] | Cache tag comparison |

### Cache Line Structure
```
64-byte line = 8 words × 8 bytes/word
  Word[0] = 64 bits [63:0]
  Word[1] = 64 bits [127:64]
  ...
  Word[7] = 64 bits [511:448]
```

### Configuration References
- **File 1:** D:\UVM_CV32E40P\cv32e40p_logic\icache-master\cv32e40p_icache_pkg.sv
  - Lines 18–24: Parameter definitions (SETS=64, WAYS=4, CL_WORDS, WORD_WIDTH)
- **File 2:** D:\UVM_CV32E40P\cv32e40p_logic\icache-master\cv32e40p_icache_defines.vh
  - Lines 10–17: Derived width calculations (TAG_WIDTH=20, INDEX_WIDTH=6, OFFSET_WIDTH=6)

---

## 3. DCache (HPDCache) Configuration

### Cache Hierarchy
- **Type:** Data Cache (Level 1)
- **Name:** HPDCache (High-Performance Data Cache)
- **Location:** Separate wrapper module (cv32e40p_dcache_wrapper.sv)
- **Purpose:** Cache data loads and stores from CV32E40P OBI interface
- **Prefetcher:** Domino Prefetcher (trigger-based, pattern history table MHT1/MHT2)

### Physical Organization
| Parameter | Value | Calculation |
|-----------|-------|-------------|
| **Number of Sets** | 64 | - |
| **Number of Ways** | 8 | 8-way set-associative |
| **Cache Line Size** | 64 bytes | 8 words × 8 bytes/word |
| **Words per Line** | 8 | (64 bytes) ÷ (8 bytes/word) |
| **Word Width** | 64 bits | Internal data path (8 bytes) |
| **Total Cache Size** | 32 KB | 64 sets × 8 ways × 64 bytes |

### Address Decomposition (56-bit Physical Address - PA)
| Field | Width | LSB:MSB | Purpose |
|-------|-------|---------|---------|
| **CL_Offset** | 6 bits | [5:0] | Cache line byte offset (log₂(64)) |
| **Set** | 6 bits | [11:6] | Set index (log₂(64)) |
| **Tag** | 44 bits | [55:12] | Physical tag (56 - 6 - 6 = 44) |

**Note:** CV32E40P OBI provides 32-bit address; HPDCache wrapper extends internally to 56-bit PA.

### Cache Line Structure
```
64-byte line = 8 words × 8 bytes/word
  Word[0] = 64 bits [63:0]
  Word[1] = 64 bits [127:64]
  ...
  Word[7] = 64 bits [511:448]
```

### Data Path Dimensions
| Item | Bits | Formula |
|------|------|---------|
| **Request Data Width** | 128 bits | 2 words × 64 bits/word |
| **Request BE Width** | 16 bits | 2 words × (64 bits ÷ 8 bits/byte) |
| **Memory Data Width** | 512 bits | 8 words × 64 bits/word |
| **Memory BE Width** | 64 bits | 8 words × (64 bits ÷ 8 bits/byte) |

### Prefetcher: Domino Pattern
- **Type:** Trigger-based (MHT1/MHT2 pattern history tables)
- **XOR Hash:** For pattern matching
- **Priority Mux:** Prefetch request arbitration
- **Trigger Detector:** Detects access patterns for prefetch trigger
- **History Buffer:** Stores recent address sequences

### Configuration References
- **File 1:** D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\hpdcache_config.svh
  - Lines 1–35: All HPDCache parameter definitions
    - Line 3: PA_WIDTH = 56
    - Line 4: WORD_WIDTH = 64
    - Line 5: SETS = 64
    - Line 6: WAYS = 8
    - Line 7: CL_WORDS = 8
    - Line 8: REQ_WORDS = 2
    - Line 9: REQ_TRANS_ID_WIDTH = 6
    - Line 31: MEM_ADDR_WIDTH = 56
    - Line 33: MEM_DATA_WIDTH = 512

- **File 2:** D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\rtl\cv32e40p_dcache_wrapper.sv
  - Lines 1–50: Wrapper instantiation with parameter mapping

---

## 4. Memory Subsystem (L2/AXI)

### AXI4 Interface (DCache to L2 Memory)
| Parameter | Value | Notes |
|-----------|-------|-------|
| **Address Width** | 56 bits | Physical address (same as HPDCache PA_WIDTH) |
| **Data Width** | 512 bits | (configurable, default 256 bits shown in wrapper) |
| **ID Width** | 8 bits | AXI transaction ID |
| **User Width** | Configurable | Optional AXI user field |

### Request/Response Format
- **Read Request:** AXI ARID, ARADDR[55:0], ARSIZE, ARLEN
- **Write Request:** AWID, AWADDR[55:0], AWSIZE, AWLEN, WDATA[511:0], WSTRB[63:0]
- **Response:** RID, RDATA, RRESP (read); BID, BRESP (write)

### Reference
- **File:** D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\rtl\cv32e40p_dcache_wrapper.sv
  - Lines 30–35: AXI interface parameter mapping

---

## 5. UVM Testbench Configuration Mapping

### CRITICAL FIX REQUIRED
The UVM package currently defines:
```verilog
localparam int unsigned UVM_HPDCACHE_PA_WIDTH = 32;  // WRONG!
```

**Should be:**
```verilog
localparam int unsigned UVM_HPDCACHE_PA_WIDTH = 56;  // Correct (matches RTL)
```

### Width Calculation Impact

**Current (WRONG with PA_WIDTH=32):**
```
UVM_CL_OFFSET_WIDTH = log₂(8 × 64 ÷ 8) = log₂(64) = 6 bits
UVM_SET_WIDTH = log₂(64) = 6 bits
UVM_TAG_WIDTH = 32 - 6 - 6 = 20 bits
```

**Repetition error at line 88 of hpdcache_seq_item.sv:**
```verilog
addr_tag = hpdcache_tag_t'({{(TAG_W-32){1'b0}}, $urandom()});
                             ^^^^^^^^^^^
                             (20-32) = -12 ← NEGATIVE! Integer overflow error
```

**Correct (with PA_WIDTH=56):**
```
UVM_CL_OFFSET_WIDTH = log₂(8 × 64 ÷ 8) = log₂(64) = 6 bits
UVM_SET_WIDTH = log₂(64) = 6 bits
UVM_TAG_WIDTH = 56 - 6 - 6 = 44 bits
```

**Repetition valid at line 88:**
```verilog
addr_tag = hpdcache_tag_t'({{(TAG_W-32){1'b0}}, $urandom()});
                             ^^^^^^^^^^^
                             (44-32) = 12 ✓ Positive, valid repetition
```

### File to Update
- **File:** D:\UVM_CV32E40P\sv\hpdcache_uvm_pkg.sv
- **Line:** 38
- **Change:** `UVM_HPDCACHE_PA_WIDTH = 32` → `UVM_HPDCACHE_PA_WIDTH = 56`

### All Derived Width Calculations (After Fix)
| Localparam | Calculation | Value (bits) | Purpose |
|-----------|-------------|--------------|---------|
| UVM_CL_OFFSET_WIDTH | log₂(8 × 64 ÷ 8) | 6 | Byte offset within cache line |
| UVM_SET_WIDTH | log₂(64) | 6 | Cache set index |
| UVM_TAG_WIDTH | 56 - 6 - 6 | 44 | Physical tag bits |
| UVM_REQ_OFFSET_WIDTH | 6 + 6 | 12 | Set + offset (address decomposition) |
| UVM_REQ_DATA_WIDTH | 2 × 64 | 128 | Request data width |
| UVM_REQ_BE_WIDTH | 2 × (64÷8) | 16 | Request byte enable width |

### Type Aliases (After Fix)
```verilog
typedef logic [43:0]  hpdcache_tag_t;              // 44 bits
typedef logic [11:0]  hpdcache_req_offset_t;       // 12 bits
typedef logic [1:0][63:0] hpdcache_req_data_t;     // 2×64 = 128 bits
typedef logic [1:0][7:0]  hpdcache_req_be_t;       // 2×8 = 16 bits
typedef logic [2:0]   hpdcache_req_sid_t;          // 3 bits (source ID)
typedef logic [5:0]   hpdcache_req_tid_t;          // 6 bits (transaction ID)
typedef logic [55:0]  hpdcache_req_addr_t;         // 56 bits (physical address)
typedef logic [5:0]   hpdcache_set_t;              // 6 bits (cache set)
```

---

## 6. Three-Phase Verification Strategy

### Phase 1: Basic Request/Response Transactions
- **Scope:** Single agent (ICache or DCache alone)
- **Focus:** Request handshake (valid/ready), response correlation by TID
- **Stimulus:** Random LOAD/STORE to cacheable addresses
- **Checker:** Response data matches request (cold misses skip check)
- **Status:** ✅ Implemented (hpdcache_env, hpdcache_driver, hpdcache_monitor, hpdcache_scoreboard)

### Phase 2: Dual Agent + Instruction Decoding
- **Scope:** Concurrent ICache (Requester 0) + DCache (Requester 1)
- **Focus:** Instruction decoder integration, request routing by SID, RVFI commit analysis
- **Stimulus:** Fetch alternating with load/store sequences
- **Checker:** Both agents respond independently; RVFI captures committed instructions
- **Status:** 🔧 In Progress (decoder_seq, perf_monitor integration)

### Phase 3: Prefetcher Validation + Performance Metrics
- **Phase 3A (Prefetcher):** Domino pattern trigger detection
  - Scope: Detect address sequences matching MHT1/MHT2 patterns
  - Focus: Verify prefetch requests initiated on pattern hits
  - Stimulus: Strided/sequential access patterns
  
- **Phase 3B (Performance):** Cache hit/miss rate, stall cycles, prefetch accuracy
  - Scope: Event collection (cache_read_miss, cache_write_miss, prefetch_req, stall)
  - Focus: Performance metrics with and without prefetch
  - Stimulus: Realistic mixed workloads
  
- **Status:** 🔄 To Be Implemented

---

## 7. Configuration Summary Table

| Aspect | ICache | DCache | CV32E40P | Notes |
|--------|--------|--------|----------|-------|
| **Sets** | 64 | 64 | - | Log₂(64) = 6 bits index |
| **Ways** | 4 | 8 | - | 4-way vs 8-way associativity |
| **Line Size** | 64 B | 64 B | - | Same for coherence |
| **Total Size** | 16 KB | 32 KB | - | 4:8 way difference |
| **Address Width (OBI)** | 32 bits | 32 bits | 32 bits | Instruction and data buses |
| **Address Width (Internal)** | 32 bits | 56 bits | 56 bits via cache | PA extension in DCache |
| **Tag Width** | 20 bits | 44 bits | - | 32-(6+6) vs 56-(6+6) |
| **Data Width** | 256 bits (line) | 512 bits (line) | 32 bits (OBI) | Internal vs external |
| **Word Width** | 64 bits | 64 bits | - | Both use 8-byte words |
| **Prefetcher** | None | Domino (MHT) | N/A | Only DCache has prefetch |

---

## 8. Key Files Reference

### Configuration Source Files
1. **CV32E40P Core**
   - D:\UVM_CV32E40P\cv32e40p_logic\cv32e40p-master\rtl\cv32e40p_top.sv

2. **ICache**
   - D:\UVM_CV32E40P\cv32e40p_logic\icache-master\cv32e40p_icache_pkg.sv
   - D:\UVM_CV32E40P\cv32e40p_logic\icache-master\cv32e40p_icache_defines.vh

3. **DCache (HPDCache)**
   - D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\hpdcache_config.svh
   - D:\UVM_CV32E40P\cv32e40p_logic\cv-hpdcache-master\rtl\cv32e40p_dcache_wrapper.sv

### UVM Testbench Configuration
- **Main Package:** D:\UVM_CV32E40P\sv\hpdcache_uvm_pkg.sv
  - **Lines 38–66:** All UVM configuration and derived widths
  - **Action Required:** Fix line 38 (PA_WIDTH = 56)

- **Seq Item:** D:\UVM_CV32E40P\sv\hpdcache_seq_item.sv
  - **Lines 20–29:** Width shortcuts from package
  - **Lines 88, 108:** Array declarations (affected by PA_WIDTH fix)

---

## 9. Verification Checklist

### Configuration Validation
- [ ] UVM_HPDCACHE_PA_WIDTH = 56 (RTL match)
- [ ] UVM_TAG_WIDTH calculated = 44 bits
- [ ] UVM_SET_WIDTH = 6 bits
- [ ] UVM_CL_OFFSET_WIDTH = 6 bits
- [ ] Type aliases match RTL (hpdcache_tag_t = 44 bits)
- [ ] Recompilation: 0 errors, 0 warnings

### Functional Verification
- [ ] Phase 1: Single agent request/response
- [ ] Phase 1: Response correlation by TID
- [ ] Phase 2: Dual agents concurrent operation
- [ ] Phase 2: Request routing by SID (Req0=ICache, Req1=DCache)
- [ ] Phase 2: RVFI instruction capture
- [ ] Phase 3A: Prefetcher pattern detection
- [ ] Phase 3B: Performance event tracking

---

## 10. Important Notes

### Address Width Mismatch (Intentional Design)
- **CV32E40P OBI interface:** 32-bit address (practical limit for embedded systems)
- **HPDCache internal:** 56-bit physical address (supports full address space in testbench)
- **Wrapper conversion:** cv32e40p_dcache_wrapper adapts 32-bit OBI to 56-bit PA for HPDCache
- **UVM model:** Must use 56-bit PA to match DCache RTL behavior

### Cache Line Alignment
- **ICache:** 6-bit offset = 64-byte lines, instruction word-aligned
- **DCache:** 6-bit offset = 64-byte lines, data word-aligned (8 bytes)
- **Both:** Same line size ensures potential I/D coherence at line granularity

### Prefetcher Trigger Conditions
- **Domino Trigger:** Detected when access pattern matches MHT1/MHT2 entry
- **Prefetch Request:** Issued to L2 AXI interface independently of core request
- **Accuracy Metrics:** Monitor coverage (how often trigger matches) and timeliness (latency of prefetch vs actual access)

---

**Document Status:** ✅ Ready for Implementation  
**Next Step:** Apply PA_WIDTH fix and recompile testbench (0 errors expected)
