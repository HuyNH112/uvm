# CVA6 + HPDcache + ICache UVM 1.1d Upgrade Plan
## QuestaSim 23.3 Starter Edition — Logic Simulation Configuration

**Date:** July 2026  
**Status:** Phase 1 Ready (ISA Agent Framework)  
**Target:** Complete Testcases 1.1–2.3 (Core ALU/Branch/Exception + ICache Fetch)

---

## 1. EXECUTIVE SUMMARY

### Current State
- ✅ **HPDcache verification complete:** Driver, Monitor, Scoreboard, 12+ testcases (TC 3.1–5.4)
- ✅ **AXI Memory Model working:** Behavioral model in `hw_top.sv`, shadow_mem[], FIFO queues
- ✅ **UVM 1.1d baseline:** Compile flow validated, run_phase only (no SVA/SVAssertions)
- ❌ **Testcases 1.1–2.3 missing:** Require ISA Agent + ICache Agent (new agents)

### Goal
Extend UVM testbench to verify:
1. **TC 1.1–1.3:** CVA6 Core (ALU ops, Branch, Exception/CSR)
2. **TC 2.1–2.3:** ICache (Fetch hit/miss, Jump redirect, FENCE.I coherency)

### Scope
- Only **logic simulation** (no power, timing, EDA tools)
- No `randomize()` (UVM 1.1d Starter limitation)
- No SVA/assertions (licensing)
- **Stimulus:** Bare-metal RISC-V assembly → `.hex` files
- **Observation:** RVFI probes (CVA6) + Behavioral monitors (UVM)

---

## 2. CURRENT ARCHITECTURE ANALYSIS

### 2.1 Compilation Flow (run_uvm.do)

```
Step 1: Project compile (57 RTL files via QuestaSim project)
        ↓
Step 2: Interface compile
        tb/hpdcache_if.sv  ← only HPDcache signals
        ↓
Step 3: UVM Package compile
        sv/hpdcache_uvm_pkg.sv  ← import hpdcache_pkg
        ├─ seq_item.sv
        ├─ sequencer.sv
        ├─ driver.sv
        ├─ monitor.sv
        ├─ scoreboard.sv
        └─ env.sv
        ↓
Step 4: Hardware Top compile
        tb/hw_top.sv  ← hpdcache_wrapper + AXI mem model
        ↓
Step 5: Testbench Top compile
        tb/tb_top.sv  ← includes seq_lib, base_test, test_lib
        ├─ tb/hpdcache_seq_lib.sv
        ├─ tb/hpdcache_base_test.sv
        └─ tb/hpdcache_test_lib.sv
        ↓
Step 6: Simulate
        vsim -voptargs="+acc=rn" work.tb_top +UVM_TESTNAME=<test>
```

### 2.2 Current Hierarchy

```
tb_top.sv (UVM testbench container)
  ├─ hw_top u_hw (hardware top)
  │   ├─ hpdcache_wrapper i_dut (Device Under Test)
  │   │   ├─ hpdcache core (main cache)
  │   │   ├─ CVA6 CPU interface (core_req/core_rsp)
  │   │   └─ AXI4 interface (mem_req/mem_resp)
  │   │
  │   └─ Behavioral Memory Model (tasks: axi_read_req_enqueue, axi_read_resp_serve, axi_write_handle)
  │       ├─ shadow_mem[logic] indexed by cacheline address
  │       ├─ rd_fifo[] (depth=16 for MSHR)
  │       ├─ wr_fifo[] (depth=4 for WBUF)
  │       └─ Response generators (rd_serving, wr_rsp_serving)
  │
  └─ UVM Environment (uvm_test_top.env)
      ├─ hpdcache_sequencer
      ├─ hpdcache_driver (negedge drive, 80-cycle init delay)
      ├─ hpdcache_monitor (observe core_req/core_rsp on interface)
      ├─ hpdcache_scoreboard (compare req/rsp, track FAIL count)
      └─ config_db (VIF: hpdcache_if.driver_mp, monitor_mp)
```

### 2.3 Interface Signals (hpdcache_if.sv)

**Current:** Only HPDcache wrapper interface
```
Core side:
  - core_req_valid_i, core_req_ready_o
  - core_req_i (addr, data, op, etc.)
  - core_rsp_valid_o, core_rsp_o (rdata, error)

Memory side:
  - mem_req_read_valid_o, mem_req_read_ready_i
  - mem_resp_read_valid_i, mem_resp_read_ready_o
  - (similar for write)

Config:
  - cfg_enable_i, cfg_wbuf_threshold_i, cfg_prefetch_*
```

**Missing:** RVFI + ICache signals (need new interfaces)

---

## 3. GAP ANALYSIS: TC 1.1–2.3 Requirements

| TC | Category | Current | Need |
|---|----------|---------|------|
| 1.1 | Core ALU ops | ❌ No ISA monitor | ✓ RVFI commit_monitor |
| 1.2 | Branch prediction | ❌ No PC trace | ✓ commit_monitor + PC check |
| 1.3 | CSR/Exception | ❌ No CSR capture | ✓ csr_monitor (mepc, mcause) |
| 2.1 | ICache fetch hit/miss | ❌ No fetch monitor | ✓ fetch_monitor (dreq) |
| 2.2 | Branch fetch redirect | ❌ No kill signal | ✓ fetch_monitor + kill tracking |
| 2.3 | FENCE.I coherency | ❌ No coherency check | ✓ fetch_monitor + mem coherency |

### Missing Agents

#### **ISA Agent** (for TC 1.1–1.3)
- **commit_monitor:** Observe RVFI `commit_valid` → capture PC, instruction, GPR write
- **csr_monitor:** Observe CSR updates (mepc, mcause, mstatus)
- **isa_driver:** Control reset sequence, stimulus flow
- **golden_model:** Hardcoded expected results from `.hex` reference
- **scoreboard extension:** Compare actual vs expected commit trace

