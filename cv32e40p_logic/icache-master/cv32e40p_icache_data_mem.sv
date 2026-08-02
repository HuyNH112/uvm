// ============================================================
// cv32e40p_icache_data_mem.sv
//
// Data memory array for CV32E40P I-Cache
// - 4-way associative
// - 64 sets per way
// - Data width: 256 bits (4 x 64-bit words per cache line)
//
// Ports:
//   - Read port (combinatorial, all ways)
//   - Write port (synchronous, per-way)
//
// Status: [PLACEHOLDER - TO BE IMPLEMENTED]
// ============================================================

module cv32e40p_icache_data_mem
  import cv32e40p_icache_pkg::*;
#(
  parameter int DEPTH      = ICACHE_SETS,         // 64
  parameter int WAYS       = ICACHE_WAYS,         // 4
  parameter int DATA_WIDTH = ICACHE_DATA_WIDTH    // 256
) (
  input logic clk_i,
  input logic rst_ni,

  // Read port (combinatorial)
  input logic [ICACHE_INDEX_WIDTH-1:0] raddr_i,
  output logic [DATA_WIDTH-1:0] rdata_o [WAYS-1:0],

  // Write port (synchronous)
  input logic wen_i,
  input logic [WAYS-1:0] wsel_i,
  input logic [ICACHE_INDEX_WIDTH-1:0] waddr_i,
  input logic [DATA_WIDTH-1:0] wdata_i
);

  // Data memory array (4 ways x 64 sets x 256 bits)
  logic [DATA_WIDTH-1:0] data_mem [WAYS-1:0] [DEPTH-1:0];
  
  // ===== READ PORT (Combinatorial) =====
  // Read from all ways simultaneously
  always_comb begin
    for (int w = 0; w < WAYS; w++) begin
      rdata_o[w] = data_mem[w][raddr_i];
    end
  end
  
  // ===== WRITE PORT (Synchronous) =====
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Reset: clear all data
      for (int w = 0; w < WAYS; w++) begin
        for (int s = 0; s < DEPTH; s++) begin
          data_mem[w][s] <= '0;
        end
      end
    end else if (wen_i) begin
      // Write: update selected ways
      for (int w = 0; w < WAYS; w++) begin
        if (wsel_i[w]) begin
          data_mem[w][waddr_i] <= wdata_i;
        end
      end
    end
  end

endmodule : cv32e40p_icache_data_mem
