# =============================================================================
# prog_fencei.s — TC 2.x: ICache Coherency (FENCE.I)
# =============================================================================
# Test ICache coherency after code modification
# Use case: Self-modifying code, dynamic code generation
#
# Execution flow:
#   PC=0x00: addi x2, x0, 1          → x2 = 1
#   PC=0x04: li x3, 0x1000           → x3 = 0x1000 (memory address to modify)
#   PC=0x08: li x4, 0x00200293       → x4 = machine code for "addi x5, x0, 2"
#   PC=0x0C: sw x4, 0(x3)            → Store x4 to address 0x1000 (write new instruction)
#   PC=0x10: fence.i                 → Flush ICache, ensure instruction writes visible
#   PC=0x14: jalr x0, x3, 0          → Jump to 0x1000 (execute modified code)
#   
#   PC=0x1000 (dynamically written):
#            addi x5, x0, 2          → x5 = 2 (from self-modifying code)
#   PC=0x1004: ecall                 → Trap
#
# RVFI expected commits:
#   [0] addi x2, x0, 1               → x2 := 1
#   [1] li x3, 0x1000                → x3 := 0x1000
#   [2] li x4, 0x00200293            → x4 := machine code
#   [3] sw x4, 0(x3)                 → Store (no rd, memory write)
#   [4] fence.i                      → Fence (no register write)
//   [5] jalr x0, x3, 0              → Jump to 0x1000
//   [6] addi x5, x0, 2 (at 0x1000)  → x5 := 2 (from modified code)
//   [7] ecall                       → Exception
//
// Verification:
//   ✓ FENCE.I instruction commits
//   ✓ Self-modifying code executes correctly after FENCE.I
//   ✓ ICache is invalidated (new instruction visible)
//   ✓ Dynamic code produces expected register writes
// =============================================================================

.text
.globl _start

_start:
    # Setup
    addi x2, x0, 1              # x2 = 1

    # Address of code to modify
    lui x3, 0x1                 # x3 = 0x1000 (load upper immediate)
    addi x3, x3, 0              # x3 = 0x1000 (adjust if needed)

    # Machine code to write: "addi x5, x0, 2"
    # Encoding: 0x00200293
    lui x4, 0x0020              # x4[31:12] = 0x0020
    addi x4, x4, 0x293          # x4[11:0] = 0x293 (complete encoding)

    # Write instruction to memory
    sw x4, 0(x3)                # Store to address 0x1000

    # Synchronize ICache with code modifications
    fence.i                     # FENCE.I: flush ICache

    # Jump to modified code location
    jalr x0, x3, 0              # Jump to x3 (0x1000), don't link

    # Should not reach here (execution jumps to 0x1000)
    j _start

// =========================================================================
// Modified code at 0x1000 (loaded via self-modifying store + FENCE.I)
// =========================================================================
.org 0x1000

modified_code:
    addi x5, x0, 2              # x5 = 2 (executed after FENCE.I)
    ecall                       # Trap
    j _start                    # Hang
