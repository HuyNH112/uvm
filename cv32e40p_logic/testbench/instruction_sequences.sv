// ============================================================
// Instruction Sequences for CV32E40P Cache Testcases
// Machine code in hex format (32-bit RISC-V instructions)
// ============================================================

// RISC-V RV32I Instruction Format Reference:
// NOP:  0x0000_0013 (ADDI x0, x0, 0)
// JAL:  0x0062_F0EF (JAL x1, offset) - Jump to new cache line
// ADDI: 0x0080_0093 (ADDI x1, x0, 8)
// LW:   0x0000_2083 (LW x1, 0(x0))
// SW:   0x0040_0023 (SW x1, 0(x0))

package instruction_sequences;

  // ============================================================
  // TC-INT-01: Boot + 32 Sequential NOPs (BASELINE)
  // Cache line @ 0x8000_0000: [NOP, NOP, NOP, NOP, NOP, NOP, NOP, NOP]
  // ============================================================
  localparam logic [255:0] TC_INT_01_LINE = {
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013,
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013
  };

  // ============================================================
  // TC-I-02: I-Cache Cold Miss via OBI Burst
  // Boot @ 0x8000_0000 (Line A: NOPs)
  // Jump to 0x8001_0000 (Line B: NOPs) → triggers 4-beat AXI burst
  // ============================================================
  // Line A @ 0x8000_0000 (8 words = 256 bits)
  localparam logic [255:0] TC_I_02_LINE_A = {
    32'h0000_1067, // JAL x0, 0x10000 (jump to 0x8001_0000)
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

  // Line B @ 0x8001_0000 (8 NOPs)
  localparam logic [255:0] TC_I_02_LINE_B = {
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013,
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013
  };

  // ============================================================
  // TC-I-03: I-Cache Mixed Hit/Miss with PLRU
  // Pattern: fetch L1, fetch L1 (hit), fetch L1 (hit),
  //          jump to L2 (miss), fetch L2 (hit)
  // ============================================================
  // Line 1 @ 0x8000_0000
  localparam logic [255:0] TC_I_03_LINE_1 = {
    32'h0000_0013, // Word 0
    32'h0000_0013, // Word 1
    32'h0000_2067, // JAL x0, 0x2000 (jump to 0x8002_0000)
    32'h0000_0013,
    32'h0000_0013,
    32'h0000_0013,
    32'h0000_0013,
    32'h0000_0013
  };

  // Line 2 @ 0x8002_0000
  localparam logic [255:0] TC_I_03_LINE_2 = {
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013,
    32'h0000_0013, 32'h0000_0013, 32'h0000_0013, 32'h0000_0013
  };

  // ============================================================
  // TC-D-01: D-Cache STORE → LOAD Hit
  // ADDI x1, x0, 0xABCD (load immediate)
  // SW x1, 0(x2) (store to 0x9000_0000)
  // LW x3, 0(x2) (load from same address → cache hit)
  // ============================================================
  localparam logic [255:0] TC_D_01_PROGRAM = {
    32'hABCD_0093, // ADDI x1, x0, -21555 (0xABCD as signed immediate)
    32'h0001_0113, // ADDI x2, x0, 0 (x2 = 0 for base address)
    32'h0010_2023, // SW x1, 0(x2) (write to 0x9000_0000)
    32'h0010_2083, // LW x3, 0(x2) (read from 0x9000_0000)
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

  // ============================================================
  // TC-D-02: D-Cache Cold Miss + OBI Stall
  // LW x1, 0x9100_0000 (first load, cache cold → stall)
  // LW x2, 0x9100_0004 (next load → may still be refilling)
  // ============================================================
  localparam logic [255:0] TC_D_02_PROGRAM = {
    32'h00002083, // LW x1, 0(x0) (load @ offset 0)
    32'h00402103, // LW x2, 4(x0) (load @ offset 4)
    32'h00002183, // LW x3, 0(x0) (repeat load)
    32'h00002203, // LW x4, 0(x0)
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

  // ============================================================
  // TC-D-03: D-Cache Write-Back + CMO Flush
  // Configure write-back mode (via CSR, placeholder)
  // SW x1, 0(x0) (store to buffer)
  // SW x2, 8(x0) (store another)
  // FENCE or CMO.FLUSH (placeholder: use ECALL)
  // ============================================================
  localparam logic [255:0] TC_D_03_PROGRAM = {
    32'h00002023, // SW x0, 0(x0) (write-through store)
    32'h00802223, // SW x0, 4(x0) (write-through store)
    32'h0000100F, // FENCE (memory barrier - CMO placeholder)
    32'h00000073, // ECALL (placeholder for CMO.FLUSH)
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

  // ============================================================
  // TC-PF-01: Domino Prefetch Stride Detect
  // Load @ 0x9100_0000, 0x9100_0100, 0x9100_0200 (stride +0x100)
  // Then prefetch should predict 0x9100_0300
  // ============================================================
  localparam logic [255:0] TC_PF_01_PROGRAM = {
    32'h00002083, // LW x1, 0(x0)       @ 0x9100_0000
    32'h10002183, // LW x2, 0x100(x0)   @ 0x9100_0100
    32'h20002283, // LW x3, 0x200(x0)   @ 0x9100_0200
    32'h30002383, // LW x4, 0x300(x0)   @ 0x9100_0300 (prefetch hit expected)
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

  // ============================================================
  // TC-PF-02: Miss Rate Reduction (Prefetch ON vs OFF)
  // Same as TC-PF-01 but run twice: once without, once with prefetch
  // ============================================================
  localparam logic [255:0] TC_PF_02_PROGRAM = TC_PF_01_PROGRAM;

  // ============================================================
  // TC-INT-02: Full L1 Stack (I+D Cache + Domino + OBI)
  // Mixed load/store/fetch workload
  // ============================================================
  localparam logic [255:0] TC_INT_02_PROGRAM = {
    32'h00002083, // LW x1, 0(x0)       (D-Cache load)
    32'h00402103, // LW x2, 4(x0)       (D-Cache load)
    32'h00202023, // SW x1, 0(x0)       (D-Cache store)
    32'h00302223, // SW x2, 4(x0)       (D-Cache store)
    32'h00002283, // LW x3, 0(x0)       (prefetch candidate)
    32'h10002383, // LW x4, 0x100(x0)   (stride load)
    32'h0000_0013, // NOP
    32'h0000_0013  // NOP
  };

endpackage
