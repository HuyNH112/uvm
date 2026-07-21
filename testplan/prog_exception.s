# =============================================================================
# prog_exception.s — TC 1.3: Exception Handling
# =============================================================================
# Test exception traps: ECALL (environment call), CSR writes on exception
#
# Execution trace (expected):
#   PC=0x00: addi x2, x0, 42         → x2 = 42
#   PC=0x04: ecall                   → TRAP: mcause=11 (Environment call)
#   
# On ECALL exception:
#   - CVA6 commits the ECALL instruction
#   - Sets mepc = PC of ECALL (0x04)
#   - Sets mcause = 11 (0x0B, ECALL from M-mode)
#   - Sets mtval = 0 (no additional trap value)
#   - Jumps to mtvec (machine trap handler)
#
# RVFI expected commits: 2
#   [0] commit_instr=0x02A00113, commit_pc=0x0000, rd=2, rd_wdata=0x2A
#   [1] commit_instr=0x00000073, commit_pc=0x0004, exception_valid=1, mcause=11
#                                                    mepc=0x0004
#
# Verification:
#   ✓ ECALL instruction commits
#   ✓ exception_valid = 1
#   ✓ mcause = 11 (ECALL)
#   ✓ mepc = PC of ECALL (0x0004)
#   ✓ CSR reads show updated values (in trap handler)
# =============================================================================

.text
.globl _start

_start:
    # Load a recognizable value
    addi x2, x0, 42             # x2 = 0x2A (42 in decimal)

    # Trigger exception: ECALL (Environment Call)
    # This is a synchronous trap that transfers control to exception handler
    # mcause will be set to 11 (machine environment call)
    ecall                       # TRAP

    # If exception is handled and execution continues here:
    # (Depends on mtvec configuration)
    j _start                    # Hang / restart
