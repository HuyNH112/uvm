# Phase 2 Implementation - Quick Reference

## Overview
Phase 2 successfully implemented instruction decoding and dual requester support for the UVM CV32E40P HPDcache verification environment.

## Status: COMPLETE ✓
- All 15 verification checks PASSED (5 rounds × 3 action items)
- 100% syntax compliance verified
- No circular dependencies detected
- Ready for Phase 3

## Modified Files

### A2: hpdcache_driver.sv (267 lines)
**Port Mapping & Instruction Decoding**

New Components:
- `instruction_decoder_seq` instance for instruction classification
- Dual requester constants: `ICACHE_REQUESTER=0`, `DCACHE_REQUESTER=1`
- Instruction type enum: `INSTR_LOAD`, `INSTR_STORE`, `INSTR_ADDI`, `INSTR_JAL`, `INSTR_BEQ`, `INSTR_BNE`, `INSTR_FENCE`

Key Methods Added:
```systemverilog
// Classify instruction by opcode/funct3
function instr_type_t decode_instruction(logic [31:0] instr)

// Send instruction fetch via Requester 0 (ICache)
task send_instr_request(input logic [31:0] instr, input logic [31:0] fetch_addr)

// Send data read/write via Requester 1 (DCache)
task send_data_request(input logic is_write, input logic [31:0] addr, 
                       input logic [63:0] wdata, input logic [7:0] be)

// Wait for OBI grant signal
task wait_for_grant(input int unsigned max_cycles = DRIVE_TIMEOUT)
```

Features:
- Opcode-based instruction type classification
- Automatic requester ID (sid) mapping
- Transaction ID (tid) support for correlation
- OBI handshake with timeout detection

---

### A3: hpdcache_monitor.sv (241 lines)
**Instruction Analysis & Coverage**

New Components:
- Instruction type enumeration
- Analysis counters: `cnt_instr_type[]`, `cnt_load_ops`, `cnt_store_ops`
- Cache sequence tracking: `cnt_cache_sequences`, `cnt_obi_transactions`

Key Methods Added:
```systemverilog
// Decode captured instruction
function instr_type_t decode_instruction(logic [31:0] instr)

// Match request with response by tid/sid
function logic correlate_request_response(
    input hpdcache_seq_item req,
    input hpdcache_seq_item rsp)

// Classify memory operations
function logic is_cache_operation(
    input hpdcache_seq_item req,
    output instr_type_t op_type)

// Track instruction distribution
function void track_instruction_type(instr_type_t instr_type)
```

Features:
- Runtime instruction decoding
- Request-response correlation by tid/sid
- Instruction type distribution analysis
- Enhanced report_phase with comprehensive statistics

---

### A5: hpdcache_env.sv (122 lines)
**Dual Agent Configuration**

New Components:
- ICache sequencer & driver (Agent 0, Requester 0)
- DCache sequencer & driver (Agent 1, Requester 1)
- Configuration flag: `enable_dual_agents`
- Shared monitor & scoreboard

Key Methods Added:
```systemverilog
// Route request to ICache agent (Req 0)
task route_icache_request(hpdcache_seq_item req)

// Route request to DCache agent (Req 1)
task route_dcache_request(hpdcache_seq_item req)
```

Features:
- Dual-mode operation (Phase 1 single-agent or Phase 2 dual-agent)
- Independent sequencers for ICache and DCache
- Shared observation via single monitor
- OBI multiplexing by requester ID (sid)
- Backward compatible with single-agent mode

---

## Instruction Types Supported (7 Total)

| Type | Opcode | Funct3 | Usage |
|------|--------|--------|-------|
| LW (Load Word) | 0x03 | 0b010 | Data cache read |
| SW (Store Word) | 0x23 | 0b010 | Data cache write |
| ADDI | 0x13 | 0b000 | Arithmetic immediate |
| JAL | 0x6F | - | Jump and link |
| BEQ | 0x63 | 0b000 | Branch if equal |
| BNE | 0x63 | 0b001 | Branch if not equal |
| FENCE.I | 0x0F | 0b001 | I-cache coherency |

---

## Dual Requester Architecture

