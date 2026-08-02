// ============================================================
// instruction_decoder_seq.sv - UVM Class Wrapper
// CLASS WRAPPER FOR UVM TEST SEQUENCES
// Extracted from instruction_decoder.sv for package inclusion
// ============================================================
`ifndef INSTRUCTION_DECODER_SEQ_SV
`define INSTRUCTION_DECODER_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
class instruction_decoder_seq extends uvm_object;
  `uvm_object_utils(instruction_decoder_seq)

  logic [31:0] instruction;
  logic [31:0] pc;

  function new(string name = "");
    super.new(name);
  endfunction

  // Generate LW instruction: LW rd, offset(rs1)
  // Encoding: I-type opcode 0x03
  function logic [31:0] gen_lw(int unsigned rd, int unsigned rs1, logic signed [11:0] offset);
    logic [31:0] instr;
    instr[6:0]   = 7'b0000011;      // LOAD opcode
    instr[14:12] = 3'b010;          // funct3 for word (32-bit)
    instr[11:7]  = rd;              // destination register
    instr[19:15] = rs1;             // base address register
    instr[31:20] = offset;          // offset (sign-extended by decoder)
    return instr;
  endfunction

  // Generate SW instruction: SW rs2, offset(rs1)
  // Encoding: S-type opcode 0x23
  function logic [31:0] gen_sw(int unsigned rs2, int unsigned rs1, logic signed [11:0] offset);
    logic [31:0] instr;
    instr[6:0]   = 7'b0100011;      // STORE opcode
    instr[14:12] = 3'b010;          // funct3 for word (32-bit)
    instr[11:7]  = offset[4:0];     // lower 5 bits of offset
    instr[19:15] = rs1;             // base address register
    instr[24:20] = rs2;             // source data register
    instr[31:25] = offset[11:5];    // upper 7 bits of offset
    return instr;
  endfunction

  // Generate JAL instruction: JAL rd, target_offset
  // Encoding: J-type opcode 0x6F
  function logic [31:0] gen_jal(int unsigned rd, logic signed [20:0] offset);
    logic [31:0] instr;
    logic [20:0] imm = offset >> 1;  // JAL offset is in 2-byte units
    instr[6:0]   = 7'b1101111;      // JAL opcode
    instr[11:7]  = rd;              // return address register
    instr[19:12] = imm[10:3];       // imm[10:3]
    instr[20]    = imm[11];         // imm[11]
    instr[30:21] = imm[19:10];      // imm[19:10]
    instr[31]    = imm[20];         // imm[20]
    return instr;
  endfunction

  // Generate BEQ instruction: BEQ rs1, rs2, target_offset
  // Encoding: B-type opcode 0x63
  function logic [31:0] gen_beq(int unsigned rs1, int unsigned rs2, logic signed [12:0] offset);
    logic [31:0] instr;
    logic [12:0] imm = offset >> 1;  // Branch offset is in 2-byte units
    instr[6:0]   = 7'b1100011;      // BRANCH opcode
    instr[14:12] = 3'b000;          // funct3 for BEQ
    instr[19:15] = rs1;             // source register 1
    instr[24:20] = rs2;             // source register 2
    instr[11:7]  = {imm[4:1], imm[11]};  // imm[4:1|11]
    instr[31:25] = {imm[12], imm[10:5]}; // imm[12|10:5]
    return instr;
  endfunction

  // Generate BNE instruction: BNE rs1, rs2, target_offset
  // Encoding: B-type opcode 0x63 with funct3 = 1
  function logic [31:0] gen_bne(int unsigned rs1, int unsigned rs2, logic signed [12:0] offset);
    logic [31:0] instr;
    logic [12:0] imm = offset >> 1;
    instr[6:0]   = 7'b1100011;      // BRANCH opcode
    instr[14:12] = 3'b001;          // funct3 for BNE
    instr[19:15] = rs1;
    instr[24:20] = rs2;
    instr[11:7]  = {imm[4:1], imm[11]};
    instr[31:25] = {imm[12], imm[10:5]};
    return instr;
  endfunction

  // Generate ADDI instruction: ADDI rd, rs1, immediate
  // Encoding: I-type opcode 0x13
  function logic [31:0] gen_addi(int unsigned rd, int unsigned rs1, logic signed [11:0] imm);
    logic [31:0] instr;
    instr[6:0]   = 7'b0010011;      // ADDI opcode
    instr[14:12] = 3'b000;          // funct3 for add
    instr[11:7]  = rd;              // destination register
    instr[19:15] = rs1;             // source register
    instr[31:20] = imm;             // immediate
    return instr;
  endfunction

  // Generate FENCE.I instruction
  // Encoding: I-type opcode 0x0F with funct3 = 1
  function logic [31:0] gen_fence_i();
    logic [31:0] instr;
    instr[6:0]   = 7'b0001111;      // FENCE opcode
    instr[14:12] = 3'b001;          // funct3 for FENCE.I
    instr[11:7]  = 5'b0;            // rd (ignored)
    instr[19:15] = 5'b0;            // rs1 (ignored)
    instr[31:20] = 12'b0;           // imm (ignored)
    return instr;
  endfunction

endclass : instruction_decoder_seq

`endif // INSTRUCTION_DECODER_SEQ_SV
