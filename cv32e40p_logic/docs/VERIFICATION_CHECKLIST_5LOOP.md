# 5-Loop Comprehensive Verification Checklist

**Status:** Ready for Final Verification Run  
**Date:** 30 July 2026  
**Target:** 30/30 PASS + Zero Synchrony Issues

---

## LOOP ITERATION PLAN

### **LOOP 1: COMPILATION & ELABORATION**

**Checks:**
- [ ] All 166 RTL files compile without errors
- [ ] obi_to_axi4_adapter.sv compiles successfully
- [ ] int_full_integration.sv compiles (may have warnings about static variables - OK)
- [ ] Elaboration completes successfully
- [ ] No port/interface mismatches

**Success Criteria:**
- ✓ Compilation: 0 failed
- ✓ Elaboration: No fatal errors

---

### **LOOP 2: SIMULATION EXECUTION**

**Checks:**
- [ ] Simulation starts without errors
- [ ] Clock generation starts (10ns period)
- [ ] Reset sequence executes (rst_ni released @ 50ns)
- [ ] All signals initialize to known state
- [ ] Test sequence begins at cycle 6 (after reset)

**Success Criteria:**
- ✓ Simulation runs to completion ($finish called)
- ✓ No simulation hangs/timeouts
- ✓ No protocol violations detected

**Expected Simulation Output Markers:**
```
[TEST 1] Instruction Fetch via OBI → AXI4 AR/R
[TEST 2] Data Write via OBI → AXI4 AW/W/B
[TEST 3] Data Read via OBI → AXI4 AR/R
[TEST 4] Concurrent Instr + Data Read (Priority Test)
[TEST 5] Data Width Conversion Verification
```

---

### **LOOP 3: SIGNAL SYNCHRONY VERIFICATION**

**Check each signal type:**

#### **A. Clock Domain Signals** (Must update @ posedge only)

| Signal | Type | Synchrony | Check |
|--------|------|-----------|-------|
| clk_i | Clock | — | ✓ 10ns period |
| rst_ni | Reset | Async (OK) | ✓ Deasserts @ 50ns |
| read_latency_q[3:0] | Sequential | ✓ | Must countdown 5→0 @ posedge |
| read_latency_d[3:0] | Sequential | ✓ | Must capture latency_q @ posedge |
| rvalid_pulse_r | Sequential | ✓ | Must pulse when latency_q==2 |
| write_latency_q[3:0] | Sequential | ✓ | Must countdown 3→0 @ posedge |
| write_latency_d[3:0] | Sequential | ✓ | Must capture latency_q @ posedge |
| bvalid_pulse_r | Sequential | ✓ | Must pulse when latency_q==2 |

**Waveform Check:**
```
Verify countdown sequence:
read_latency_q:  5 → 4 → 3 → 2 → 1 → 0
                 (one value per clock cycle, updates @ posedge)

read_latency_d:  X → 5 → 4 → 3 → 2 → 1 → 0
                 (delayed by 1 cycle)

rvalid_pulse_r:  0 → 0 → 0 → 1 → 0 → 0 → 0
                 (HIGH exactly when latency_q==2)
```

#### **B. OBI Handshake Signals** (Combinational from adapter)

| Signal | Source | Sync Check | Expected Behavior |
|--------|--------|-----------|-------------------|
| obi_instr_gnt | Adapter combinational | Via instr_req & m_arready_i | Pulse HIGH when request accepted |
| obi_data_gnt | Adapter combinational | Via data_req & arbitration | Pulse HIGH when request accepted |
| obi_instr_rvalid | axi_rvalid & (axi_rid==0) | Via rvalid_pulse_r | Pulse HIGH when latency==1 |
| obi_data_rvalid | (axi_rvalid & rid==1) \| axi_bvalid | Via pulse registers | Pulse HIGH when latency==1 |

**Waveform Check:**
```
Grant sequence (Request → Grant → Response):
obi_instr_req:    ┌─┐ (1 cycle)
obi_instr_gnt:    ┌─┐ (same cycle as req)
                  └─┘
axi_arvalid:      ┌────────────┐ (continuous after grant)
axi_rvalid:             ┌─┐    (5 cycles after AR valid)
obi_instr_rvalid:       ┌─┐    (corresponds to axi_rvalid)
```

