# CV32E40P L1 Cache Verification Framework

Functional verification of an **L1 cache subsystem (HPDcache + I-Cache + Domino prefetcher)** integrated into the **CV32E40P** RISC-V core. The project delivers a production-grade **OBI-to-AXI4 protocol adapter** that bridges the CPU's OpenBus Interface to the cache's AXI4 Full interface, plus a UVM verification environment built around it. Phase 1 (RTL logic simulation of the adapter and full integration path) is complete with **19/19 checks passing and zero timing violations**.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Project Architecture](#project-architecture)
- [Verification Methodology](#verification-methodology)
- [Key Components](#key-components)
- [Results & Status](#results--status)
- [Usage Examples](#usage-examples)
- [Future Work](#future-work)
- [Contributing](#contributing)
- [Contact & Support](#contact--support)

---

## Overview

The CV32E40P core exposes a simple OBI memory interface, while the HPDcache L1 subsystem expects AXI4 Full. This repository closes that gap and proves the result correct.

Two layers of work sit here side by side. The first is an RTL integration layer — the adapter, a cache-wrapped core, and directed logic-simulation testbenches that establish the datapath actually works cycle by cycle. The second is a UVM environment (driver, monitor, scoreboard, coverage, prefetcher monitor, performance measurement) that raises verification from directed checks to constrained-random, coverage-driven testing against an 11-item testplan.

**Target configuration:** CV32E40P (RV32IMC) + HPDcache (4-way, 32-bit PA) + Domino prefetcher, verified under QuestaSim 2023.3 with UVM 1.1d.

---

## Features

- **Production OBI-to-AXI4 adapter** — full AXI4 channel set, 32-bit → 64-bit data width conversion, byte-enable to strobe translation (4-bit → 8-bit), ID-based response demuxing.
- **Instruction-priority arbitration** — instruction fetch wins over data reads, with automatic data retry so no request is dropped.
- **Complete L1 integration stack** — CV32E40P core, HPDcache, I-Cache and Domino prefetcher wired together as a single elaboratable top.
- **Directed logic-simulation suite** — 19 scenarios covering fetch, read, write, arbitration, retry, and byte-enable paths, runnable without a UVM license.
- **Full UVM environment** — sequencer/driver/monitor/scoreboard, functional coverage model, and a dual-requester virtual interface for I-Cache and D-Cache traffic.
- **RISC-V instruction decoder** — sign-extended immediates and generators for LW, SW, ADDI, JAL, BEQ, BNE, and FENCE.I, used to build realistic instruction streams.
- **Performance instrumentation** — cache hit/miss monitoring, prefetcher effectiveness tracking, and automated performance reporting.
- **Turnkey simulation scripts** — QuestaSim `.do` files for each integration scenario, from smoke test to full RTL.

---

## Repository Structure

```
UVM/
├── cv32e40p_logic/          RTL sources + Phase 1 logic simulation
│   ├── cv32e40p-master/       CV32E40P RISC-V core (178 files, ~43.8k LOC)
│   ├── cv-hpdcache-master/    HPDcache L1 + Domino prefetcher (88 files, ~19.9k LOC)
│   ├── icache-master/         Instruction cache (8 files, ~1.7k LOC)
│   ├── integration/           Adapters and cache-wrapped core (4 files, 700 LOC)
│   ├── testbench/             Directed testbenches and test cases (20 files)
│   ├── do_files/              QuestaSim run scripts (11 scripts)
│   └── docs/                  Adapter spec, timing analyses, verification reports
├── sv/                      UVM environment components (15 files, ~3.6k LOC)
├── tb/                      Testbench top, interfaces, test library (23 files, ~2.6k LOC)
├── do/                      Top-level compile and run scripts
├── doc/                     Setup guide, code reviews, phase summaries
├── markdown_data/           Engineering notes, fix logs, phase reports
├── testplan/                testplan_CV32E40P.xlsx (11 test items)
└── project_uvm/             QuestaSim project and work library
```

| Folder | Purpose |
| --- | --- |
| [`cv32e40p_logic/integration/`](cv32e40p_logic/integration/) | The protocol adapters — this is the design under test |
| [`cv32e40p_logic/testbench/`](cv32e40p_logic/testbench/) | Directed Phase 1 testbenches that produced the 19/19 result |
| [`sv/`](sv/) | Reusable UVM agent, scoreboard, coverage, and performance components |
| [`tb/`](tb/) | Testbench top level, virtual interfaces, and the TC-* test classes |
| [`do/`](do/), [`cv32e40p_logic/do_files/`](cv32e40p_logic/do_files/) | QuestaSim automation |

---

## Getting Started

### Prerequisites

| Requirement | Version | Notes |
| --- | --- | --- |
| QuestaSim | 2023.3 | Earlier versions with SystemVerilog 2012 support should work |
| UVM | 1.1d | Ships with Questa; only needed for Phase 2+ |
| Disk space | ~2 GB | RTL sources plus simulation libraries |

Logic simulation (Phase 1) needs **no UVM license** — the directed testbenches are plain SystemVerilog.

### Clone

```bash
git clone https://github.com/HuyNH112/uvm.git
cd uvm
```

### Configure paths

The `.do` scripts use absolute paths set at the top of each file. Update them to match your checkout before running:

```tcl
set BASE_DIR      "D:/UVM/project_uvm"
set UVM_DIR       "D:/UVM/sv"
set TB_DIR        "D:/UVM/tb"
set HPDCACHE_INC  "D:/UVM/cv32e40p_logic/cv-hpdcache-master/rtl/include"
```

### First run

```bash
cd cv32e40p_logic
vsim -c -do do_files/full_rtl_integration.do
```

A passing run ends with all 19 integration checks reported as PASS.

---

## Project Architecture

```
                 ┌───────────────────────────┐
                 │   CV32E40P RISC-V Core    │
                 │        (RV32IMC)          │
                 └─────┬───────────────┬─────┘
                       │ OBI instr     │ OBI data
                       │ (32-bit)      │ (32-bit)
                 ┌─────▼───────────────▼─────┐
                 │   obi_to_axi4_adapter     │
                 │  • instr-priority arbiter │
                 │  • 32→64 data conversion  │
                 │  • BE→WSTRB conversion    │
                 │  • ID-based demux         │
                 └─────────────┬─────────────┘
                               │ AXI4 Full (64-bit)
                 ┌─────────────▼─────────────┐
                 │  L1 Cache Subsystem       │
                 │  HPDcache │ I-Cache       │
                 │  Domino Prefetcher        │
                 └─────────────┬─────────────┘
                               │
                 ┌─────────────▼─────────────┐
                 │     Main Memory Model     │
                 └───────────────────────────┘
```

The UVM environment attaches to this stack through `cv32e40p_obi_adapter_if`, a dual-requester virtual interface that presents requester 0 as the instruction path and requester 1 as the data path, each with `master`, `slave`, and `monitor` modports.

---

## Verification Methodology

The project follows a four-phase plan that moves from proving the datapath to proving coverage closure.

### Phase 1 — RTL Logic Simulation ✅ Complete

Directed simulation of the adapter and the full integration path. Establishes protocol compliance and timing correctness before any random stimulus. Also delivered the UVM foundation pieces (instruction decoder, OBI virtual interface, CV32E40P-correct parameters) that unblock the later phases. **Result: 19/19 checks PASSED.**

### Phase 2 — UVM Agent Integration 🔄 In Progress

Wire `hpdcache_driver.sv` and `hpdcache_monitor.sv` to the instruction decoder and the OBI virtual interface, including requester selection between I-Cache and D-Cache. This unblocks the two integration test items, TC-INT-01 and TC-INT-02.

### Phase 3 — Coverage & Performance 📋 Planned

Environment cleanup, ISA stimulus optimization, prefetcher monitor completion, and the performance measurement framework.

### Phase 4 — Regression & Closure 📋 Planned

Full constrained-random regression across all 11 testplan items, functional and code coverage closure, and sign-off reporting.

### Testplan coverage

| Test ID | Category | Phase 1 Status |
| --- | --- | --- |
| TC-I-01, TC-I-02 | Instruction cache | Unblocked |
| TC-D-01 … TC-D-03 | Data cache | Unblocked |
| TC-P-01 … TC-P-03 | Prefetcher | Unblocked |
| TC-INT-01, TC-INT-02 | Full integration | Partially unblocked (needs Phase 2) |
| TC-SYS-01 | System level | Blocked (needs Phase 3) |

**8 of 11 items fully unblocked by Phase 1.**

---

## Key Components

### OBI-to-AXI4 Adapter — 214 LOC

[`cv32e40p_logic/integration/obi_to_axi4_adapter.sv`](cv32e40p_logic/integration/obi_to_axi4_adapter.sv)

```systemverilog
module obi_to_axi4_adapter #(
  parameter int AXI_ADDR_WIDTH = 32,
  parameter int AXI_DATA_WIDTH = 64,  // HPDcache default
  parameter int AXI_ID_WIDTH   = 4
) (
  input  logic clk_i,
  input  logic rst_ni,
  // OBI slave: instruction + data paths
  // AXI4 Full master: AR / R / AW / W / B channels
  ...
);
```

Single-beat AXI4 transfers, fully synchronous on one clock, with no backpressure toward the CPU. Read latency is 5 cycles and write response latency is 3 cycles in the reference testbench model. The full signal-level contract is documented in [`OBI_to_AXI4_ADAPTER_SPECIFICATION.md`](cv32e40p_logic/docs/OBI_to_AXI4_ADAPTER_SPECIFICATION.md).

### Integration Testbench — 810 LOC

[`cv32e40p_logic/testbench/int_full_integration.sv`](cv32e40p_logic/testbench/int_full_integration.sv)

Drives all 19 Phase 1 scenarios: an AXI4 slave behavioral model with configurable latency, self-checking assertions on every handshake, and a scoreboard that compares returned data against expected values per transaction.

### UVM Environment — ~3.6k LOC

| File | LOC | Role |
| --- | --- | --- |
| [`sv/hpdcache_performance_measurement.sv`](sv/hpdcache_performance_measurement.sv) | 506 | Latency and throughput measurement |
| [`sv/hpdcache_wrapper.sv`](sv/hpdcache_wrapper.sv) | 420 | DUT wrapper for the UVM environment |
| [`sv/hpdcache_prefetcher_monitor.sv`](sv/hpdcache_prefetcher_monitor.sv) | 390 | Domino prefetcher observation |
| [`sv/instruction_decoder.sv`](sv/instruction_decoder.sv) | 392 | RISC-V decode + 7 instruction generators |
| [`sv/hpdcache_driver.sv`](sv/hpdcache_driver.sv) | 263 | Transaction driving |
| [`sv/hpdcache_monitor.sv`](sv/hpdcache_monitor.sv) | 237 | Protocol observation |
| [`sv/hpdcache_coverage.sv`](sv/hpdcache_coverage.sv) | 195 | Functional coverage model |
| [`sv/hpdcache_scoreboard.sv`](sv/hpdcache_scoreboard.sv) | 178 | Reference checking |

Testbench infrastructure lives in [`tb/`](tb/): `hw_top.sv` (447 LOC) builds the hardware top, `hpdcache_seq_lib.sv` (511 LOC) holds the sequence library, and `cv32e40p_obi_adapter_if.sv` (260 LOC) provides the dual-requester virtual interface.

### RTL Stack — 65,000+ LOC across 274 files

| Component | Files | LOC |
| --- | --- | --- |
| CV32E40P core | 178 | ~43,800 |
| HPDcache + Domino prefetcher | 88 | ~19,900 |
| I-Cache | 8 | ~1,700 |
| Integration layer | 4 | 700 |

---

## Results & Status

### Phase 1: 19/19 PASSED

| Test | Component | Checks | Result |
| --- | --- | --- | --- |
| TC1 | Instruction fetch | 3 | ✅ PASS |
| TC2 | Data write path | 5 | ✅ PASS |
| TC3 | Data read path | 3 | ✅ PASS |
| TC4a | Priority arbitration | 4 | ✅ PASS |
| TC4b | Data retry | 2 | ✅ PASS |
| TC5 | Byte-enable conversion | 3 | ✅ PASS |
| **Total** | **L1 integration** | **19** | **🟢 100%** |

Zero failures, zero timing violations, zero elaboration errors. Protocol compliance verified in both directions across the OBI ↔ AXI4 boundary.

### Phase 1 UVM foundation

Three action items delivered 631 lines of new SystemVerilog: the instruction decoder (A1), the OBI adapter virtual interface (A4), and a CV32E40P-correct parameter set (A7) that moved `UVM_HPDCACHE_PA_WIDTH` from 56 to 32 bits and `UVM_HPDCACHE_WAYS` from 8 to 4, with dependent tag widths recomputed automatically. All five verification rounds passed.

---

## Usage Examples

### Run the full RTL integration test (19/19)

```bash
cd cv32e40p_logic
vsim -c -do do_files/full_rtl_integration.do
```

### Run individual scenarios

```bash
vsim -c -do do_files/run_icache_test.do      # I-Cache path
vsim -c -do do_files/run_dcache_test.do      # D-Cache path
vsim -c -do do_files/obi_hpdcache.do         # OBI + HPDcache smoke test
vsim -c -do do_files/run_int02.do            # Minimal integration proof
```

### Run with waveforms

```bash
vsim -do do_files/int_waveform.do
```

### Five-loop regression

```bash
vsim -c -do do_files/int_verify_5loop_complete.do
```

### Logic simulation without a UVM license

```bash
vsim -c -do do/uvm.do        # compile RTL foundation
vsim -c -do do/run_uvm.do    # run the simple logic testbench
```

---

## Future Work

**Phase 2 — UVM agent integration**
- `hpdcache_driver.sv`: map decoder output to driver transactions and implement I-Cache/D-Cache requester selection
- `hpdcache_monitor.sv`: capture OBI/HPDcache traffic and cross-check against the decoder
- Unblocks TC-INT-01 and TC-INT-02

**Phase 3 — Coverage and performance**
- Environment cleanup and ISA stimulus optimization
- Complete the prefetcher monitor and the performance measurement framework
- Unblocks TC-SYS-01

**Phase 4 — Regression and closure**
- Constrained-random regression across all 11 testplan items
- Functional and code coverage closure with sign-off reporting

**Longer term**
- Burst-mode AXI4 transfers (currently single-beat)
- Formal property verification of the adapter
- Multi-core / multi-requester cache coherency scenarios

---

## Contributing

Contributions are welcome, particularly on Phase 2 driver and monitor work.

1. Fork the repository and create a feature branch (`git checkout -b feature/phase2-driver`).
2. Follow the existing style — lowercase `snake_case` for signals, `_i`/`_o` suffixes for ports, header comments on every module.
3. Run the Phase 1 regression before opening a PR; 19/19 must still pass.
4. Update the relevant document in [`markdown_data/`](markdown_data/) or [`cv32e40p_logic/docs/`](cv32e40p_logic/docs/) when behavior changes.
5. Open a pull request describing the change, the tests you ran, and the results.

Bug reports should include the simulator version, the `.do` script used, and the failing transcript excerpt.

---

## Contact & Support

**Huy Nguyen** — nguyenhoanghuynt73@gmail.com

- Issues and questions: [GitHub Issues](https://github.com/HuyNH112/uvm/issues)
- Adapter specification: [`cv32e40p_logic/docs/OBI_to_AXI4_ADAPTER_SPECIFICATION.md`](cv32e40p_logic/docs/OBI_to_AXI4_ADAPTER_SPECIFICATION.md)
- Setup guide: [`doc/SETUP_GUIDE.md`](doc/SETUP_GUIDE.md)
- Phase 1 report: [`markdown_data/PHASE1_COMPLETION_REPORT.md`](markdown_data/PHASE1_COMPLETION_REPORT.md)

### Acknowledgements

This project builds on open-source cores from the OpenHW Group and CEA:

- [CV32E40P](https://github.com/openhwgroup/cv32e40p) — OpenHW Group (Apache-2.0)
- [CV-HPDcache](https://github.com/openhwgroup/cv-hpdcache) — CEA / OpenHW Group (Apache-2.0)

Verification framework code in `sv/`, `tb/`, and `cv32e40p_logic/integration/` is original work.
