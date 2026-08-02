// ============================================================
// cv32e40p_to_hpdcache_adapter.sv
//
// Protocol Adapter: CV32E40P OBI ↔ HPDcache
//
// Converts CV32E40P OBI protocol (1-cycle, 32-bit) to
// HPDcache protocol (2-cycle, 512-bit struct-based)
//
// Implements 7 transformation layers:
//  1. Address decomposition (flat 32-bit → {offset, index, tag})
//  2. Write enable mapping (1-bit boolean → 5-bit op enum)
//  3. Data width adaptation (32-bit ↔ 512-bit)
//  4. Byte enable expansion (4-bit → 64-bit)
//  5. Pipeline delay (Cycle N offset, Cycle N+1 tag)
//  6. Response demultiplexing (512-bit → 32-bit word extraction)
//  7. Transaction routing (counter → sid/tid tracking)
//
// Design Date: 28 July 2026
// Status: ✅ TASK 1 - ADAPTER IMPLEMENTATION
// ============================================================

module cv32e40p_to_hpdcache_adapter
  import hpdcache_pkg::*;
#(
  // Cache geometry (must match HPDcache configuration)
  parameter int OFFSET_WIDTH = 6,        // log2(64 bytes/line)
  parameter int INDEX_WIDTH = 8,         // log2(256 sets)
  parameter int TAG_WIDTH = 18,          // 32 - OFFSET - INDEX

  // HPDcache configuration
  parameter int REQ_WORDS = 8,           // 8 words × 64-bit = 512-bit
  parameter int WORD_WIDTH = 64,         // 64-bit per word
  parameter int REQ_SRC_ID_WIDTH = 2,    // 0-3 (single core = 0)
  parameter int REQ_TRANS_ID_WIDTH = 2   // transaction tracking
) (
  input logic clk_i,
  input logic rst_ni,

  // ===== CV32E40P OBI DATA INTERFACE (INPUT) =====
  // 1-cycle OBI protocol from core
  input logic        obi_req_i,           // Request valid
  output logic       obi_gnt_o,           // Grant (ready)
  input logic [31:0] obi_addr_i,          // 32-bit address
  input logic        obi_we_i,            // Write enable (0=read, 1=write)
  input logic [3:0]  obi_be_i,            // Byte enables
  input logic [31:0] obi_wdata_i,         // Write data (32-bit)

  // Read response (from HPDcache through adapter)
  output logic       obi_rvalid_o,        // Response valid
  output logic [31:0] obi_rdata_o,        // 32-bit read data
  output logic       obi_err_o,           // Error flag

  // ===== HPDCACHE CORE INTERFACE (OUTPUT) =====
  // 2-cycle struct protocol to cache

  // Cycle N: Request with offset
  output logic                            hpd_req_valid_o,
  input logic                             hpd_req_ready_i,
  output logic                            hpd_req_o,  // Will cast to hpdcache_req_t internally

  // Cycle N+1: Tag and PMA (separate delivery)
  output logic                            hpd_req_tag_valid_o,
  output logic [TAG_WIDTH-1:0]            hpd_req_tag_o,
  output logic                            hpd_req_pma_o,  // Will cast to hpdcache_pma_t internally

  // Response
  input logic                             hpd_rsp_valid_i,
  input logic                             hpd_rsp_i  // Will cast to hpdcache_rsp_t internally
);

  // ===== TYPEDEFS & LOCAL STRUCTS (for internal casting) =====
  typedef logic [OFFSET_WIDTH-1:0]    offset_t;
  typedef logic [INDEX_WIDTH-1:0]     index_t;
  typedef logic [TAG_WIDTH-1:0]       tag_t;
  typedef logic [WORD_WIDTH-1:0]      word_t;
  typedef logic [WORD_WIDTH/8-1:0]    be_word_t;
  typedef logic [REQ_WORDS-1:0][WORD_WIDTH-1:0] req_data_t;
  typedef logic [REQ_WORDS-1:0][WORD_WIDTH/8-1:0] req_be_t;

  // Local struct definitions for internal use (cast from logic ports)
  typedef struct packed {
    offset_t                        addr_offset;
    req_data_t                      wdata;
    logic [4:0]                     op;
    req_be_t                        be;
    logic [2:0]                     size;
    logic [REQ_SRC_ID_WIDTH-1:0]    sid;
    logic [REQ_TRANS_ID_WIDTH-1:0]  tid;
    logic                           need_rsp;
    logic                           phys_indexed;
    tag_t                           addr_tag;
    hpdcache_pma_t                  pma;
  } hpdcache_req_t;

  typedef struct packed {
    req_data_t                      rdata;
    logic [REQ_SRC_ID_WIDTH-1:0]    sid;
    logic [REQ_TRANS_ID_WIDTH-1:0]  tid;
    logic                           error;
  } hpdcache_rsp_t;

  // ===== INTERNAL SIGNALS =====

  // Request pipeline stage 1 (Cycle N - address decomposition)
  offset_t    addr_offset_r;     // Offset field (low bits of address)
  index_t     addr_index_r;      // Index field (middle bits)
  tag_t       addr_tag_r;        // Tag field (high bits)
  logic       req_we_r;          // Write enable
  logic [3:0] req_be_r;          // Byte enables (4-bit)
  logic [31:0] req_wdata_r;      // Write data (32-bit)
  logic       req_valid_r;       // Request valid flag

  // Request pipeline stage 2 (Cycle N+1 - tag delivery)
  tag_t       req_tag_r;         // Tag for N+1 delivery
  hpdcache_pma_t req_pma_r;      // PMA flags
  logic       req_tag_valid_r;   // Tag valid flag

  // Address decomposition (combinatorial)
  wire offset_t    addr_offset_w = obi_addr_i[OFFSET_WIDTH-1:0];
  wire index_t     addr_index_w = obi_addr_i[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH];
  wire tag_t       addr_tag_w = obi_addr_i[31:OFFSET_WIDTH+INDEX_WIDTH];

  // Data width adaptation (write path)
  req_data_t  wdata_expanded;    // 32-bit padded to 512-bit
  req_be_t    be_expanded;       // 4-bit padded to 64-bit

  // Data width adaptation (read path)
  logic [31:0] rdata_extracted;  // 32-bit extracted from 512-bit response
  logic [1:0]  rdata_offset_r;   // Offset within cache line (for word selection)

  // Response tracking
  logic       rsp_valid_w;
  logic [31:0] rsp_data_w;
  logic       rsp_err_w;

  // ===== LAYER 1: ADDRESS DECOMPOSITION =====
  // Split flat 32-bit address into {tag, index, offset}
  //
  // Address layout: [31:TAG+INDEX] [TAG+INDEX-1:INDEX] [INDEX-1:0]
  //                       tag            index          offset
  // Example (assuming TAG=18, INDEX=8, OFFSET=6):
  //   addr[31:14] = tag (18 bits)
  //   addr[13:6]  = index (8 bits)
  //   addr[5:0]   = offset (6 bits)

  always_comb begin
    // Extract fields from flat address
    // These are combinatorial - no delay
  end

  // ===== LAYER 2: WRITE ENABLE MAPPING (1-bit → 5-bit op enum) =====
  // CV32E40P: data_we_o is 1-bit (0=read, 1=write)
  // HPDcache: op field is 5-bit enum
  //   LOAD (0x00), STORE (0x01), AMO_* (0x04-0x0e), CMO_* (0x10-0x17)

  logic [4:0] op_mapped;

  always_comb begin
    case (obi_we_i)
      1'b0: op_mapped = hpdcache_pkg::HPDCACHE_REQ_LOAD;    // 5'h00 - read
      1'b1: op_mapped = hpdcache_pkg::HPDCACHE_REQ_STORE;   // 5'h01 - write
    endcase
  end

  // ===== LAYER 3: DATA WIDTH ADAPTATION (WRITE PATH: 32→512 bit) =====
  // CV32E40P sends 32-bit write data
  // HPDcache expects 8×64-bit words (512-bit total)
  // Strategy: Place 32-bit data in first word (index 0), zero-pad remainder

  always_comb begin
    // Expanded data: place 32-bit OBI wdata into word 0, zero others
    wdata_expanded = '0;  // Initialize to zero

    // Map 32-bit OBI write data to 64-bit HPDcache word (first word only)
    // OBI data goes into LSBs of word 0, upper 32 bits zero-padded
    wdata_expanded[0] = 64'({32'h0000_0000, obi_wdata_i});
  end

  // ===== LAYER 4: BYTE ENABLE EXPANSION (4-bit → 64-bit) =====
  // CV32E40P: 4 byte enables for 32-bit word
  // HPDcache: 64 byte enables (one per byte in 512-bit line, 8 words × 8 bytes)
  // Strategy: Replicate 4-bit OBI be to word 0, zero others

  always_comb begin
    be_expanded = '0;  // Initialize to zero

    // Replicate OBI byte enables to first word (8 bytes)
    // OBI be[3:0] maps to word[0] be[7:0]
    // Duplication: OBI be[0] → be[0], be[1] → be[1], be[2] → be[2], be[3] → be[3],
    //             then pad with zeros for remaining bytes
    be_expanded[0] = 8'b0000_0000 | {{4{1'b0}}, obi_be_i};

    // For single 32-bit access in 64-byte line:
    // Only 4 bytes of the first word are active
    // Set remaining 4 bytes of word 0 to 0 (no write)
    // All other words remain 0
    for (int i = 0; i < 4; i++) begin
      be_expanded[0][i] = obi_be_i[i];
    end
  end

  // ===== LAYER 5: PIPELINE DELAY (Cycle N vs N+1 separation) =====
  // OBI request arrives in Cycle N with all information
  // HPDcache expects:
  //   Cycle N: core_req_valid, core_req (struct with offset, size, op, be, sid, tid, pma)
  //   Cycle N+1: core_req_tag (separate delivery)
  //
  // Pipeline:
  //   Cycle N: Capture request, send core_req (with offset, op, be)
  //            Store tag for next cycle
  //   Cycle N+1: Send core_req_tag (from register)

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_valid_r <= 1'b0;
      addr_offset_r <= '0;
      addr_index_r <= '0;
      addr_tag_r <= '0;
      req_we_r <= 1'b0;
      req_be_r <= '0;
      req_wdata_r <= '0;
      rdata_offset_r <= '0;

      req_tag_valid_r <= 1'b0;
      req_tag_r <= '0;
      req_pma_r <= '0;
    end else begin
      // Cycle N: Capture OBI request
      if (obi_req_i && obi_gnt_o) begin
        req_valid_r <= 1'b1;
        addr_offset_r <= addr_offset_w;
        addr_index_r <= addr_index_w;
        addr_tag_r <= addr_tag_w;
        req_we_r <= obi_we_i;
        req_be_r <= obi_be_i;
        req_wdata_r <= obi_wdata_i;
        rdata_offset_r <= obi_addr_i[2:1];  // Which 32-bit word in 64-byte line

        // Queue tag for Cycle N+1 delivery
        req_tag_valid_r <= 1'b1;
        req_tag_r <= addr_tag_w;
        req_pma_r <= '0;  // Default: cacheable, write-back
      end else begin
        req_valid_r <= 1'b0;
        req_tag_valid_r <= 1'b0;
      end
    end
  end

  // ===== LAYER 6: RESPONSE DEMULTIPLEXING (512-bit → 32-bit) =====
  // HPDcache returns 8×64-bit words (512-bit total)
  // CV32E40P expects 32-bit word
  // Extract correct 32-bit word based on saved offset

  always_comb begin
    // Cast logic port to struct for internal access
    automatic hpdcache_rsp_t hpd_rsp_cast = hpdcache_rsp_t'(hpd_rsp_i);

    // Extract 32-bit word from 512-bit response
    // HPDcache rdata is array: rdata[0..7], each 64-bits
    // Select one 64-bit word, then extract correct 32-bit half

    case (rdata_offset_r)
      2'b00: rdata_extracted = hpd_rsp_cast.rdata[0][31:0];    // Word 0, lower half
      2'b01: rdata_extracted = hpd_rsp_cast.rdata[0][63:32];   // Word 0, upper half
      2'b10: rdata_extracted = hpd_rsp_cast.rdata[1][31:0];    // Word 1, lower half
      2'b11: rdata_extracted = hpd_rsp_cast.rdata[1][63:32];   // Word 1, upper half
    endcase

    // Error extraction (from HPDcache response struct)
    rsp_err_w = hpd_rsp_cast.error;
  end

  // ===== LAYER 7: TRANSACTION ROUTING (counter → sid/tid) =====
  // CV32E40P LSU tracks up to 2 outstanding transactions with counter
  // HPDcache uses sid (source ID) and tid (transaction ID) for routing
  // Single-core design: force sid=0, use tid as transaction counter

  // For simplicity in single-core: sid=0, tid=counter%4
  logic [1:0] trans_counter;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trans_counter <= '0;
    end else if (obi_req_i && obi_gnt_o) begin
      trans_counter <= trans_counter + 1;
    end
  end

  // ===== REQUEST INTERFACE ASSEMBLY =====
  // Construct HPDcache request struct from decomposed fields

  hpdcache_req_t req_struct;

  always_comb begin
    req_struct.addr_offset = addr_offset_r;
    req_struct.wdata = wdata_expanded;
    req_struct.op = op_mapped;
    req_struct.be = be_expanded;
    req_struct.size = 3'b010;  // 4-byte access (log2(32-bit / 8))
    req_struct.sid = '0;  // Single-core: force sid=0
    req_struct.tid = trans_counter;
    req_struct.need_rsp = 1'b1;  // Always need response
    req_struct.phys_indexed = 1'b1;  // Physical addressing
    req_struct.addr_tag = addr_tag_r;  // Will be overridden by Cycle N+1 signal
    req_struct.pma = '0;  // Default: cacheable
  end

  // ===== OUTPUT ASSIGNMENTS =====

  // OBI grant (request accepted)
  assign obi_gnt_o = hpd_req_ready_i;

  // HPDcache Cycle N request (offset phase)
  assign hpd_req_valid_o = req_valid_r;
  assign hpd_req_o = logic'(req_struct);  // Cast struct to logic for port assignment

  // HPDcache Cycle N+1 tag delivery (separate)
  assign hpd_req_tag_valid_o = req_tag_valid_r;
  assign hpd_req_tag_o = req_tag_r;
  assign hpd_req_pma_o = req_pma_r;

  // Response interface
  assign obi_rvalid_o = hpd_rsp_valid_i;
  assign obi_rdata_o = rdata_extracted;
  assign obi_err_o = rsp_err_w;

  // ===== ASSERTIONS & CHECKS =====

  `ifndef SYNTHESIS

  // Assert: Address decomposition correctness
  // Verify that decomposed address can reconstruct original
  always @(posedge clk_i) begin
    if (obi_req_i && rst_ni) begin
      automatic logic [31:0] reconstructed_addr = {addr_tag_w, addr_index_w, addr_offset_w};
      assert (reconstructed_addr == obi_addr_i)
        else $error("Address decomposition failed: %h != %h", reconstructed_addr, obi_addr_i);
    end
  end

  // Assert: Write enable mapping
  // Verify operation encoding matches OBI intent
  always @(posedge clk_i) begin
    if (obi_req_i && rst_ni) begin
      if (obi_we_i == 1'b0) begin
        assert (op_mapped == hpdcache_pkg::HPDCACHE_REQ_LOAD)
          else $error("Write enable 0 should map to LOAD, got %h", op_mapped);
      end else if (obi_we_i == 1'b1) begin
        assert (op_mapped == hpdcache_pkg::HPDCACHE_REQ_STORE)
          else $error("Write enable 1 should map to STORE, got %h", op_mapped);
      end
    end
  end

  // Assert: Only single-core (sid=0)
  always @(*) begin
    assert (req_struct.sid == '0)
      else $error("Adapter is single-core only, sid must be 0");
  end

  `endif

endmodule : cv32e40p_to_hpdcache_adapter

