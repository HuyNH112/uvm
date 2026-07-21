# =============================================================================
# prog_alu.s — TC 1.1: Basic ALU Operations
# =============================================================================
# Test ALU instructions: ADD, AND, OR, XOR, then trap with ECALL
# 
# Execution trace (expected):
#   PC=0x00: ADD x2, x0, 1        → x2 = 1
#   PC=0x04: ADD x3, x0, 2        → x3 = 2
#   PC=0x08: AND x6, x2, x3       → x6 = 1 AND 2 = 0
#   PC=0x0C: OR x7, x2, x3        → x7 = 1 OR 2 = 3
#   PC=0x10: XOR x8, x2, x3       → x8 = 1 XOR 2 = 3
#   PC=0x14: ECALL                → Trap, mcause=11 (Environment call)
#
# RVFI expected commits: 6
#   [0] ADD x2,x0,1          rd_addr=2 rd_wdata=0x1
#   [1] ADD x3,x0,2          rd_addr=3 rd_wdata=0x2
#   [2] AND x6,x2,x3         rd_addr=6 rd_wdata=0x0
#   [3] OR x7,x2,x3          rd_addr=7 rd_wdata=0x3
#   [4] XOR x8,x2,x3         rd_addr=8 rd_wdata=0x3
#   [5] ECALL                exception_valid=1, mcause=11
#
# Verification:
#   ✓ Commit monitor captures 6 events
#   ✓ Destination register values correct
#   ✓ Exception triggered on ECALL
# =============================================================================

.text
.globl _start

_start:
    # ALU Test 1: ADD
    addi x2, x0, 1              # x2 = 1

    # ALU Test 2: ADD (different operand)
    addi x3, x0, 2              # x3 = 2

    # ALU Test 3: AND
    and x6, x2, x3              # x6 = 0x1 & 0x2 = 0x0

    # ALU Test 4: OR
    or x7, x2, x3               # x7 = 0x1 | 0x2 = 0x3

    # ALU Test 5: XOR
    xor x8, x2, x3              # x8 = 0x1 ^ 0x2 = 0x3

    # Trap: Environment call
    ecall                       # Exception: mcause = 11 (ECALL)

    # Hang (should not reach)
    j _start
