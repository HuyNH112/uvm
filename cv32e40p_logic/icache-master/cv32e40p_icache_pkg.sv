// ============================================================
// cv32e40p_icache_pkg.sv
// 
// Package definition for CV32E40P I-Cache
// Contains:
//   - Parameters
//   - Type definitions
//   - Helper functions
//
// Design Date: July 27, 2026
// Status: [PLACEHOLDER - TO BE IMPLEMENTED]
// ============================================================

package cv32e40p_icache_pkg;

  // ===== CACHE PARAMETERS =====
  parameter int ICACHE_SIZE        = 16384;      // 16 KB total
  parameter int ICACHE_LINE_SIZE   = 64;         // 64 bytes per line
  parameter int ICACHE_WAYS        = 4;          // 4-way associative
  parameter int ICACHE_SETS        = ICACHE_SIZE / (ICACHE_LINE_SIZE * ICACHE_WAYS);  // 64 sets
  
  // Derived parameters
  parameter int ICACHE_ADDR_WIDTH     = 32;
  parameter int ICACHE_DATA_WIDTH     = 256;     // 4 x 64-bit words
  parameter int ICACHE_TAG_WIDTH      = 32 - $clog2(ICACHE_LINE_SIZE) - $clog2(ICACHE_SETS);
  parameter int ICACHE_INDEX_WIDTH    = $clog2(ICACHE_SETS);
  parameter int ICACHE_OFFSET_WIDTH   = $clog2(ICACHE_LINE_SIZE);
  parameter int ICACHE_WAY_WIDTH      = $clog2(ICACHE_WAYS);

  // ===== TYPE DEFINITIONS =====
  
  // Fetch Request (from CV32E40P core via OBI)
  typedef struct packed {
    logic [31:0]  addr;      // Fetch address
    logic         valid;     // Request valid
  } dreq_t;
  
  // Fetch Response (to CV32E40P core via OBI)
  typedef struct packed {
    logic [31:0]  data;      // Instruction data (32-bit from 256-bit line)
    logic         valid;     // Data valid
  } drsp_t;
  
  // Memory Request (to adapter/memory on miss)
  typedef struct packed {
    logic [31:0]  addr;      // Miss address
    logic [7:0]   len;       // Burst length (3 for 4-beat)
    logic [2:0]   size;      // Beat size (3 for 64-bit)
  } mem_req_t;
  
  // Memory Response (from memory on refill)
  typedef struct packed {
    logic [255:0] data;      // Cache line data (4 x 64-bit)
    logic         last;      // Last beat flag
    logic         valid;     // Data valid
  } mem_rsp_t;

  // ===== HELPER FUNCTIONS =====
  
  // Binary to One-Hot conversion
  function automatic logic [ICACHE_WAYS-1:0] bin2oh(input logic [ICACHE_WAY_WIDTH-1:0] in);
    logic [ICACHE_WAYS-1:0] out;
    out = '0;
    if (in < ICACHE_WAYS) out[in] = 1'b1;
    return out;
  endfunction
  
  // One-Hot to Binary conversion
  function automatic logic [ICACHE_WAY_WIDTH-1:0] oh2bin(input logic [ICACHE_WAYS-1:0] in);
    for (int i = 0; i < ICACHE_WAYS; i++) begin
      if (in[i]) return i;
    end
    return '0;
  endfunction
  
  // Bit width calculator
  function automatic int clog2(int n);
    int width = 0;
    int temp = n - 1;
    if (n <= 1) return 0;
    while (temp > 0) begin
      width++;
      temp = temp >> 1;
    end
    return width;
  endfunction

endpackage : cv32e40p_icache_pkg