#### **ICache Agent** (for TC 2.1–2.3)
- **fetch_monitor:** Observe CVA6 I-side requests/responses
- **kill_monitor:** Track fetch cancellation (kill_s1, kill_s2, fetch_kill_i)
- **coherency_checker:** Verify FENCE.I invalidates cached instructions
- **fetch_sequencer:** (Optional) Backdoor write instruction memory for TC 2.3

---

## 4. PHASE 1: ISA AGENT IMPLEMENTATION (TC 1.1–1.3)

### 4.1 New Files Required

#### A. `cva6_rvfi_if.sv` — RVFI Interface
```systemverilog
interface cva6_rvfi_if(input logic clk_i, input logic rst_ni);
    
    // ===== RVFI Signals from CVA6 (commit_valid → core committed instruction)
    logic              commit_valid;      // Instruction committed this cycle
    logic [63:0]       commit_pc;         // Committed instruction PC
    logic [63:0]       commit_pc_next;    // Next PC (PC + 4 or branch target)
    logic [31:0]       commit_instr;      // Committed instruction opcode
    logic [4:0]        commit_rd_addr;    // Destination register (x0–x31, x0=never written)
    logic              commit_rd_we;      // Register write enable
    logic [63:0]       commit_rd_wdata;   // Register write data
    
    // ===== Exception / Trap Signals
    logic              exception_valid;   // Exception occurred this cycle
    logic [3:0]        mcause;            // Exception cause (RISC-V standard)
    logic [63:0]       mepc;              // Exception PC (address that caused trap)
    
    // ===== CSR Write Signals (optional, for TC 1.3)
    logic              csr_valid;         // CSR written this cycle
    logic [11:0]       csr_addr;          // CSR address [11:0]
    logic [63:0]       csr_wdata;         // CSR write data
    
    // Modport: monitor only (read-only observation)
    modport monitor_mp (
        input clk_i, rst_ni,
        input commit_valid, commit_pc, commit_pc_next, commit_instr,
              commit_rd_addr, commit_rd_we, commit_rd_wdata,
              exception_valid, mcause, mepc,
              csr_valid, csr_addr, csr_wdata
    );
    
endinterface : cva6_rvfi_if
```

#### B. `isa_seq_item.sv` — Minimal Sequence Item
```systemverilog
class isa_seq_item extends uvm_sequence_item;
    `uvm_object_utils(isa_seq_item)
    
    // Minimal item for UVM 1.1d (no randomize)
    logic [63:0] reset_cycles;  // Number of cycles before releasing reset
    logic        halt;          // Signal to halt test
    
    function new(string name="isa_seq_item");
        super.new(name);
        reset_cycles = 0;
        halt = 0;
    endfunction
    
    function string convert2string();
        return $sformatf("reset_cycles=%0d halt=%0b", reset_cycles, halt);
    endfunction
endclass : isa_seq_item
```

#### C. `isa_commit_monitor.sv` — Commit Event Capture
```systemverilog
class isa_commit_monitor extends uvm_monitor;
    `uvm_component_utils(isa_commit_monitor)
    
    virtual cva6_rvfi_if.monitor_mp vif;
    uvm_analysis_port #(isa_commit_event) ap_commit;
    
    typedef struct {
        logic [63:0]  pc;
        logic [63:0]  pc_next;
        logic [31:0]  instr;
        logic [4:0]   rd_addr;
        logic [63:0]  rd_wdata;
        logic         rd_we;
    } isa_commit_event;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_commit = new("ap_commit", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found in config_db")
    endfunction
    
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk_i);
            if (vif.commit_valid && vif.rst_ni) begin
                isa_commit_event evt;
                evt.pc       = vif.commit_pc;
                evt.pc_next  = vif.commit_pc_next;
                evt.instr    = vif.commit_instr;
                evt.rd_addr  = vif.commit_rd_addr;
                evt.rd_wdata = vif.commit_rd_wdata;
                evt.rd_we    = vif.commit_rd_we;
                ap_commit.write(evt);
                `uvm_info("COMMIT", $sformatf("PC=%016h INSTR=%08h RD=%d WD=%016h",
                          evt.pc, evt.instr, evt.rd_addr, evt.rd_wdata), UVM_HIGH)
            end
        end
    endtask
    
endclass : isa_commit_monitor
```

#### D. `isa_csr_monitor.sv` — CSR & Exception Capture
```systemverilog
class isa_csr_monitor extends uvm_monitor;
    `uvm_component_utils(isa_csr_monitor)
    
    virtual cva6_rvfi_if.monitor_mp vif;
    uvm_analysis_port #(isa_exception_event) ap_exception;
    uvm_analysis_port #(isa_csr_event) ap_csr_write;
    
    typedef struct {
        logic [3:0]   mcause;
        logic [63:0]  mepc;
    } isa_exception_event;
    
    typedef struct {
        logic [11:0]  csr_addr;
        logic [63:0]  csr_wdata;
    } isa_csr_event;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_exception = new("ap_exception", this);
        ap_csr_write = new("ap_csr_write", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found")
    endfunction
    
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk_i);
            
            // Exception event
            if (vif.exception_valid && vif.rst_ni) begin
                isa_exception_event evt;
                evt.mcause = vif.mcause;
                evt.mepc   = vif.mepc;
                ap_exception.write(evt);
                `uvm_info("EXCEPTION", $sformatf("mcause=%04h mepc=%016h",
                          evt.mcause, evt.mepc), UVM_MEDIUM)
            end
            
            // CSR write event
            if (vif.csr_valid && vif.rst_ni) begin
                isa_csr_event evt;
                evt.csr_addr  = vif.csr_addr;
                evt.csr_wdata = vif.csr_wdata;
                ap_csr_write.write(evt);
                `uvm_info("CSR_WRITE", $sformatf("addr=%03h wdata=%016h",
                          evt.csr_addr, evt.csr_wdata), UVM_HIGH)
            end
        end
    endtask
    
endclass : isa_csr_monitor
```