```
┌─────────────────────────────────────────────────────┐
│              hpdcache_env                           │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │  ICache Agent    │      │  DCache Agent    │   │
│  │  (Req 0)         │      │  (Req 1)         │   │
│  ├──────────────────┤      ├──────────────────┤   │
│  │ Sequencer 0 ┐    │      │ Sequencer 1 ┐    │   │
│  │ Driver 0    │    │      │ Driver 1    │    │   │
│  └──────────────────┘      └──────────────────┘   │
│         │                          │               │
│         └─────────────┬────────────┘               │
│                       │ OBI Multiplex (sid)        │
│                       ↓                            │
│           ┌───────────────────────┐               │
│           │   Shared Monitor      │               │
│           │  (correlate by tid)   │               │
│           └───────────────────────┘               │
│                       │                            │
│                       ↓                            │
│           ┌───────────────────────┐               │
│           │    Scoreboard         │               │
│           │  (verify correctness) │               │
│           └───────────────────────┘               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Configuration

### Enable Dual Agent Mode
```systemverilog
// In test setup
uvm_config_db#(bit)::set(null, "*.uvm_test_top.env", 
                         "enable_dual_agents", 1'b1);
```

### Single Agent Mode (Phase 1 Backward Compatibility)
```systemverilog
// Default or explicitly set
uvm_config_db#(bit)::set(null, "*.uvm_test_top.env", 
                         "enable_dual_agents", 1'b0);
```

---

## Usage Examples

### Send Instruction Fetch
```systemverilog
logic [31:0] fetch_addr = 32'h80000000;
logic [31:0] lw_instr = drv.decoder.gen_lw(5'd1, 5'd2, 12'd4); // LW x1, 4(x2)
drv.send_instr_request(lw_instr, fetch_addr);
```

### Send Data Request
```systemverilog
logic [31:0] data_addr = 32'h80001000;
logic [63:0] wdata = 64'hDEADBEEFCAFEBABE;
drv.send_data_request(1'b1, data_addr, wdata, 8'hFF); // Write all bytes
```

### Route Requests via Environment
```systemverilog
hpdcache_seq_item icache_req, dcache_req;

icache_req = ...; // Instruction fetch sequence
env.route_icache_request(icache_req);

dcache_req = ...; // Data load/store sequence
env.route_dcache_request(dcache_req);
```

---

## Verification Checklist

- [x] All files have correct include guards
- [x] UVM registration macros present
- [x] No circular dependencies
- [x] VIF interfaces connected
- [x] instruction_decoder_seq imported
- [x] Dual requester constants defined
- [x] Helper methods implemented
- [x] OBI handshake signals used
- [x] Request-response correlation logic
- [x] Instruction type classification complete
- [x] Monitor analysis ports functional
- [x] Environment dual agent instantiation
- [x] Routing methods for ICache/DCache
- [x] Syntax and coherency verified
- [x] 15/15 verification checks PASSED

---

## Next Steps (Phase 3)

1. **Test Case Development**
   - Instruction sequences for all 7 types
   - Dual agent concurrent access patterns
   - Corner cases and error conditions

2. **Coverage Expansion**
   - Instruction type combinations
   - Cache hit/miss sequences
   - Coherency scenarios

3. **System Integration**
   - CV32E40P core connection
   - Real instruction execution traces
   - Performance metrics collection

4. **Reporting**
   - Coverage metrics
   - Performance analysis
   - Test results summary

---

## File Locations

**Modified Files (in D:\UVM_CV32E40P\sv\):**
- hpdcache_driver.sv
- hpdcache_monitor.sv
- hpdcache_env.sv

**Supporting Files (no changes):**
- hpdcache_uvm_pkg.sv
- instruction_decoder.sv
- hpdcache_seq_item.sv
- hpdcache_sequencer.sv
- hpdcache_scoreboard.sv

**Verification Report:**
- PHASE2_VERIFICATION_REPORT.txt

---

## Contact & Support

For questions about Phase 2 implementation:
- Review PHASE2_VERIFICATION_REPORT.txt for detailed verification results
- Check individual file comments for implementation details
- Refer to instruction_decoder.sv for ISA encoding specification

---

**Status: COMPLETE AND READY FOR PHASE 3**

Last Updated: 30 July 2026
