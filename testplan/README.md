# Firmware Test Programs — CVA6 ISA Verification (Phase 1-2)

## Overview

This directory contains RISC-V firmware test programs (`.s` assembly + `.hex` machine code) for TC 1.1–2.3 in the CVA6 + HPDcache verification flow.

**Location:** `/mnt/user-data/outputs/testplan/`

**Files:**
- `prog_alu.s` / `prog_alu.hex` — TC 1.1: Basic ALU operations
- `prog_branch.s` / `prog_branch.hex` — TC 1.2: Branch instructions
- `prog_exception.s` / `prog_exception.hex` — TC 1.3: Exception handling
- `prog_fencei.s` / `prog_fencei.hex` — TC 2.x: ICache coherency

---

## Test Cases

### TC 1.1: Basic ALU Operations (`prog_alu.hex`)

**Purpose:** Verify basic arithmetic/logic operations and instruction commits

**Instructions tested:**
- ADDI (add immediate)
- AND (bitwise AND)
- OR (bitwise OR)
- XOR (bitwise XOR)
- ECALL (exception trap)

**Expected RVFI trace:**
```
[0] addi x2, x0, 1    → x2 = 0x1
[1] addi x3, x0, 2    → x3 = 0x2
[2] and x6, x2, x3    → x6 = 0x0
[3] or x7, x2, x3     → x7 = 0x3
[4] xor x8, x2, x3    → x8 = 0x3
[5] ecall             → exception_valid=1, mcause=11
```

**Success criteria:**
- ✓ 6 commits captured by isa_commit_monitor
- ✓ Register writes match expected values
- ✓ Exception triggered on ECALL

---

### TC 1.2: Branch Instructions (`prog_branch.hex`)

**Purpose:** Verify branch prediction and control flow

**Instructions tested:**
- BEQ (branch if equal) — taken
- BNE (branch if not equal) — taken
- JAL (jump and link)
- JALR (jump and link register)

**Expected RVFI trace:**
```
[0] addi x2, x0, 1           → x2 = 0x1
[1] addi x3, x0, 1           → x3 = 0x1
[2] beq x2, x3, +12          → branch taken, PC jumps to 0x14
[3] (skipped: addi x4, 999)
[4] addi x4, x0, 10          → x4 = 0xA
[5] addi x5, x0, 20          → x5 = 0x14
[6] bne x4, x5, +8           → branch taken, PC jumps to 0x20
[7] (skipped: addi x6, 999)
[8] jal x1, +8               → link PC+4=0x24 to x1, jump to 0x28
[9] addi x6, x0, 100         → x6 = 0x64
[10] jalr x0, x1, 0          → jump to x1 (0x24)
[11] ecall                   → exception_valid=1, mcause=11
```

**Success criteria:**
- ✓ Branches execute with correct taken/not-taken behavior
- ✓ JAL writes return address (PC+4) to x1
- ✓ JALR restores control flow to link address

---

### TC 1.3: Exception Handling (`prog_exception.hex`)

**Purpose:** Verify exception detection and trap state setup

**Instructions tested:**
- ADDI (setup instruction)
- ECALL (machine environment call exception)

**Expected RVFI trace:**
```
[0] addi x2, x0, 42  → x2 = 0x2A, exception_valid=0
[1] ecall            → exception_valid=1, mcause=0x0B (11 decimal)
                       mepc=0x0004 (PC of ECALL instruction)
```

**Success criteria:**
- ✓ ECALL instruction commits
- ✓ exception_valid = 1
- ✓ mcause = 11 (ECALL from M-mode)
- ✓ mepc = PC of ECALL instruction (0x0004)

---

### TC 2.x: ICache Coherency (`prog_fencei.hex`) — Phase 2

**Purpose:** Verify ICache coherency after self-modifying code

**Instructions tested:**
- LUI (load upper immediate)
- ADDI (arithmetic)
- SW (store word)
- FENCE.I (instruction cache fence)
- JALR (jump to modified code)

**Expected RVFI trace:**
```
[0] addi x2, x0, 1            → x2 = 1
[1] lui x3, 0x1               → x3 = 0x1000
[2] addi x3, x3, 0            → x3 = 0x1000
[3] lui x4, 0x20              → x4 = 0x20000
[4] addi x4, x4, 0x293        → x4 = 0x00200293 (machine code)
[5] sw x4, 0(x3)              → Store to 0x1000
[6] fence.i                   → Flush ICache
[7] jalr x0, x3, 0            → Jump to 0x1000
[8] addi x5, x0, 2            → x5 = 2 (from dynamic code at 0x1000)
[9] ecall                     → exception_valid=1, mcause=11
```

**Success criteria:**
- ✓ Self-modified instruction executes correctly
- ✓ FENCE.I flushes ICache (new instruction visible after jump)
- ✓ x5 register shows correct value from dynamic code

---

## Integration with hw_top.sv

### Instruction Memory Initialization

The `.hex` files are loaded into CVA6's instruction memory at simulation start. Typical integration:

```systemverilog
// In hw_top.sv: Initialize instruction memory from hex file
initial $readmemh("testplan/prog_alu.hex", u_cva6.instruction_memory);
```

### Memory Addresses

- **Boot code (TC 1.x):** 0x0000–0x0034
- **Dynamic code (TC 2.x):** 0x1000–0x100C

### Reset Behavior

On `rst_ni = 0` → release, CVA6 PC = 0x0000 (default), start fetching from boot code.

---

## File Formats

### `.s` (Assembly)

RISC-V assembly source code. Can be compiled with:

```bash
$ riscv64-unknown-elf-gcc -c prog_alu.s -o prog_alu.o
$ riscv64-unknown-elf-objdump -d prog_alu.o > prog_alu.dis
```

### `.hex` (Verilog $readmemh format)

32-bit words in hexadecimal, one per line. Example:

```
00100113    // 0x00: addi x2, x0, 1
00200193    // 0x04: addi x3, x0, 2
...
```

**Format**: `$readmemh` compatible for Verilog:
```systemverilog
$readmemh("prog_alu.hex", instruction_mem);
```

---

## RVFI Monitoring

Each test produces an expected RVFI trace. The ISA Agent compares against golden reference:

```systemverilog
isa_commit_monitor → captures commit events
isa_scoreboard → matches commits against golden trace
```

**Golden reference per test:**
- TC 1.1: 6 commits (5 ALU + 1 ECALL)
- TC 1.2: 10 commits (8 execute + 2 trap-related)
- TC 1.3: 2 commits (1 ALU + 1 ECALL exception)
- TC 2.x: 10 commits (boot + dynamic + exception)

---

## Next Steps

1. **Step 2 (Current):** Generate .hex files ✅ (DONE)
2. **Step 3:** Compile testbench with hw_top.sv + firmware
3. **Step 4:** Run TC 1.1 smoke test: `vsim work.tb_top +UVM_TESTNAME=core_basic_alu_ops`
4. **Step 5:** Verify RVFI trace matches golden reference
5. **Phase 2:** Enable ICache tests (TC 2.x)

---

## References

- **upgrade.md § 7:** Compilation flow
- **upgrade.md § 8:** Test execution traces
- **upgrade.md § 14:** Success metrics
- **RISC-V ISA Manual:** [riscv.org](https://riscv.org)
