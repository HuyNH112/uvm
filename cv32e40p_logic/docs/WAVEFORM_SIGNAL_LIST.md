# OBI-to-AXI4 Adapter Waveform Trace Signal List

**Mục đích:** Danh sách chi tiết các signal cần trace để xác nhận adapter hoạt động chính xác.  
**File:** `int_full_integration.sv`  
**Testbench:** `int_full_integration_tb`  
**Date:** 30 July 2026

---

## I. CLOCK & RESET (Infrastructure)

| Signal | Width | Direction | Purpose |
|--------|-------|-----------|---------|
| `clk_i` | 1 | In | Master clock (10ns period = 100 MHz) |
| `rst_ni` | 1 | In | Active-low reset |

**Observation Points:**
- Reset released @ cycle 5 (50ns)
- Clock runs until $finish @ 575ns (57.5 cycles)

---

## II. OBI SLAVE INTERFACE (from CPU)

### A. Instruction Memory Path

| Signal | Width | Direction | Test Affected | Verification |
|--------|-------|-----------|----------------|---------------|
| `obi_instr_req` | 1 | In | TEST 1, 4 | Pulse width = 1 cycle (asserted then deasserted) |
| `obi_instr_gnt` | 1 | Out | TEST 1, 4 | Must pulse high when adapter accepts |
| `obi_instr_addr[31:0]` | 32 | In | TEST 1, 4 | Valid only when `req=1 && gnt=1` (handshake) |
| `obi_instr_rvalid` | 1 | Out | TEST 1, 4 | Pulse high after ~5-cycle latency from grant |
| `obi_instr_rdata[31:0]` | 32 | Out | TEST 1, 4 | Should contain response data (echoes address in testbench) |

**Key Traces:**
- Verify `req` and `gnt` coincide on same cycle → **handshake timing**
- Check `rvalid` pulses exactly 5 cycles after grant → **latency**
- Inspect `rdata` contents → **data path correctness**

**Test 1 Signature:**
```
Cycle 7-8:   instr_req → instr_gnt (handshake)
Cycle 13:    instr_rvalid pulses (5 cycles later)
```

**Test 4 Signature (Priority):**
```
Cycle 35-36: Both instr_req + data_req high
Cycle 36:    instr_gnt=1, data_gnt=0 (instr priority)
Cycle 44:    instr_rvalid pulses
```

---

### B. Data Memory Path

| Signal | Width | Direction | Test Affected | Verification |
|--------|-------|-----------|----------------|---------------|
| `obi_data_req` | 1 | In | TEST 2, 3, 4, 5 | Pulse width = 1 cycle |
| `obi_data_gnt` | 1 | Out | TEST 2, 3, 4, 5 | Pulses high when accepted |
| `obi_data_addr[31:0]` | 32 | In | TEST 2, 3, 4, 5 | Valid during handshake |
| `obi_data_we` | 1 | In | TEST 2, 5 (write); TEST 3, 4 (read) | **Write=1** → AW/W/B path; **Write=0** → AR/R path |
| `obi_data_be[3:0]` | 4 | In | TEST 2, 5 | Byte enable (only for writes) |
| `obi_data_wdata[31:0]` | 32 | In | TEST 2, 5 | Write data (only valid when we=1) |
| `obi_data_rvalid` | 1 | Out | TEST 2, 3, 5 | Pulse high when response ready |
| `obi_data_rdata[31:0]` | 32 | Out | TEST 3 (read); TEST 2 (write ack) | Read data or write acknowledgment |

**Key Traces:**
- **TEST 2 (Write):** Trace `we`, `be`, `wdata` → should translate to AXI4 W/B path
- **TEST 3 (Read):** Trace `we=0` → should use AR/R path
- **TEST 5 (BE expansion):** `be[3:0]` should map to `axi_wstrb[7:0]` correctly

**Test 2 Signature:**
```
Cycle 17-18: data_req=1, we=1, be=1111, wdata=0xCAFEBABE
Cycle 18:    data_gnt=1 (accepted)
Cycle 21:    data_rvalid=1 (write response via B channel)
```

