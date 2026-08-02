// ============================================================
// Instruction Decoder for CV32E40P Cache Testcases
// Purpose: Parse RISC-V instructions and generate synthetic
//          cache requests (LW, SW, ADDI, JAL)
// ============================================================

package instruction_decoder;

  typedef struct packed {
    logic [31:0] instr;
    logic [31:0] pc;
  } instr_t;

  typedef struct packed {
    logic valid;          // Request valid
    logic [31:0] addr;    // Memory address
    logic [31:0] wdata;   // Write data
    logic we;             // Write enable (1=SW, 0=LW)
    logic [3:0] be;       // Byte enable
  } cache_request_t;

  // ============================================================
  // RISC-V Instruction Field Extraction
  // ============================================================
  function logic [4:0] get_rd(logic [31:0] instr);
    return instr[11:7];
  endfunction

  function logic [4:0] get_rs1(logic [31:0] instr);
    return instr[19:15];
  endfunction

  function logic [4:0] get_rs2(logic [31:0] instr);
    return instr[24:20];
  endfunction

  function logic [11:0] get_imm_i(logic [31:0] instr);
    return instr[31:20];
  endfunction

  function logic [11:0] get_imm_s(logic [31:0] instr);
    return {instr[31:25], instr[11:7]};
  endfunction

  function logic [6:0] get_opcode(logic [31:0] instr);
    return instr[6:0];
  endfunction

  function logic [2:0] get_funct3(logic [31:0] instr);
    return instr[14:12];
  endfunction

  // ============================================================
  // Instruction Classifier
  // ============================================================
  function logic is_nop(logic [31:0] instr);
    // NOP = ADDI x0, x0, 0 (0x0000_0013)
    return (instr == 32'h0000_0013);
  endfunction

  function logic is_addi(logic [31:0] instr);
    // ADDI: opcode=0b001_0011
    return (get_opcode(instr) == 7'b001_0011);
  endfunction

  function logic is_lw(logic [31:0] instr);
    // LW: opcode=0b000_0011, funct3=0b010
    return (get_opcode(instr) == 7'b000_0011 && get_funct3(instr) == 3'b010);
  endfunction

  function logic is_sw(logic [31:0] instr);
    // SW: opcode=0b010_0011, funct3=0b010
    return (get_opcode(instr) == 7'b010_0011 && get_funct3(instr) == 3'b010);
  endfunction

  function logic is_jal(logic [31:0] instr);
    // JAL: opcode=0b110_1111
    return (get_opcode(instr) == 7'b110_1111);
  endfunction

  function logic is_fence(logic [31:0] instr);
    // FENCE: opcode=0b000_1111, funct3=0b000
    return (get_opcode(instr) == 7'b000_1111 && get_funct3(instr) == 3'b000);
  endfunction

  // ============================================================
  // Register File Simulator (for ADDI immediate loads)
  // ============================================================
  class RegFile;
    logic [31:0] regs[32];

    function new();
      for (int i = 0; i < 32; i++) regs[i] = 32'h0;
    endfunction

    function logic [31:0] read(logic [4:0] addr);
      return regs[addr];
    endfunction

    function void write(logic [4:0] addr, logic [31:0] data);
      if (addr != 0) regs[addr] = data;  // x0 is read-only
    endfunction

    function logic [31:0] get_imm_sext(logic [31:0] instr);
      // Sign-extend 12-bit immediate to 32-bit
      logic [11:0] imm = get_imm_i(instr);
      return {{20{imm[11]}}, imm};
    endfunction
  endclass

  // ============================================================
  // Cache Request Generator
  // ============================================================
  function cache_request_t decode_instruction(
    logic [31:0] instr,
    logic [31:0] pc,
    RegFile rf
  );
    cache_request_t req;
    logic [31:0] base_addr;
    logic [11:0] offset;
    logic [4:0] rd, rs1, rs2;
    logic [31:0] imm;

    req.valid = 1'b0;
    req.addr = 32'h0;
    req.wdata = 32'h0;
    req.we = 1'b0;
    req.be = 4'b1111;

    // Check instruction type
    if (is_nop(instr)) begin
      // NOP: no cache request
      req.valid = 1'b0;
    end
    else if (is_addi(instr)) begin
      // ADDI x_rd, x_rs1, imm
      // Simulates register load (no cache request)
      rd = get_rd(instr);
      rs1 = get_rs1(instr);
      imm = {{20{instr[31]}}, instr[31:20]};  // Sign-extend
      // Would update RF: regs[rd] = regs[rs1] + imm
      req.valid = 1'b0;  // No memory access
    end
    else if (is_lw(instr)) begin
      // LW x_rd, imm(x_rs1)
      // Cache load request
      rd = get_rd(instr);
      rs1 = get_rs1(instr);
      offset = get_imm_i(instr);
      base_addr = rf.read(rs1);
      req.addr = base_addr + {{20{offset[11]}}, offset};  // Sign-extend offset
      req.we = 1'b0;  // Read
      req.be = 4'b1111;  // Full word
      req.valid = 1'b1;
    end
    else if (is_sw(instr)) begin
      // SW x_rs2, imm(x_rs1)
      // Cache store request
      rs1 = get_rs1(instr);
      rs2 = get_rs2(instr);
      offset = get_imm_s(instr);
      base_addr = rf.read(rs1);
      req.addr = base_addr + {{20{offset[11]}}, offset};
      req.wdata = rf.read(rs2);
      req.we = 1'b1;  // Write
      req.be = 4'b1111;
      req.valid = 1'b1;
    end
    else if (is_jal(instr)) begin
      // JAL x_rd, imm
      // No cache request (control flow)
      req.valid = 1'b0;
    end
    else if (is_fence(instr)) begin
      // FENCE (memory barrier)
      req.valid = 1'b0;
    end

    return req;
  endfunction

endpackage