#### E. `isa_driver.sv` — Test Flow Control
```systemverilog
class isa_driver extends uvm_driver #(isa_seq_item);
    `uvm_component_utils(isa_driver)
    
    virtual cva6_rvfi_if.monitor_mp vif;  // Read-only (monitor side only)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::get(
                this, "", "rvfi_vif", vif))
            `uvm_fatal("NOVIF", "RVFI VIF not found")
    endfunction
    
    task run_phase(uvm_phase phase);
        // Note: reset is handled by hw_top.sv initial block
        // This driver mainly waits for sequence commands (not used in run_phase-only mode)
        forever begin
            isa_seq_item item;
            seq_item_port.get_next_item(item);
            `uvm_info("DRV", $sformatf("Item: %s", item.convert2string()), UVM_MEDIUM)
            seq_item_port.item_done();
        end
    endtask
    
endclass : isa_driver
```

#### F. `isa_sequencer.sv` — Sequencer
```systemverilog
class isa_sequencer extends uvm_sequencer #(isa_seq_item);
    `uvm_component_utils(isa_sequencer)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
endclass : isa_sequencer
```

#### G. `isa_agent.sv` — ISA Agent Container
```systemverilog
class isa_agent extends uvm_agent;
    `uvm_component_utils(isa_agent)
    
    isa_sequencer       sequencer;
    isa_driver          driver;
    isa_commit_monitor  commit_mon;
    isa_csr_monitor     csr_mon;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer   = isa_sequencer::type_id::create("sequencer", this);
        driver      = isa_driver::type_id::create("driver", this);
        commit_mon  = isa_commit_monitor::type_id::create("commit_mon", this);
        csr_mon     = isa_csr_monitor::type_id::create("csr_mon", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
    
endclass : isa_agent
```

#### H. `isa_scoreboard.sv` — ISA Verification Scoreboard
```systemverilog
class isa_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(isa_scoreboard)
    
    // Analysis FIFOs for incoming events
    uvm_tlm_analysis_fifo #(isa_commit_monitor::isa_commit_event) fifo_commit;
    uvm_tlm_analysis_fifo #(isa_csr_monitor::isa_exception_event) fifo_exception;
    
    // Golden reference (from .hex file or hardcoded)
    typedef struct {
        logic [63:0] pc;
        logic [31:0] instr;
        logic [4:0]  rd_addr;
        logic [63:0] rd_wdata;
    } golden_commit_t;
    
    golden_commit_t golden_reference[$];  // Queue of expected commits
    
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fifo_commit    = new("fifo_commit", this);
        fifo_exception = new("fifo_exception", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        load_golden_reference();
    endfunction
    
    function void load_golden_reference();
        // TODO: Load from .hex file or hardcode for each TC
        // Example for TC 1.1 (ALU):
        //   golden_reference = '{
        //       '{pc: 64'h0000_0000, instr: 32'h0010_0113, rd_addr: 5'd2, rd_wdata: 64'h0000_0001}, // ADD x2, x0, 1
        //       '{pc: 64'h0000_0004, instr: 32'h0010_0193, rd_addr: 5'd3, rd_wdata: 64'h0000_0002}, // ADD x3, x0, 2
        //       ...
        //   };
    endfunction
    
    task run_phase(uvm_phase phase);
        int idx = 0;
        forever begin
            isa_commit_monitor::isa_commit_event evt;
            fifo_commit.get(evt);
            
            if (idx < golden_reference.size()) begin
                golden_commit_t gold = golden_reference[idx];
                if (evt.pc == gold.pc && evt.instr == gold.instr &&
                    evt.rd_addr == gold.rd_addr && evt.rd_wdata == gold.rd_wdata) begin
                    `uvm_info("SCOREBOARD", $sformatf("PASS [%0d] PC=%016h", idx, evt.pc), UVM_HIGH)
                    pass_count++;
                end else begin
                    `uvm_error("SCOREBOARD", $sformatf("FAIL [%0d] PC mismatch: expected %016h got %016h",
                               idx, gold.pc, evt.pc))
                    fail_count++;
                end
            end
            idx++;
        end
    endtask
    
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf("PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
        if (fail_count > 0)
            `uvm_error("SCOREBOARD", "Test FAILED")
    endfunction
    
endclass : isa_scoreboard
```

### 4.2 Modified Files

#### A. `hpdcache_uvm_pkg.sv` — Add ISA classes

**Insert before `endpackage` (after line 131):**

```systemverilog
    // =========================================================================
    // ISA Agent classes — TC 1.1 (ALU), TC 1.2 (Branch), TC 1.3 (Exception)
    // =========================================================================
    `include "isa_seq_item.sv"
    `include "isa_commit_monitor.sv"
    `include "isa_csr_monitor.sv"
    `include "isa_driver.sv"
    `include "isa_sequencer.sv"
    `include "isa_agent.sv"
    `include "isa_scoreboard.sv"
```

#### B. `hw_top.sv` — Add RVFI Interface

**Insert after line 65 (after hpdcache_if instantiation):**

```systemverilog
    // -------------------------------------------------------------------------
    // RVFI Interface instantiation (CVA6 Core observation)
    // -------------------------------------------------------------------------
    cva6_rvfi_if rvfi_vif (.clk_i(clk), .rst_ni(rst_n));
    
    // Placeholder: Connect RVFI signals from CVA6 core
    // CRITICAL: This assumes CVA6 has rvfi_probes_o or similar output
    // If core is not directly instantiated in hw_top, remove these assigns
    // and handle in top-level integration
    
    // assign rvfi_vif.commit_valid    = /* from CVA6 */;
    // assign rvfi_vif.commit_pc       = /* from CVA6 */;
    // assign rvfi_vif.commit_pc_next  = /* from CVA6 */;
    // assign rvfi_vif.commit_instr    = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_addr  = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_we    = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_wdata = /* from CVA6 */;
    // assign rvfi_vif.exception_valid = /* from CVA6 */;
    // assign rvfi_vif.mcause          = /* from CVA6 */;
    // assign rvfi_vif.mepc            = /* from CVA6 */;
    // assign rvfi_vif.csr_valid       = /* from CVA6 */;
    // assign rvfi_vif.csr_addr        = /* from CVA6 */;
    // assign rvfi_vif.csr_wdata       = /* from CVA6 */;
```

#### C. `tb_top.sv` — Add RVFI config_db

**Insert after line 45 (after monitor config_db set):**

```systemverilog
        uvm_config_db #(virtual cva6_rvfi_if.monitor_mp)::set(
            null,
            "uvm_test_top.*",
            "rvfi_vif",
            u_hw.rvfi_vif
        );
```

#### D. `hpdcache_env.sv` — Add ISA Agent

**Modify `hpdcache_env.sv`:**

```systemverilog
class hpdcache_env extends uvm_env;

    `uvm_component_utils(hpdcache_env)

    hpdcache_sequencer  sequencer;
    hpdcache_driver     driver;
    hpdcache_monitor    monitor;
    hpdcache_scoreboard scoreboard;
    
    isa_agent          isa_agt;        // NEW
    isa_scoreboard     isa_sb;         // NEW

    // ... rest of code ...

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer   = hpdcache_sequencer::type_id::create("sequencer", this);
        driver      = hpdcache_driver::type_id::create("driver", this);
        monitor     = hpdcache_monitor::type_id::create("monitor", this);
        scoreboard  = hpdcache_scoreboard::type_id::create("scoreboard", this);
        
        isa_agt     = isa_agent::type_id::create("isa_agt", this);              // NEW
        isa_sb      = isa_scoreboard::type_id::create("isa_sb", this);          // NEW
    endfunction

    function void connect_phase(uvm_phase phase);
        // Existing connections
        driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap_req.connect(scoreboard.fifo_req.analysis_export);
        monitor.ap_rsp.connect(scoreboard.fifo_rsp.analysis_export);
        
        // NEW: ISA connections
        isa_agt.commit_mon.ap_commit.connect(isa_sb.fifo_commit.analysis_export);
        isa_agt.csr_mon.ap_exception.connect(isa_sb.fifo_exception.analysis_export);
    endfunction

endclass : hpdcache_env
```

#### E. `run_uvm.do` — Update Compile Script

**Add after Step 2 (after hpdcache_if.sv), before Step 3:**

```tcl
echo "=== Step 2b: Compile RVFI Interface ==="
vlog -sv -work work \
    +incdir+. \
    +incdir+$TB_DIR/sv \
    +incdir+$TB_DIR/tb \
    +incdir+$HPDCACHE_INC \
    $TB_DIR/tb/cva6_rvfi_if.sv
```

---

## 5. PHASE 2: ICACHE AGENT IMPLEMENTATION (TC 2.1–2.3)

### 5.1 New Files Required

#### A. `cva6_icache_if.sv` — ICache Interface
```systemverilog
interface cva6_icache_if(input logic clk_i, input logic rst_ni);
    
    // ===== Fetch Request (CPU → ICache)
    logic              fetch_req_valid;
    logic              fetch_req_ready;
    logic [63:0]       fetch_req_addr;
    logic [1:0]        fetch_req_size;    // 0=32b, 1=64b, etc.
    
    // ===== Fetch Response (ICache → CPU)
    logic              fetch_rsp_valid;
    logic              fetch_rsp_ready;
    logic [127:0]      fetch_rsp_data;    // 2×64b instruction pair
    logic              fetch_rsp_err;
    
    // ===== Kill/Flush (CPU → ICache) — abort pending fetch
    logic              fetch_kill_s1;     // Kill at stage 1
    logic              fetch_kill_s2;     // Kill at stage 2
    
    // ===== AXI Read (ICache → Memory) — refill
    logic              axi_arvalid;
    logic              axi_arready;
    logic [63:0]       axi_araddr;
    logic [7:0]        axi_arlen;
    logic [2:0]        axi_arsize;
    logic [3:0]        axi_arid;
    
    logic              axi_rvalid;
    logic              axi_rready;
    logic [511:0]      axi_rdata;
    logic [3:0]        axi_rid;
    logic              axi_rlast;
    logic [1:0]        axi_rresp;
    
    modport monitor_mp (
        input clk_i, rst_ni,
        input fetch_req_valid, fetch_req_ready, fetch_req_addr, fetch_req_size,
              fetch_rsp_valid, fetch_rsp_ready, fetch_rsp_data, fetch_rsp_err,
              fetch_kill_s1, fetch_kill_s2,
              axi_arvalid, axi_arready, axi_araddr, axi_arlen, axi_arsize, axi_arid,
              axi_rvalid, axi_rready, axi_rdata, axi_rid, axi_rlast, axi_rresp
    );
    
endinterface : cva6_icache_if
```

#### B. `icache_fetch_monitor.sv` — Fetch Event Capture
```systemverilog
class icache_fetch_monitor extends uvm_monitor;
    `uvm_component_utils(icache_fetch_monitor)
    
    virtual cva6_icache_if.monitor_mp vif;
    uvm_analysis_port #(icache_fetch_event) ap_fetch_req;
    uvm_analysis_port #(icache_fetch_event) ap_fetch_rsp;
    uvm_analysis_port #(icache_kill_event) ap_kill;
    
    typedef struct {
        logic [63:0]  addr;
        logic [1:0]   size;
        int           cycle;
    } icache_fetch_event;
    
    typedef struct {
        logic [63:0]  addr;
        logic         stage1;  // Killed at S1
        logic         stage2;  // Killed at S2
        int           cycle;
    } icache_kill_event;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_fetch_req = new("ap_fetch_req", this);
        ap_fetch_rsp = new("ap_fetch_rsp", this);
        ap_kill      = new("ap_kill", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual cva6_icache_if.monitor_mp)::get(
                this, "", "icache_vif", vif))
            `uvm_fatal("NOVIF", "ICache VIF not found")
    endfunction
    
    task run_phase(uvm_phase phase);
        int cycle = 0;
        forever begin
            @(posedge vif.clk_i);
            if (!vif.rst_ni) begin
                cycle = 0;
            end else begin
                // Fetch Request
                if (vif.fetch_req_valid && vif.fetch_req_ready) begin
                    icache_fetch_event evt;
                    evt.addr  = vif.fetch_req_addr;
                    evt.size  = vif.fetch_req_size;
                    evt.cycle = cycle;
                    ap_fetch_req.write(evt);
                    `uvm_info("FETCH_REQ", $sformatf("[%0d] addr=%016h", cycle, evt.addr), UVM_HIGH)
                end
                
                // Fetch Response
                if (vif.fetch_rsp_valid && vif.fetch_rsp_ready) begin
                    icache_fetch_event evt;
                    evt.addr  = vif.fetch_req_addr;  // Not available in rsp, use last req addr
                    evt.cycle = cycle;
                    ap_fetch_rsp.write(evt);
                    `uvm_info("FETCH_RSP", $sformatf("[%0d] data=%0x", cycle, vif.fetch_rsp_data), UVM_HIGH)
                end
                
                // Kill signal
                if (vif.fetch_kill_s1 || vif.fetch_kill_s2) begin
                    icache_kill_event evt;
                    evt.addr   = vif.fetch_req_addr;
                    evt.stage1 = vif.fetch_kill_s1;
                    evt.stage2 = vif.fetch_kill_s2;
                    evt.cycle  = cycle;
                    ap_kill.write(evt);
                    `uvm_info("KILL", $sformatf("[%0d] S1=%b S2=%b", cycle, evt.stage1, evt.stage2), UVM_HIGH)
                end
                
                cycle++;
            end
        end
    endtask
    
endclass : icache_fetch_monitor
```

#### C. `icache_scoreboard.sv` — ICache Verification
```systemverilog
class icache_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(icache_scoreboard)
    
    uvm_tlm_analysis_fifo #(icache_fetch_monitor::icache_fetch_event) fifo_req;
    uvm_tlm_analysis_fifo #(icache_fetch_monitor::icache_fetch_event) fifo_rsp;
    uvm_tlm_analysis_fifo #(icache_fetch_monitor::icache_kill_event) fifo_kill;
    
    int unsigned miss_count = 0;   // Requests that miss
    int unsigned hit_count = 0;    // Requests that hit
    int unsigned kill_count = 0;   // Requests killed
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fifo_req  = new("fifo_req", this);
        fifo_rsp  = new("fifo_rsp", this);
        fifo_kill = new("fifo_kill", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        // TC 2.1: Sequential fetch → first should miss, rest hit
        // TC 2.2: Jump → old fetch killed, new fetch issued
        // TC 2.3: FENCE.I → fetch should be refilled
        
        `uvm_info("ICACHE_SB", "ICache scoreboard active", UVM_MEDIUM)
    endtask
    
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ICACHE_SB", $sformatf("HIT=%0d MISS=%0d KILL=%0d",
                  hit_count, miss_count, kill_count), UVM_LOW)
    endfunction
    
endclass : icache_scoreboard
```

### 5.2 File List Summary

---

## 6. FILE INVENTORY & MODIFICATIONS

### 6.1 NEW Files to Create

| File | Size | Purpose | Phase |
|------|------|---------|-------|
| `tb/cva6_rvfi_if.sv` | ~100 lines | RVFI interface (CVA6 commit/exception) | 1 |
| `sv/isa_seq_item.sv` | ~30 lines | Minimal sequence item | 1 |
| `sv/isa_commit_monitor.sv` | ~90 lines | Capture commit events | 1 |
| `sv/isa_csr_monitor.sv` | ~90 lines | Capture CSR/exception | 1 |
| `sv/isa_driver.sv` | ~40 lines | Test flow control | 1 |
| `sv/isa_sequencer.sv` | ~20 lines | UVM sequencer | 1 |
| `sv/isa_agent.sv` | ~50 lines | ISA agent container | 1 |
| `sv/isa_scoreboard.sv` | ~100 lines | ISA verification scoreboard | 1 |
| `tb/cva6_icache_if.sv` | ~100 lines | ICache interface (fetch/kill/AXI) | 2 |
| `sv/icache_fetch_monitor.sv` | ~100 lines | Fetch event capture | 2 |
| `sv/icache_scoreboard.sv` | ~80 lines | ICache verification | 2 |
| `testplan/prog_alu.hex` | ~100 lines | Bare-metal ALU program | 1 |
| `testplan/prog_branch.hex` | ~150 lines | Bare-metal branch program | 1 |
| `testplan/prog_exception.hex` | ~100 lines | Bare-metal exception program | 1 |
| `testplan/prog_fencei.hex` | ~200 lines | Bare-metal FENCE.I program | 2 |
| `testplan/upgrade.md` | - | This document | - |

### 6.2 MODIFIED Files

| File | Lines Changed | Reason |
|------|----------------|--------|
| `sv/hpdcache_uvm_pkg.sv` | +7 | Include ISA agent classes (phase 1) |
| `tb/hw_top.sv` | +15 | Instantiate RVFI interface + assigns |
| `tb/tb_top.sv` | +6 | Add RVFI config_db set |
| `sv/hpdcache_env.sv` | +10 | Add isa_agent instantiation + connect |
| `run_uvm.do` | +12 | Add RVFI interface compile step |
| `tb/hpdcache_base_test.sv` | - | No change (TC 1.x tests derive from this) |

### 6.3 NO CHANGE Required

| File | Reason |
|------|--------|
| `tb/hpdcache_if.sv` | HPDcache interface; RVFI + ICache use separate interfaces |
| `tb/hw_top.sv` (memory model) | AXI model already complete; reuse as-is |
| `sv/hpdcache_seq_item.sv` | HPDcache transactions unaffected |
| `sv/hpdcache_driver.sv` | HPDcache driver unaffected |
| `sv/hpdcache_monitor.sv` | HPDcache monitor unaffected |
| `sv/hpdcache_scoreboard.sv` | HPDcache scoreboard unaffected |
| `tb/hpdcache_seq_lib.sv` | HPDcache sequences (TC 3.1–5.4) unaffected |
| `tb/hpdcache_test_lib.sv` | HPDcache test classes (TC 3.1–5.4) unaffected |

---

## 7. COMPILATION FLOW — UPDATED

### 7.1 Original Flow

```
Step 1: RTL compile (57 files)
Step 2: Interface → hpdcache_if.sv
Step 3: Package → hpdcache_uvm_pkg.sv (includes driver, monitor, etc.)
Step 4: Hardware → hw_top.sv
Step 5: Testbench → tb_top.sv
Step 6: Simulate → vsim
```

### 7.2 NEW Flow (with Phase 1)

```
Step 1: RTL compile (57 files)
Step 2: Interfaces
        ├─ hpdcache_if.sv (existing)
        └─ cva6_rvfi_if.sv (NEW)
Step 3: Packages
        └─ hpdcache_uvm_pkg.sv
            ├─ hpdcache_seq_item.sv (existing)
            ├─ hpdcache_driver.sv (existing)
            ├─ hpdcache_monitor.sv (existing)
            ├─ hpdcache_scoreboard.sv (existing)
            ├─ hpdcache_env.sv (existing, MODIFIED)
            ├─ isa_seq_item.sv (NEW)
            ├─ isa_commit_monitor.sv (NEW)
            ├─ isa_csr_monitor.sv (NEW)
            ├─ isa_driver.sv (NEW)
            ├─ isa_sequencer.sv (NEW)
            ├─ isa_agent.sv (NEW)
            └─ isa_scoreboard.sv (NEW)
Step 4: Hardware
        ├─ hw_top.sv (MODIFIED: add rvfi_vif instantiation)
Step 5: Testbench
        ├─ tb_top.sv (MODIFIED: add config_db for rvfi_vif)
Step 6: Simulate
        └─ vsim -voptargs="+acc=rn" work.tb_top +UVM_TESTNAME=<test>
```

### 7.3 Updated `run_uvm.do` Snippet

```tcl
echo "=== Step 2a: Compile HPDcache Interface ==="
vlog -sv -work work ... $TB_DIR/tb/hpdcache_if.sv

echo "=== Step 2b: Compile RVFI Interface ==="
vlog -sv -work work ...
    $TB_DIR/tb/cva6_rvfi_if.sv

echo "=== Step 3: Compile UVM Package ==="
vlog -sv -work work \
    -L mtiUvm \
    $TB_DIR/sv/hpdcache_uvm_pkg.sv
    # (hpdcache_uvm_pkg.sv internally includes isa_* classes)
```

---

## 8. TEST FLOW — EXECUTION SEQUENCE

### 8.1 Test Structure (run_phase only)

```
tb_top.sv (top-level module)
  ├─ clock/reset generation (hw_top.sv initial block)
  ├─ hw_top instantiation
  │   ├─ DUT (hpdcache_wrapper)
  │   ├─ AXI memory model
  │   └─ VIF instantiation (dut_if, rvfi_vif)
  │
  └─ UVM run_test("core_basic_alu_ops")  [TC 1.1]
      ├─ build_phase → instantiate env, agents
      ├─ connect_phase → get VIF from config_db, connect monitors
      │
      └─ run_phase
          ├─ Load prog_alu.hex → memory model via backdoor
          ├─ Wait reset release
          ├─ Core starts executing → commits instructions
          ├─ Monitors observe:
          │   ├─ isa_commit_monitor → capture PC, instr, GPR
          │   ├─ isa_csr_monitor → exception/CSR events
          │   └─ hpdcache_monitor → cache traffic (if any)
          ├─ Scoreboard compares actual vs. golden reference
          ├─ Wait for drain (300 cycles post-last instruction)
          └─ Report: PASS/FAIL
```

### 8.2 Test Execution for TC 1.1 (ALU)

```
[0 ns]         tb_top instantiates hw_top
                 clk=0, rst_n=0
                 
[100 ns]       reset released (rst_n=1 after 10 cycles × 10 ns)
               
[200 ns]       test.run_phase() starts
               load prog_alu.hex → mem_model[0x0000_0000:...]
               
[210 ns]       core fetches 1st instruction @ PC=0x0000_0000 (ADD x2, x0, 1)
               isa_commit_monitor captures:
                 PC=0x0000_0000, instr=0x00100113, rd_addr=2, rd_wdata=0x0000_0001
               
[220 ns]       core commits → isa_scoreboard checks:
               Expected: rd_wdata=0x1, got: rd_wdata=0x1 → PASS [0]
               
[230 ns]       core fetches 2nd instruction @ PC=0x0000_0004 (ADD x3, x0, 2)
               ...
               
[3100 ns]      all instructions committed
               isa_scoreboard reports: PASS=N, FAIL=0
               
[3400 ns]      drain timeout → report_phase
               "Test PASSED" or "Test FAILED"
               
[3400 ns]      $finish
```

---

## 9. DEPENDENCIES & RTL SIGNALS

### 9.1 Critical: CVA6 Core RVFI Signals

**Required from CVA6 RTL:** Verify these signals exist in your core

| Signal | Type | Source | Used in |
|--------|------|--------|---------|
| `rvfi_probes_o.commit_valid` | logic | Core (commit stage) | TC 1.1–1.3 |
| `rvfi_probes_o.commit_pc` | [63:0] | Commit stage | TC 1.2 (branch) |
| `rvfi_probes_o.commit_pc_next` | [63:0] | Commit stage | TC 1.2 |
| `rvfi_probes_o.commit_instr` | [31:0] | Commit stage | TC 1.1–1.3 |
| `rvfi_probes_o.commit_rd_addr` | [4:0] | Commit WB | TC 1.1 |
| `rvfi_probes_o.commit_rd_wdata` | [63:0] | Commit WB | TC 1.1 |
| `csr_mepc_o` or `rvfi_probes_o.mepc` | [63:0] | CSR unit | TC 1.3 |
| `csr_mcause_o` or `rvfi_probes_o.mcause` | [3:0] | CSR unit | TC 1.3 |

**Action:** Confirm these signal names in your CVA6 RTL file (e.g., `cva6_core.sv` or `cva6_cv32a6_imac.sv`)

### 9.2 Critical: CVA6 ICache Signals (Phase 2)

| Signal | Type | Source | Used in |
|--------|------|--------|---------|
| `dreq_o.valid` | logic | ICache | TC 2.1 (fetch response) |
| `dreq_o.data` | [127:0] | ICache | TC 2.1 |
| `dreq_i.req` | logic | Core | TC 2.1 (fetch request) |
| `dreq_i.vaddr` | [63:0] | Core | TC 2.1 |
| `dreq_i.kill_s1` | logic | Core | TC 2.2 (branch redirect) |
| `dreq_i.kill_s2` | logic | Core | TC 2.2 |
| (or) `fetch_kill_i` | logic | Core | TC 2.2 (alternative name) |

**Action:** Verify ICache fetch interface in CVA6 RTL

### 9.3 Firmware Files Required (Bare-metal RISC-V)

| File | Program | Lines | Instruction Set |
|------|---------|-------|-----------------|
| `prog_alu.hex` | ADD, SUB, AND, OR, SLT | ~50 | RV64I |
| `prog_branch.hex` | BEQ, BNE, JAL, JALR | ~100 | RV64I |
| `prog_exception.hex` | ECALL or illegal instr | ~50 | RV64I + RV64Zicsr |
| `prog_fencei.hex` | Modify code + FENCE.I | ~200 | RV64I + Zifencei |

**Format:** Intel HEX or raw binary (load via `$readmemh()` in testbench)

---

## 10. IMPLEMENTATION ROADMAP

### Phase 1: ISA Agent (Weeks 1–2) ✓ Ready
- [ ] Create `cva6_rvfi_if.sv`
- [ ] Create `isa_seq_item.sv`, `isa_commit_monitor.sv`, `isa_csr_monitor.sv`
- [ ] Create `isa_driver.sv`, `isa_sequencer.sv`, `isa_agent.sv`, `isa_scoreboard.sv`
- [ ] Modify `hpdcache_uvm_pkg.sv` (add includes)
- [ ] Modify `hw_top.sv` (add RVFI interface + assigns)
- [ ] Modify `tb_top.sv` (add config_db)
- [ ] Modify `hpdcache_env.sv` (add isa_agent)
- [ ] Modify `run_uvm.do` (add RVFI compile step)
- [ ] Verify RVFI signal names in CVA6 RTL
- [ ] Create firmware: `prog_alu.hex`, `prog_branch.hex`, `prog_exception.hex`
- [ ] Write TC 1.1 test class: `core_basic_alu_ops`
- [ ] Write TC 1.2 test class: `core_branch_prediction_flush`
- [ ] Write TC 1.3 test class: `core_exception_trap`
- [ ] Debug & validate TC 1.1–1.3

### Phase 2: ICache Agent (Weeks 3–4)
- [ ] Create `cva6_icache_if.sv`
- [ ] Create `icache_fetch_monitor.sv`, `icache_scoreboard.sv`
- [ ] Modify `hpdcache_env.sv` (add icache_agent)
- [ ] Modify `hw_top.sv` (add ICache interface assigns)
- [ ] Verify ICache signal names in CVA6 RTL
- [ ] Create firmware: `prog_fencei.hex`
- [ ] Write TC 2.1 test: `icache_seq_fetch_hit_miss`
- [ ] Write TC 2.2 test: `icache_jump_target_miss`
- [ ] Write TC 2.3 test: `icache_fence_i_flush`
- [ ] Debug & validate TC 2.1–2.3

### Phase 3: Integration & Regression (Week 5)
- [ ] Run full regression: TC 1.1–1.3 + TC 2.1–2.3
- [ ] Verify no interference between HPDcache (TC 3.1–5.4) + ISA + ICache tests
- [ ] Generate coverage reports
- [ ] Final documentation

---

## 11. SIGNAL CHECKLIST — CVA6 RTL VERIFICATION

**Before starting Phase 1, confirm:**

| Signal | RTL File | Path | Status |
|--------|----------|------|--------|
| `commit_valid` | `cva6_ex_stage.sv` (?) | `u_core.rvfi_*.commit_valid` | ❓ NEED |
| `commit_pc` | CSR / IFetch | `u_core.rvfi_*.commit_pc` | ❓ NEED |
| `commit_instr` | Decode | `u_core.rvfi_*.commit_instr` | ❓ NEED |
| `commit_rd_addr` | Writeback | `u_core.gpr_*.waddr` | ❓ NEED |
| `commit_rd_wdata` | Writeback | `u_core.gpr_*.wdata` | ❓ NEED |
| `mepc` | CSR unit | `u_core.csr_*.mepc_o` | ❓ NEED |
| `mcause` | CSR unit | `u_core.csr_*.mcause_o` | ❓ NEED |

**Action Required:** Provide RTL file hierarchy or signal names

---

## 12. COMMON PITFALLS & SOLUTIONS

| Pitfall | Symptom | Solution |
|---------|---------|----------|
| RVFI signals not found | `vsim-3015` width mismatch | Verify signal names in CVA6 RTL; match bit widths |
| reset timing | Monitors see garbage before rst_ni=1 | Check `if (!vif.rst_ni)` in all monitors |
| Golden reference mismatch | Many FAIL in scoreboard | Verify `.hex` program matches expected commit trace |
| Interface modport error | Can't get VIF from config_db | Ensure modport name matches config_db type: `cva6_rvfi_if.monitor_mp` |
| Deadlock in run_phase | Simulation hangs after 5K cycles | Check watchdog timeout in tb_top (default 20K); increase if needed |
| Monitor never captures events | Scoreboard FIFO empty at end | Add `@(posedge clk)` loop in monitor; check `rst_ni` guard |

---

## 13. VALIDATION CHECKLIST

### Pre-Compilation
- [ ] CVA6 RVFI signal names confirmed
- [ ] CVA6 ICache signal names confirmed  
- [ ] Firmware `.hex` files ready
- [ ] Directory structure:
  ```
  UVM/
  ├─ sv/
  │  ├─ hpdcache_uvm_pkg.sv (MODIFIED)
  │  ├─ isa_seq_item.sv (NEW)
  │  ├─ isa_commit_monitor.sv (NEW)
  │  ├─ isa_csr_monitor.sv (NEW)
  │  ├─ isa_driver.sv (NEW)
  │  ├─ isa_sequencer.sv (NEW)
  │  ├─ isa_agent.sv (NEW)
  │  ├─ isa_scoreboard.sv (NEW)
  │  └─ (+ icache_*.sv in Phase 2)
  ├─ tb/
  │  ├─ cva6_rvfi_if.sv (NEW)
  │  ├─ hpdcache_base_test.sv (existing)
  │  ├─ hpdcache_if.sv (existing)
  │  ├─ hpdcache_seq_lib.sv (existing)
  │  ├─ hpdcache_test_lib.sv (existing)
  │  ├─ hw_top.sv (MODIFIED)
  │  ├─ tb_top.sv (MODIFIED)
  │  └─ (+ cva6_icache_if.sv in Phase 2)
  ├─ testplan/
  │  ├─ prog_alu.hex (NEW)
  │  ├─ prog_branch.hex (NEW)
  │  ├─ prog_exception.hex (NEW)
  │  └─ prog_fencei.hex (NEW, Phase 2)
  └─ run_uvm.do (MODIFIED)
  ```

### Compilation
- [ ] `vlog -sv ... cva6_rvfi_if.sv` → Success
- [ ] `vlog -sv ... hpdcache_uvm_pkg.sv` → Compiles with ISA classes
- [ ] `vlog -sv ... hw_top.sv` → No errors (RVFI interface instantiation)
- [ ] `vlog -sv ... tb_top.sv` → No errors (RVFI config_db)
- [ ] `vsim work.tb_top` → Elaboration successful

### Simulation (TC 1.1)
- [ ] Watchdog doesn't fire (20K cycles default)
- [ ] Monitor message: `[COMMIT] PC=0x0000_0000 INSTR=0x00100113`
- [ ] Scoreboard: `PASS >= N-1` (allow for startup variance)
- [ ] Final report: `UVM_ERROR == 0`
- [ ] Waveform shows: clk, rst_n, rvfi_commit_valid, rvfi_commit_rd_wdata

### Regression (All TC 1.x + TC 2.x)
- [ ] No interference: HPDcache tests (TC 3.1–5.4) still pass
- [ ] All ISA tests report `PASSED`
- [ ] All ICache tests report `PASSED`
- [ ] Total simulation time < 1 hour for full regression

---

## 14. REFERENCES & DOCUMENTATION

### RFCs
- **RISC-V ISA Manual v2.2:** https://riscv.org/technical/specifications/
- **RISC-V Debug Spec 0.13:** rvfi (Risc-V Formal Interface)
- **AXI4 Protocol A.1.4.8**

### Files in This Repo
- `UVM_CVA6_PLAN.pdf` — Overall architecture  
- `testplan_uvm11d.csv` — Test matrix (TC 1.1–5.4)
- `hpdcache_config.svh` — HPDcache parameters

### Tools
- **QuestaSim 2023.3 (Starter):** https://www.siemens-eda.com/products/questa
- **RISC-V GCC:** `riscv64-unknown-elf-gcc` (for compiling `.c` → `.hex`)

---

## 15. SIGN-OFF & NEXT STEPS

### Immediate Actions (Next 48 Hours)
1. **Verify RTL signals:**
   - Provide CVA6 core RTL file paths or signal map
   - Confirm RVFI signal existence (commit_valid, commit_instr, mepc, mcause)
   - Confirm ICache signal existence (dreq_i, dreq_o, kill_*)

2. **Prepare firmware:**
   - Generate `.hex` files from RISC-V assembly
   - Validate via spike ISS (https://github.com/riscv-software-src/riscv-isa-sim)

3. **Stage files:**
   - Copy this document to `testplan/upgrade.md`
   - Create `sv/` subdirectory structure for ISA classes

### Week 1 Completion Criteria
- [ ] Phase 1 files created (8 new `.sv` files)
- [ ] 4 files modified (hpdcache_uvm_pkg, hw_top, tb_top, run_uvm.do)
- [ ] Compilation successful
- [ ] TC 1.1 simulation passes

### Success Metrics
- **Compilation:** `vsim work.tb_top` without errors
- **Simulation:** All TC 1.x pass with `PASS >= expected, FAIL == 0`
- **Regression:** No impact on TC 3.1–5.4 (HPDcache tests)
- **Coverage:** Functional coverage >= 80% for ISA commit path

---

## Appendix A: Minimal Example (TC 1.1)

### prog_alu.hex
```hex
:020000040000F8
:10000000130101000100000000000000000000000F
:10001000130102000200000000000000000000000E
:10002000B300120002000000000000000000000001
:10003000050100007305100000000000000000009F
:00000001FF
```
(ADD x2, x0, 1; ADD x3, x0, 2; AND x6, x2, x3; ECALL)

### Golden Reference (in isa_scoreboard.sv)
```
[0] PC=0x0000_0000, INSTR=0x00100113, RD=2, WDATA=0x0000_0001
[1] PC=0x0000_0004, INSTR=0x00200193, RD=3, WDATA=0x0000_0002
[2] PC=0x0000_0008, INSTR=0x003001B3, RD=6, WDATA=0x0000_0000
[3] PC=0x0000_000C, INSTR=0x00000073, RD=0, WDATA=0x(exception)
```

---

**Document Version:** 1.0  
**Last Updated:** July 2026  
**Status:** Ready for Phase 1 Implementation  
**Next Review:** After first compile