#### **C. AXI4 Channel Signals** (From adapter to slave)

| Channel | Signals | Sync Source | Check |
|---------|---------|-------------|-------|
| AR | arvalid, araddr, arid, arsize, arburst | Combinational from OBI | Valid HIGH when instr/data request |
| R | rvalid, rdata, rid | From testbench responder | Valid pulse after latency countdown |
| AW | awvalid, awaddr, awid, awsize, awburst | Combinational from data_req & we | Valid HIGH when write request |
| W | wvalid, wdata, wstrb, wlast | Combinational from data_req & we | Valid HIGH when write request |
| B | bvalid, bid, bresp | From testbench responder | Valid pulse after latency countdown |

**Waveform Check:**
```
Read request → response:
arvalid: ┌─┐ (1-2 cycles)
arid:    │0│ or │1│
rvalid:        ┌─┐ (5 cycles later)
rid:           │0│ or │1│ (echoes arid)

Write request → response:
awvalid: ┌─┐ (1-2 cycles)
wvalid:  ┌─┐ (same as awvalid)
awid:    │1│ (always 1 for writes)
bvalid:        ┌─┐ (3 cycles later)
bid:           │1│ (echoes awid)
```

---

### **LOOP 4: PORT VALIDITY CHECK**

**Every port must have valid data when signal is asserted:**

#### **OBI Ports** (From CPU side)

- [ ] `instr_req_i=1` → `instr_addr_i` must be valid address
- [ ] `instr_gnt_o=1` → occurs same cycle as req
- [ ] `instr_rvalid_o=1` → `instr_rdata_o` must contain read data
- [ ] `data_req_i=1` → `data_addr_i` must be valid address
- [ ] `data_we_i=1` → `data_wdata_i` and `data_be_i` must be valid
- [ ] `data_gnt_o=1` → occurs same cycle as req
- [ ] `data_rvalid_o=1` → `data_rdata_o` must contain response data

**Waveform Check:**
```
Signal stability:
obi_instr_addr:  stable when req=1 ✓
obi_data_addr:   stable when req=1 ✓
obi_data_wdata:  stable when we=1 ✓
obi_data_be:     stable when we=1 ✓
obi_instr_rdata: valid when rvalid=1 ✓
obi_data_rdata:  valid when rvalid=1 ✓
```

#### **AXI4 Ports** (Master side)

- [ ] `m_arvalid_o=1` → `m_araddr_o`, `m_arid_o` must be valid
- [ ] `m_rvalid_i=1` → `m_rdata_i`, `m_rid_i` must be valid
- [ ] `m_awvalid_o=1` → `m_awaddr_o`, `m_awid_o` must be valid
- [ ] `m_wvalid_o=1` → `m_wdata_o`, `m_wstrb_o` must be valid
- [ ] `m_bvalid_i=1` → `m_bid_i` must be valid

**Waveform Check:**
```
Data validity:
m_araddr_o:  valid when arvalid=1 ✓
m_arid_o:    valid when arvalid=1 ✓
m_rdata_i:   valid when rvalid=1 ✓
m_rid_i:     valid when rvalid=1 ✓
m_awaddr_o:  valid when awvalid=1 ✓
m_awid_o:    valid when awvalid=1 ✓
m_wdata_o:   valid when wvalid=1 ✓
m_wstrb_o:   valid when wvalid=1 ✓
m_bid_i:     valid when bvalid=1 ✓
```

---

### **LOOP 5: LOGIC LOCK & DEADLOCK DETECTION**

**Check for stuck signals (should never stay HIGH/LOW indefinitely):**

#### **Signals that should pulse (HIGH then LOW):**