**Test 3 Signature:**
```
Cycle 25-26: data_req=1, we=0 (read request)
Cycle 26:    data_gnt=1 (accepted)
Cycle 31:    data_rvalid=1 (read response)
```

---

## III. AXI4 MASTER INTERFACE (to HPDcache)

### A. Read Address Channel (AR)

| Signal | Width | Direction | From Adapter | Verification |
|--------|-------|-----------|--------------|---------------|
| `axi_arvalid` | 1 | Out | m_arvalid_o | Asserted when instruction OR (data read without instruction priority) |
| `axi_arready` | 1 | In | (Responder) | Testbench always = 1 |
| `axi_araddr[31:0]` | 32 | Out | m_araddr_o | Address = instruction address OR data read address |
| `axi_arsize[2:0]` | 3 | Out | m_arsize_o | Should be 3'b011 (64-bit = 8 bytes) |
| `axi_arburst[1:0]` | 2 | Out | m_arburst_o | Should be 2'b01 (INCR - incrementing burst) |
| `axi_arlen[7:0]` | 8 | Out | m_arlen_o | Should be 8'h0 (single beat) |
| `axi_arid[3:0]` | 4 | Out | m_arid_o | **ID=0 for instruction**, **ID=1 for data read** |
| `axi_arlock` | 1 | Out | m_arlock_o | Should be 1'b0 (no exclusive lock) |
| `axi_arcache[3:0]` | 4 | Out | m_arcache_o | Should be 4'b0 (non-cacheable) |
| `axi_arprot[2:0]` | 3 | Out | m_arprot_o | Should be 3'b000 (unprivileged, secure, data) |

**Key Traces:**
- **ID Demux:** Verify `arid=0` for instruction, `arid=1` for data read
- **Size/Burst:** Confirm fixed to SIZE_64BIT (3'b011) and INCR (2'b01)
- **Single-beat:** Check `arlen=0` (no burst, single transfer)
- **Address validity:** Only appears when corresponding OBI request is active

**Test 1 Signature (Instruction Fetch):**
```
Cycle 8:  arvalid=1, araddr=0x80000000, arid=0, arsize=3, arburst=1, arlen=0
```

**Test 4 Signature (Instruction Priority):**
```
Cycle 36: arvalid=1, araddr=0x80004000, arid=0 (instr gets priority)
          → data read request blocked (instr_req active)
Cycle 45: (after instr completes) arvalid=1, araddr=0x80005000, arid=1
```

---

### B. Read Data Channel (R)

