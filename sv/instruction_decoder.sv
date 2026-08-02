// ============================================================
// instruction_decoder.sv
//
// RISC-V 32-bit Instruction Decoder for CV32E40P Test Generation
//
// Decodes RISC-V base ISA instructions for UVM test sequences.
// Supports: LW, SW, ADDI, JAL, BEQ, BNE, FENCE.I
//
// Design Date: 30 July 2026
// Status: Phase 1 - Foundation
// ============================================================

module instruction_decoder
  import hpdcache_pkg::*;
#(
  // Address width (CV32E40P: 32-bit)
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned INSTR_WIDTH = 32
);

  // ===== INPUTS =====
  logic [INSTR_WIDTH-1:0] instr_i;      // 32-bit instruction
  logic                   valid_i;       // Instruction valid

  // ===== OUTPUTS - DECODED FIELDS =====
  // Opcode and format detection
  logic [6:0]  opcode_o;                // bits [6:0]
  logic [2:0]  funct3_o;                // bits [14:12]
  logic [6:0]  funct7_o;                // bits [31:25]

  // Register fields
  logic [4:0]  rd_o;                    // bits [11:7] - destination
  logic [4:0]  rs1_o;                   // bits [19:15] - source 1
  logic [4:0]  rs2_o;                   // bits [24:20] - source 2

  // Immediate values (sign-extended)
  logic [ADDR_WIDTH-1:0] imm_i_ext_o;   // I-type immediate (12-bit → 32-bit)
  logic [ADDR_WIDTH-1:0] imm_s_ext_o;   // S-type immediate (12-bit → 32-bit)
  logic [ADDR_WIDTH-1:0] imm_b_ext_o;   // B-type immediate (12-bit → 32-bit)
  logic [ADDR_WIDTH-1:0] imm_j_ext_o;   // J-type immediate (20-bit → 32-bit)

  // Decoded instruction type flags
  logic is_load_o;                      // LW, LH, LB, etc.
  logic is_store_o;                     // SW, SH, SB, etc.
  logic is_branch_o;                    // BEQ, BNE, BLT, etc.
  logic is_jal_o;                       // JAL instruction
  logic is_jalr_o;                      // JALR instruction
  logic is_addi_o;                      // ADDI instruction
  logic is_fence_o;                     // FENCE.I instruction
  logic is_amo_o;                       // Atomic memory operation
  logic is_valid_o;                     // Valid instruction

  // Calculated addresses/values
  logic [ADDR_WIDTH-1:0] target_addr_o; // JAL/branch target

  // Error flags
  logic invalid_opcode_o;               // Unknown opcode

  // ===== INTERNAL SIGNALS =====
  logic [ADDR_WIDTH-1:0] pc_i;          // Program counter for target calculation

  // ===== DECODE LOGIC =====

  always_comb begin
    // Default assignments
    opcode_o        = instr_i[6:0];
    funct3_o        = instr_i[14:12];
    funct7_o        = instr_i[31:25];
    rd_o            = instr_i[11:7];
    rs1_o           = instr_i[19:15];
    rs2_o           = instr_i[24:20];
    is_valid_o      = valid_i;
    invalid_opcode_o = 1'b0;

    // ===== IMMEDIATE DECODING WITH SIGN EXTENSION =====

    // I-type immediate (bits [31:20], sign-extended)
    // Used by: LW, ADDI, FENCE.I
    imm_i_ext_o = {{20{instr_i[31]}}, instr_i[31:20]};

    // S-type immediate (bits [31:25,11:7], sign-extended)
    // Used by: SW, SH, SB
    imm_s_ext_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

    // B-type immediate (bits [31,7,30:25,11:8], sign-extended, ×2)
    // Used by: BEQ, BNE, BLT
    imm_b_ext_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

    // J-type immediate (bits [31,19:12,20,30:21], sign-extended, ×2)
    // Used by: JAL
    imm_j_ext_o = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

    // ===== INSTRUCTION TYPE CLASSIFICATION =====
    case (opcode_o)
      7'b0000011: begin  // LOAD (LW, LH, LB, etc.)
        is_load_o  = 1'b1;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b0100011: begin  // STORE (SW, SH, SB, etc.)
        is_load_o  = 1'b0;
        is_store_o = 1'b1;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b1100011: begin  // BRANCH (BEQ, BNE, BLT, etc.)
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b1;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b1101111: begin  // JAL
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b1;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b1100111: begin  // JALR
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b1;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b0010011: begin  // ADDI (and other immediate ALU)
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b1;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
      end

      7'b0001111: begin  // FENCE / FENCE.I
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b1;  // FENCE.I for I-cache coherency
        is_amo_o   = 1'b0;
      end

      7'b0101111: begin  // AMO (Atomic Memory Operations)
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b1;
      end

      default: begin
        is_load_o  = 1'b0;
        is_store_o = 1'b0;
        is_branch_o = 1'b0;
        is_jal_o   = 1'b0;
        is_jalr_o  = 1'b0;
        is_addi_o  = 1'b0;
        is_fence_o = 1'b0;
        is_amo_o   = 1'b0;
        invalid_opcode_o = 1'b1;
      end
    endcase
  end

  // ===== TARGET ADDRESS CALCULATION =====
  // Used for JAL and conditional branches
  assign target_addr_o = pc_i + (is_jal_o ? imm_j_ext_o : imm_b_ext_o);

  // ===== HELPER FUNCTIONS FOR TEST SEQUENCES =====

  // Get immediate value (I-type, S-type, etc.) based on instruction type
  function automatic logic [ADDR_WIDTH-1:0] get_immediate();
    if (is_load_o || is_addi_o || is_fence_o)
      return imm_i_ext_o;
    else if (is_store_o)
      return imm_s_ext_o;
    else if (is_branch_o)
      return imm_b_ext_o;
    else if (is_jal_o)
      return imm_j_ext_o;
    else
      return '0;
  endfunction

  // Get base register for memory operations
  function automatic logic [4:0] get_base_reg();
    return rs1_o;  // Base address comes from rs1
  endfunction

  // Get offset for LW/SW instructions
  function automatic logic [ADDR_WIDTH-1:0] get_mem_offset();
    if (is_load_o || is_store_o)
      return imm_i_ext_o;  // Both LW and SW use I-type encoding for offset
    else
      return '0;
  endfunction

  // Calculate memory address (base + offset)
  function automatic logic [ADDR_WIDTH-1:0] calculate_mem_address(
    logic [ADDR_WIDTH-1:0] base_addr
  );
    return base_addr + get_mem_offset();
  endfunction

  // Get JAL target address
  function automatic logic [ADDR_WIDTH-1:0] get_jal_target(
    logic [ADDR_WIDTH-1:0] current_pc
  );
    return current_pc + imm_j_ext_o;
  endfunction

  // Get branch target address
  function automatic logic [ADDR_WIDTH-1:0] get_branch_target(
    logic [ADDR_WIDTH-1:0] current_pc
  );
    return current_pc + imm_b_ext_o;
  endfunction

  // Check if instruction is a fence operation
  function automatic logic is_fence_i();
    return is_fence_o && (funct3_o == 3'b001);  // FENCE.I has funct3 = 1
  endfunction

  // ===== ASSERTION CHECKS =====
  // NOTE: Questa FSE doesn't support unclocked SVA assertions.
  // These assertions would need clock context from testbench to function.
  // Keeping them commented for reference; enable when using full QuestaSim.

  // // Assert: valid instructions decode properly
  // assert property (valid_i -> is_valid_o)
  //   else $error("Valid input must result in valid output");

  // // Assert: only one instruction type should be true at a time
  // assert property (valid_i ->
  //   ((is_load_o ? 1 : 0) +
  //    (is_store_o ? 1 : 0) +
  //    (is_branch_o ? 1 : 0) +
  //    (is_jal_o ? 1 : 0) +
  //    (is_jalr_o ? 1 : 0) +
  //    (is_addi_o ? 1 : 0) +
  //    (is_fence_o ? 1 : 0) +
  //    (is_amo_o ? 1 : 0)) <= 1)
  //   else $error("Multiple instruction types decoded simultaneously");

endmodule : instruction_decoder

// ============================================================
// CLASS WRAPPER FOR UVM TEST SEQUENCES
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