| Signal | Expected Pulse Width | Check |
|--------|----------------------|-------|
| obi_instr_gnt | 1 cycle | Must go LOW next cycle |
| obi_data_gnt | 1 cycle | Must go LOW next cycle |
| obi_instr_rvalid | 1 cycle | Must go LOW next cycle |
| obi_data_rvalid | 1 cycle | Must go LOW next cycle |
| axi_arvalid | 1-2 cycles | Must go LOW when arready |
| axi_awvalid | 1-2 cycles | Must go LOW when awready |
| axi_wvalid | 1-2 cycles | Must go LOW when wready |
| axi_rvalid | 1 cycle | Must pulse exactly once |
| axi_bvalid | 1 cycle | Must pulse exactly once |

**Waveform Check:**
```
Pulse detection (must not get stuck):
Signal ┌─┐
       │ │ ← Pulse HIGH
       └─┘
        ↑
     Should clear next cycle, not stay HIGH

If signal stays HIGH for >2 cycles WITHOUT arready/ready:
  ✗ LOGIC LOCK DETECTED (ERROR)
```

#### **Signals that should be combinational (no delay):**

| Signal | Source | Check |
|--------|--------|-------|
| m_arvalid_o | ar_valid (combinational) | Changes same cycle as instr/data_req |
| m_awvalid_o | data_req & data_we (combinational) | Changes same cycle as data_req |
| m_wvalid_o | data_req & data_we (combinational) | Changes same cycle as data_req |

**Waveform Check:**
```
Request → Valid propagation (0 cycle delay):
data_req: ┌─┐
m_awvalid:┌─┐ ← Should start SAME cycle, not next
          └─┘
```

#### **Deadlock Scenarios to Check:**

1. **Concurrent requests stuck:**
   - [ ] If both instr_req AND data_req high, grants should alternate
   - [ ] Neither should stay stuck LOW

2. **Response stuck:**
   - [ ] If latency counter running, response must pulse eventually
   - [ ] Verify countdown never stops prematurely

3. **Arbitration stuck:**
   - [ ] After instr_rvalid pulses, data should be grantable
   - [ ] Priority should release after instr completes

**Verification:**
```
No deadlock if:
✓ Every request eventually gets grant (within 2 cycles)
✓ Every grant eventually gets response (within latency+2 cycles)
✓ No signal stays HIGH longer than its pulse width
✓ Latency counters always countdown to zero
```

---

## WAVEFORM INSPECTION PROCEDURE

### **Step 1: Open Waveform**
```bash
gtkwave int_full_integration.vcd
```

### **Step 2: Add Critical Signals**
```
Recommended signal groups to add:
1. Clock/Reset:
   - clk_i
   - rst_ni

2. OBI Instruction Path:
   - obi_instr_req
   - obi_instr_gnt
   - obi_instr_addr[31:0]
   - obi_instr_rvalid
   - obi_instr_rdata[31:0]

3. OBI Data Path:
   - obi_data_req
   - obi_data_gnt
   - obi_data_addr[31:0]
   - obi_data_we
   - obi_data_be[3:0]
   - obi_data_wdata[31:0]
   - obi_data_rvalid
   - obi_data_rdata[31:0]

4. Responder Latency (CRITICAL):
   - read_latency_q[3:0]     ← Must show 5→4→3→2→1→0
   - read_latency_d[3:0]     ← Must show delayed copy
   - rvalid_pulse_r          ← Must pulse HIGH when latency_q==2
   - write_latency_q[3:0]    ← Must show 3→2→1→0
   - write_latency_d[3:0]    ← Must show delayed copy
   - bvalid_pulse_r          ← Must pulse HIGH when latency_q==2

5. AXI4 AR Channel:
   - axi_arvalid
   - axi_arready
   - axi_araddr[31:0]
   - axi_arid[3:0]
   - axi_arsize[2:0]
   - axi_arburst[1:0]
   - axi_arlen[7:0]

6. AXI4 R Channel:
   - axi_rvalid              ← Must follow rvalid_pulse_r
   - axi_rready
   - axi_rdata[63:0]
   - axi_rid[3:0]
   - axi_rlast
   - axi_rresp[1:0]

7. AXI4 AW Channel:
   - axi_awvalid
   - axi_awready
   - axi_awaddr[31:0]
   - axi_awid[3:0]

8. AXI4 W Channel:
   - axi_wvalid
   - axi_wready
   - axi_wdata[63:0]
   - axi_wstrb[7:0]
   - axi_wlast

9. AXI4 B Channel:
   - axi_bvalid              ← Must follow bvalid_pulse_r
   - axi_bready
   - axi_bid[3:0]
   - axi_bresp[1:0]
```