| Signal | Width | Direction | From Responder | Verification |
|--------|-------|-----------|-----------------|---------------|
| `axi_rvalid` | 1 | In | (Responder) | Pulses high 5 cycles after AR handshake |
| `axi_rready` | 1 | Out | m_rready_o | Should be 1'b1 (always ready, no backpressure) |
| `axi_rdata[63:0]` | 64 | In | (Responder) | 64-bit data: {32'hDEADBEEF, araddr_q} in testbench |
| `axi_rresp[1:0]` | 2 | In | (Responder) | Should be 2'b00 (OKAY response) |
| `axi_rlast` | 1 | In | (Responder) | Should be 1'b1 (single beat, always last) |
| `axi_rid[3:0]` | 4 | In | (Responder) | Echoes `arid` from AR channel → ID-based demux |

**Key Traces:**
- **Latency:** Measure time from AR valid to R valid = 5 cycles (testbench design)
- **ID matching:** `rid` should match `arid` from corresponding AR request
- **Data contents:** 64-bit data echoes address (testbench pattern)
- **Handshake:** `rready` always high (CPU never blocks)

**Test 1 Signature:**
```
Cycle 8:  AR: arvalid=1, arid=0
Cycle 13: R:  rvalid=1, rid=0, rdata=0xDEADBEEF80000000
```

---

### C. Write Address Channel (AW)

| Signal | Width | Direction | From Adapter | Verification |
|--------|-------|-----------|--------------|---------------|
| `axi_awvalid` | 1 | Out | m_awvalid_o | Asserted when `data_req & data_we` |
| `axi_awready` | 1 | In | (Responder) | Testbench always = 1 |
| `axi_awaddr[31:0]` | 32 | Out | m_awaddr_o | Data write address |
| `axi_awsize[2:0]` | 3 | Out | m_awsize_o | Should be 3'b011 (64-bit) |
| `axi_awburst[1:0]` | 2 | Out | m_awburst_o | Should be 2'b01 (INCR) |
| `axi_awlen[7:0]` | 8 | Out | m_awlen_o | Should be 8'h0 (single beat) |
| `axi_awid[3:0]` | 4 | Out | m_awid_o | Should always be 4'h1 (write ID = 1) |
| `axi_awlock` | 1 | Out | m_awlock_o | Should be 1'b0 |
| `axi_awcache[3:0]` | 4 | Out | m_awcache_o | Should be 4'b0 |
| `axi_awprot[2:0]` | 3 | Out | m_awprot_o | Should be 3'b000 |
| `axi_awatop[5:0]` | 6 | Out | m_awatop_o | Should be 6'b0 (no atomic operations) |

**Key Traces:**
- **Fixed ID:** `awid` always = 1 (distinct from instruction ID=0)
- **Configuration:** Verify size/burst/len same as AR channel
- **Activation:** Only valid when both `data_req=1 AND data_we=1`

**Test 2 Signature:**
```
Cycle 18: awvalid=1, awaddr=0x80001000, awid=1, awsize=3, awburst=1, awlen=0
```

---

### D. Write Data Channel (W)

| Signal | Width | Direction | From Adapter | Verification |
|--------|-------|-----------|--------------|---------------|
| `axi_wvalid` | 1 | Out | m_wvalid_o | Asserted when `data_req & data_we` |
| `axi_wready` | 1 | In | (Responder) | Testbench always = 1 |
| `axi_wdata[63:0]` | 64 | Out | m_wdata_o | **DATA WIDTH CONVERSION:** padded from 32-bit to 64-bit |
| `axi_wstrb[7:0]` | 8 | Out | m_wstrb_o | **BYTE ENABLE EXPANSION:** {4'h0, obi_data_be[3:0]} |
| `axi_wlast` | 1 | Out | m_wlast_o | Should be 1'b1 (single beat, always last) |

**Key Traces - CRITICAL FOR DATA WIDTH VERIFICATION:**
- **Padding:** `wdata[63:32]` should be 0, `wdata[31:0]` = OBI data
- **Strobe:** `wstrb[7:4]` should be 0, `wstrb[3:0]` = OBI byte enable
  - Example: `be=4'b1100` → `wstrb=8'b00001100`
  - Example: `be=4'b1111` → `wstrb=8'b00001111`

**Test 2 Signature:**
```
Cycle 18: wvalid=1, wdata=0x00000000CAFEBABE, wstrb=8'b00001111, wlast=1
```

**Test 5 Signature (BE Expansion):**
```
Cycle 55: wvalid=1, wdata=0x00000000DEADBEEF, wstrb=8'b00001100, wlast=1
          Verify: be[1100] → strb[00001100] ✓
```

---

### E. Write Response Channel (B)

| Signal | Width | Direction | From Responder | Verification |
|--------|-------|-----------|-----------------|---------------|
| `axi_bvalid` | 1 | In | (Responder) | Pulses high 3 cycles after AW+W handshake |
| `axi_bready` | 1 | Out | m_bready_o | Should be 1'b1 (always ready) |
| `axi_bresp[1:0]` | 2 | In | (Responder) | Should be 2'b00 (OKAY) |
| `axi_bid[3:0]` | 4 | In | (Responder) | Should echo `awid=4'h1` (write ID) |

**Key Traces:**
- **Latency:** Time from AW+W valid to B valid = 3 cycles (testbench design)
- **ID matching:** `bid` should be 1 (matches `awid`)
- **Ready signal:** `bready` always high (no CPU backpressure)

**Test 2 Signature:**
```
Cycle 18: AW+W: awvalid=1, wvalid=1
Cycle 21: B:    bvalid=1, bid=1, bresp=0 (OKAY)
```

---

## IV. INTERNAL ADAPTER LOGIC (Optional, Advanced Traces)

These signals are **inside the adapter** but useful for debugging protocol compliance:

| Signal | Module | Width | Purpose |
|--------|--------|-------|---------|
| `ar_valid` | AR mux | 1 | Combinational: instr_req OR (data_req & ~data_we) |
| `ar_addr` | AR mux | 32 | Combinational: instr_addr if instr_req, else data_addr |
| `ar_is_instr` | AR mux | 1 | Combinational: determines arid (0=instr, 1=data) |
| `wstrb_expanded` | W path | 8 | Combinational: byte enable expansion {4'h0, data_be} |

**Observation:** These reflect priority logic and data width conversion calculations.

---

## V. WAVEFORM VIEWER COMMANDS (GTKWave/ModelSim)

### Quick Trace (Minimal)
```tcl
add wave -position insertpoint sim:/int_full_integration_tb/clk_i
add wave -position insertpoint sim:/int_full_integration_tb/rst_ni
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_req
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_gnt
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_addr
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_rvalid
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_rdata
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_req
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_gnt
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_addr
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_we
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_be
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_wdata
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_rvalid
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_rdata
```

### Complete Trace (All AXI4 Channels)
```tcl
# OBI paths (15 signals)
add wave -noupdate -group "OBI Instr" sim:/int_full_integration_tb/obi_instr_*
add wave -noupdate -group "OBI Data" sim:/int_full_integration_tb/obi_data_*

# AXI4 channels (43 signals)
add wave -noupdate -group "AXI4 AR" sim:/int_full_integration_tb/axi_ar*
add wave -noupdate -group "AXI4 R" sim:/int_full_integration_tb/axi_r*
add wave -noupdate -group "AXI4 AW" sim:/int_full_integration_tb/axi_aw*
add wave -noupdate -group "AXI4 W" sim:/int_full_integration_tb/axi_w*
add wave -noupdate -group "AXI4 B" sim:/int_full_integration_tb/axi_b*

# Clock & reset
add wave -noupdate -group "Control" sim:/int_full_integration_tb/clk_i
add wave -noupdate -group "Control" sim:/int_full_integration_tb/rst_ni
```

### ModelSim `.do` file
```tcl
# Open waveform
view wave

# Add OBI signals
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_req
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_gnt
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_addr
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_rvalid
add wave -position insertpoint sim:/int_full_integration_tb/obi_instr_rdata
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_req
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_gnt
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_addr
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_we
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_be
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_wdata
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_rvalid
add wave -position insertpoint sim:/int_full_integration_tb/obi_data_rdata

# Add AXI4 AR channel
add wave -position insertpoint sim:/int_full_integration_tb/axi_arvalid
add wave -position insertpoint sim:/int_full_integration_tb/axi_arready
add wave -position insertpoint sim:/int_full_integration_tb/axi_araddr
add wave -position insertpoint sim:/int_full_integration_tb/axi_arsize
add wave -position insertpoint sim:/int_full_integration_tb/axi_arburst
add wave -position insertpoint sim:/int_full_integration_tb/axi_arlen
add wave -position insertpoint sim:/int_full_integration_tb/axi_arid

# Add AXI4 R channel
add wave -position insertpoint sim:/int_full_integration_tb/axi_rvalid
add wave -position insertpoint sim:/int_full_integration_tb/axi_rready
add wave -position insertpoint sim:/int_full_integration_tb/axi_rdata
add wave -position insertpoint sim:/int_full_integration_tb/axi_rresp
add wave -position insertpoint sim:/int_full_integration_tb/axi_rlast
add wave -position insertpoint sim:/int_full_integration_tb/axi_rid

# Add AXI4 AW channel
add wave -position insertpoint sim:/int_full_integration_tb/axi_awvalid
add wave -position insertpoint sim:/int_full_integration_tb/axi_awready
add wave -position insertpoint sim:/int_full_integration_tb/axi_awaddr
add wave -position insertpoint sim:/int_full_integration_tb/axi_awsize
add wave -position insertpoint sim:/int_full_integration_tb/axi_awburst
add wave -position insertpoint sim:/int_full_integration_tb/axi_awlen
add wave -position insertpoint sim:/int_full_integration_tb/axi_awid

# Add AXI4 W channel
add wave -position insertpoint sim:/int_full_integration_tb/axi_wvalid
add wave -position insertpoint sim:/int_full_integration_tb/axi_wready
add wave -position insertpoint sim:/int_full_integration_tb/axi_wdata
add wave -position insertpoint sim:/int_full_integration_tb/axi_wstrb
add wave -position insertpoint sim:/int_full_integration_tb/axi_wlast

# Add AXI4 B channel
add wave -position insertpoint sim:/int_full_integration_tb/axi_bvalid
add wave -position insertpoint sim:/int_full_integration_tb/axi_bready
add wave -position insertpoint sim:/int_full_integration_tb/axi_bresp
add wave -position insertpoint sim:/int_full_integration_tb/axi_bid

# Add clock & reset
add wave -position insertpoint sim:/int_full_integration_tb/clk_i
add wave -position insertpoint sim:/int_full_integration_tb/rst_ni

# Run to completion
run -all

# Save waveform
write format vcd -output int_full_integration.vcd
```

---

## VI. KEY VERIFICATION POINTS BY TEST

### TEST 1: Instruction Fetch
```
✓ obi_instr_req → obi_instr_gnt (handshake)
✓ axi_arvalid asserts with arid=0
✓ 5-cycle latency to axi_rvalid
✓ obi_instr_rvalid pulses at end
✓ Data contents valid (axi_rdata → obi_instr_rdata)
```

### TEST 2: Data Write
```
✓ obi_data_req → obi_data_gnt (handshake)
✓ obi_data_we=1 enables AW+W path
✓ axi_awvalid + axi_wvalid (both on same cycle)
✓ awid=1, wdata padded, wstrb=8'hFF for be=4'hF
✓ 3-cycle latency to axi_bvalid
✓ obi_data_rvalid pulses (B channel response)
```

### TEST 3: Data Read
```
✓ obi_data_req → obi_data_gnt (handshake)
✓ obi_data_we=0 enables AR path
✓ axi_arvalid with arid=1
✓ 5-cycle latency to axi_rvalid
✓ obi_data_rvalid pulses with valid rdata
```

### TEST 4: Instruction Priority
```
✓ Both obi_instr_req and obi_data_req asserted
✓ obi_instr_gnt=1, obi_data_gnt=0 (instr priority)
✓ Only axi_arvalid for instruction (arid=0)
✓ Data request blocked until instr completes
✓ After instr response, data request succeeds
```

### TEST 5: Data Width Conversion
```
✓ obi_data_be[3:0] = 4'b1100 input
✓ axi_wstrb[7:0] = 8'b00001100 output
✓ obi_data_wdata[31:0] = 32'hDEADBEEF input
✓ axi_wdata[63:32] = 32'h0 (padding), axi_wdata[31:0] = data
✓ All byte enables correctly mapped
```

---

## VII. SUMMARY: CRITICAL SIGNAL GROUPS

**Must trace for production verification:**

1. **OBI Handshakes (request/grant pairs)**
   - `obi_instr_req/gnt`, `obi_data_req/gnt`
   
2. **AXI4 ID-based Demux**
   - `axi_arid[3:0]`, `axi_rid[3:0]`, `axi_awid[3:0]`, `axi_bid[3:0]`
   
3. **Data Width Conversion**
   - `obi_data_wdata[31:0]` → `axi_wdata[63:0]`
   - `obi_data_be[3:0]` → `axi_wstrb[7:0]`
   
4. **Latency Points**
   - AR → R: 5 cycles
   - AW+W → B: 3 cycles
   
5. **Priority Logic**
   - `obi_instr_req` blocks `obi_data_gnt` (read path only)
   - Verify mutual exclusion on AR channel

**File:** `int_full_integration.vcd` (generated automatically @ end of simulation)

---

**Next Steps:**
1. View waveform: `gtkwave int_full_integration.vcd`
2. Zoom to each TEST section (marked by print statements)
3. Verify all signatures match expected behavior
4. Check for any protocol violations (valid before ready, etc.)
5. Ready for UVM testbench integration
