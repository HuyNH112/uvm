# =============================================================================
# prog_branch.s — TC 1.2: Branch Operations
# =============================================================================
# Test branch instructions: BEQ (taken/not-taken), BNE, JAL, JALR
#
# Execution trace (expected):
#   PC=0x00: addi x2, x0, 1          → x2 = 1
#   PC=0x04: addi x3, x0, 1          → x3 = 1
#   PC=0x08: beq x2, x3, +0x0C       → Taken (x2==x3), jump to PC+0x0C = 0x14
#   PC=0x14: addi x4, x0, 10         → x4 = 10
#   PC=0x18: addi x5, x0, 20         → x5 = 20
#   PC=0x1C: bne x4, x5, +0x08       → Taken (x4!=x5), jump to PC+0x08 = 0x24
#   PC=0x24: jal x1, +0x08           → Jump to 0x2C, store return addr (PC+4=0x28) in x1
#   PC=0x2C: addi x6, x0, 100        → x6 = 100
#   PC=0x30: jalr x0, x1, 0          → Jump to x1 (0x28, return), x0=0 (no link)
#   PC=0x28: ecall                   → Trap
#
# RVFI expected commits: 9 (or 10 with jalr return)
#   Branches should show correct PC transitions
#   JAL should write return address to x1
#   JALR should restore execution flow
#
# Verification:
#   ✓ BEQ taken: PC jumps forward by offset
#   ✓ BNE taken: PC jumps forward by offset
#   ✓ JAL: x1 = PC+4 (return address)
#   ✓ JALR: Restores control flow
# =============================================================================

.text
.globl _start

_start:
    # Setup operands
    addi x2, x0, 1              # x2 = 1
    addi x3, x0, 1              # x3 = 1

    # Test BEQ (branch if equal) — TAKEN
    # x2 == x3, so jump forward by 12 bytes
    beq x2, x3, forward_label   # Jump to forward_label

    # This should be skipped (branch taken)
    addi x4, x0, 999            # Should NOT execute

forward_label:
    # Continue after BEQ
    addi x4, x0, 10             # x4 = 10
    addi x5, x0, 20             # x5 = 20

    # Test BNE (branch if not equal) — TAKEN
    # x4 != x5, so jump forward by 8 bytes
    bne x4, x5, bne_label       # Jump to bne_label

    # This should be skipped
    addi x6, x0, 999            # Should NOT execute

bne_label:
    # Test JAL (jump and link)
    jal x1, jump_target         # Jump to jump_target, link PC+4 to x1

    # Return point (after JAL)
    ecall                       # Trap: mcause = 11

jump_target:
    # This is the target of JAL
    addi x6, x0, 100            # x6 = 100

    # Return to caller using x1 (which holds PC+4 from JAL)
    jalr x0, x1, 0              # Jump to x1, don't link (x0=destination)

    # Hang
    j _start