### **Step 3: Zoom to Each Test Region**

**TEST 1: Cycles 7-15**
- Verify: instr_req → instr_gnt → axi_arvalid → axi_rvalid → obi_instr_rvalid
- Check: read_latency_q countdown from 5 to 0
- Check: rvalid_pulse_r pulses when latency_q==2

**TEST 2: Cycles 17-23**
- Verify: data_req & we=1 → data_gnt → axi_awvalid & axi_wvalid → axi_bvalid → obi_data_rvalid
- Check: write_latency_q countdown from 3 to 0
- Check: bvalid_pulse_r pulses when latency_q==2
- Check: axi_wdata[63:0] = {32'h0, 32'hCAFEBABE}
- Check: axi_wstrb[7:0] = 8'b00001111

**TEST 3: Cycles 25-33**
- Verify: data_req & we=0 → data_gnt → axi_arvalid (arid=1) → axi_rvalid → obi_data_rvalid
- Check: read_latency_q countdown
- Check: axi_arid[3:0] = 4'h1 (data read, not instruction)

**TEST 4: Cycles 35-52**
- Verify: Concurrent requests → priority → instr_gnt=1, data_gnt=0
- Check: Only instr AR issued (arid=0)
- Verify: After instr response, data request succeeds

**TEST 5: Cycles 54-60**
- Verify: Partial byte enable expansion
- Check: axi_wstrb[7:0] = 8'b00001100 (for be[1100])

---

## SUCCESS CRITERIA

### **All 5 Loops Pass When:**

✓ **LOOP 1 - Compilation:**
- All files compile: 166/166 ✓
- No elaboration errors ✓

✓ **LOOP 2 - Simulation:**
- Completes without hangs ✓
- All 5 tests execute ✓
- Expected output markers present ✓

✓ **LOOP 3 - Synchrony:**
- All sequential signals update @ posedge ✓
- Latency counters countdown 5→0 or 3→0 ✓
- Pulse registers generate on edge detection ✓
- Outputs follow registered inputs ✓

✓ **LOOP 4 - Port Validity:**
- No invalid data on ports ✓
- Addresses stable when req=1 ✓
- Data stable when valid=1 ✓

✓ **LOOP 5 - Logic Integrity:**
- No stuck signals ✓
- No deadlocks ✓
- All pulses clear after 1-2 cycles ✓
- Latency always counts to zero ✓

### **Final Result:**
```
PASSED CHECKS: 30/30 ✓
FAILED CHECKS: 0/0 ✓
SYNCHRONY ISSUES: 0 ✓
PORT VIOLATIONS: 0 ✓
LOGIC LOCKS: 0 ✓

STATUS: ✓✓✓ PRODUCTION READY ✓✓✓
```

---

## TROUBLESHOOTING GUIDE

### **If Test Fails:**

1. **Latency not counting down:**
   - Check: `read_latency_q` in waveform
   - Should go 5→4→3→2→1→0 every clock cycle
   - If stuck: Responder request acceptance broken

2. **Pulse never generates:**
   - Check: `rvalid_pulse_r` when `read_latency_q==2`
   - Should go HIGH exactly for 1 cycle
   - If missing: Pulse generation logic broken

3. **Valid signal stuck HIGH:**
   - Check: Clock is running (posedge occurring)
   - Check: Pulse register is clearing
   - If stuck: Register clear logic broken

4. **Data invalid on port:**
   - Check: Address stable when req=1
   - Check: Data stable when we=1
   - If changing: Testbench stimulus broken

5. **Deadlock (grants not pulsing):**
   - Check: Arbitration logic in adapter
   - Check: No conflicting requests
   - If both stuck: Priority logic broken

---

**Document Status:** Complete Verification Checklist Ready  
**Next Action:** Run `int_verify_5loop_complete.do` and inspect waveform  
**Expected:** All checks PASS ✓

