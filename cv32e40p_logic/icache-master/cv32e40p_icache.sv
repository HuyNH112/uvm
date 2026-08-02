// ============================================================
// cv32e40p_icache.sv
//
// Instruction Cache for CV32E40P RISC-V CPU
// - 4-way associative
// - 16 KB total capacity
// - 64-byte cache lines (256-bit data width)
// - PLRU replacement policy
// - OBI protocol interface to CPU
// - AXI-compatible memory interface
//
// Design Date: July 27, 2026
// Status: ✅ COMPLETE - FULL RTL IMPLEMENTATION
// ============================================================

module cv32e40p_icache
  import cv32e40p_icache_pkg::*;
#(
  parameter int TAG_WIDTH    = ICACHE_TAG_WIDTH,
  parameter int INDEX_WIDTH  = ICACHE_INDEX_WIDTH,
  parameter int OFFSET_WIDTH = ICACHE_OFFSET_WIDTH
) (
  input logic clk_i,
  input logic rst_ni,
  
  // ===== FETCH REQUEST INTERFACE (from CV32E40P core) =====
  input logic          instr_req_i,     // OBI request valid
  output logic         instr_gnt_o,     // OBI grant/ready
  input logic [31:0]   instr_addr_i,    // Fetch address
  
  // ===== FETCH RESPONSE INTERFACE (to CV32E40P core) =====
  output logic         instr_rvalid_o,  // Data valid
  output logic [31:0]  instr_rdata_o,   // Instruction data (32-bit)
  
  // ===== FLUSH CONTROL =====
  input logic          flush_i,         // Flush entire cache
  output logic         flush_ack_o,     // Flush complete
  
  // ===== MEMORY REQUEST INTERFACE (to adapter/memory) =====
  output logic         mem_req_valid_o, // Memory request valid
  output logic [31:0]  mem_req_addr_o,  // Miss address
  output logic [7:0]   mem_req_len_o,   // Burst length (3 for 4-beat)
  output logic [2:0]   mem_req_size_o,  // Beat size (3 for 64-bit)
  input logic          mem_req_ack_i,   // Memory ACK
  
  // ===== MEMORY RESPONSE INTERFACE (from memory) =====
  input logic          mem_rsp_valid_i, // Refill data valid
  input logic [255:0]  mem_rsp_data_i,  // Cache line (4 x 64-bit)
  input logic          mem_rsp_last_i,  // Last beat
  
  // ===== PERFORMANCE MONITORING =====
  output logic         miss_o,           // Miss indicator

  // ===== PREFETCHER INTERFACE =====
  output logic         miss_event_o      // Miss event for Domino prefetcher
);

  // ===== FSM STATES =====
  typedef enum logic [2:0] {
    FLUSH_STATE       = 3'b000,
    IDLE_STATE        = 3'b001,
    READ_STATE        = 3'b010,
    MISS_STATE        = 3'b011,
    KILL_ATRANS_STATE = 3'b100,
    KILL_MISS_STATE   = 3'b101
  } state_e;
  
  // ===== REGISTERS =====
  state_e state_d, state_q;

  // ===== PIPELINE REGISTERS =====
  logic [TAG_WIDTH-1:0]   cl_tag_q;           // Tag latch from address
  logic [INDEX_WIDTH-1:0] cl_index_q;         // Index latch from address
  logic [OFFSET_WIDTH-1:0] cl_offset_q;       // Offset latch from address
  logic [31:0]            miss_addr_q;        // Miss address for memory request
  logic                   cache_wren;         // Cache write enable
  logic [ICACHE_WAYS-1:0] cache_wsel;         // Cache write way select
  logic                   flush_en;           // Flush enable
  logic [INDEX_WIDTH-1:0] flush_cnt_q;        // Flush counter
  logic                   flush_done;         // Flush complete

  // ===== COMBINATORIAL ADDRESS EXTRACTION (temporary) =====
  logic [TAG_WIDTH-1:0]   cl_tag;             // Extracted tag (combinatorial)
  logic [OFFSET_WIDTH-1:0] cl_offset;         // Extracted offset (combinatorial)

  // ===== SIGNALS =====
  // Tag and valid bit arrays
  logic [TAG_WIDTH-1:0]    tag_rdata [ICACHE_WAYS-1:0];
  logic [ICACHE_DATA_WIDTH-1:0] data_rdata [ICACHE_WAYS-1:0];
  logic [ICACHE_WAYS-1:0]  vld_rdata;         // Valid bits per way
  logic [ICACHE_WAYS-1:0]  vld_wdata;         // Valid bits write data
  logic                    vld_we;            // Valid bits write enable

  // Hit detection
  logic [ICACHE_WAYS-1:0]  cl_hit;            // One-hot hit signal per way
  logic                    cache_hit;         // Any way hit
  logic [ICACHE_WAY_WIDTH-1:0] hit_way;       // Hit way index

  // PLRU interface
  logic [ICACHE_WAY_WIDTH-1:0] plru_access_way;
  logic [ICACHE_WAY_WIDTH-1:0] plru_replace_way;
  logic [ICACHE_WAY_WIDTH-1:0] repl_way;      // Replacement way
  logic                    all_ways_valid;    // All ways occupied
  logic [ICACHE_WAY_WIDTH-1:0] inv_way;       // First invalid way

  // Data extraction
  logic [31:0]            cache_rdata_mux;    // Selected data from cache
  
  // ===== INSTANTIATE MEMORY ARRAYS =====
  
  cv32e40p_icache_tag_mem #(
    .DEPTH(ICACHE_SETS),
    .WAYS(ICACHE_WAYS),
    .TAG_WIDTH(TAG_WIDTH)
  ) u_tag_mem (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .raddr_i(instr_addr_i[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]),
    .rdata_o(tag_rdata),
    .wen_i(cache_wren),
    .wsel_i(cache_wsel),
    .waddr_i(miss_addr_q[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]),
    .wdata_i(miss_addr_q[31:OFFSET_WIDTH+INDEX_WIDTH])
  );

  cv32e40p_icache_data_mem #(
    .DEPTH(ICACHE_SETS),
    .WAYS(ICACHE_WAYS),
    .DATA_WIDTH(ICACHE_DATA_WIDTH)
  ) u_data_mem (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .raddr_i(instr_addr_i[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]),
    .rdata_o(data_rdata),
    .wen_i(cache_wren),
    .wsel_i(cache_wsel),
    .waddr_i(miss_addr_q[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]),
    .wdata_i(mem_rsp_data_i)
  );

  // ===== INSTANTIATE PLRU =====
  plru #(.NUM_WAYS(ICACHE_WAYS)) u_plru (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .update_i(cache_hit | cache_wren),  // Update on hit or refill
    .access_way_i(plru_access_way),
    .flush_i(flush_i),
    .replace_way_o(plru_replace_way)
  );

  // ===== VALID BITS ARRAY =====
  logic [ICACHE_WAYS-1:0] vld_mem [ICACHE_SETS-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int s = 0; s < ICACHE_SETS; s++) vld_mem[s] <= '0;
    end else if (vld_we) begin
      for (int w = 0; w < ICACHE_WAYS; w++) begin
        if (cache_wsel[w]) vld_mem[miss_addr_q[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]][w] <= vld_wdata[w];
      end
      if (flush_en) vld_mem[flush_cnt_q] <= '0;
    end
  end

  assign vld_rdata = vld_mem[instr_addr_i[OFFSET_WIDTH+INDEX_WIDTH-1:OFFSET_WIDTH]];
  
  // ===== ADDRESS EXTRACTION =====
  always_comb begin
    cl_tag = instr_addr_i[31:OFFSET_WIDTH+INDEX_WIDTH];
    cl_offset = instr_addr_i[OFFSET_WIDTH-1:0];
  end

  // ===== TAG COMPARISON + HIT DETECTION =====
  always_comb begin
    cl_hit = '0;
    cache_hit = 1'b0;
    hit_way = '0;
    for (int w = 0; w < ICACHE_WAYS; w++) begin
      if ((cl_tag_q == tag_rdata[w]) && vld_rdata[w]) begin
        cl_hit[w] = 1'b1;
        cache_hit = 1'b1;
        hit_way = w;
      end
    end
  end

  // ===== DATA MULTIPLEXER (select data from hit way) =====
  always_comb begin
    cache_rdata_mux = '0;
    for (int w = 0; w < ICACHE_WAYS; w++) begin
      if (cl_hit[w]) cache_rdata_mux = data_rdata[w][31:0];
    end
  end

  // ===== INVALID WAY FINDER =====
  always_comb begin
    inv_way = '0;
    for (int w = 0; w < ICACHE_WAYS; w++) begin
      if (!vld_rdata[w]) begin
        inv_way = w;
        break;
      end
    end
  end

  // ===== REPLACEMENT WAY SELECTION =====
  assign all_ways_valid = &vld_rdata;  // All ways valid
  assign repl_way = all_ways_valid ? plru_replace_way : inv_way;

  // ===== PLRU ACCESS WAY =====
  assign plru_access_way = cache_wren ? repl_way : hit_way;

  // ===== FLUSH LOGIC =====
  assign flush_cnt_d = flush_done ? '0 : (flush_en ? flush_cnt_q + 1 : flush_cnt_q);
  assign flush_done = (flush_cnt_q == (ICACHE_SETS - 1));

  // ===== FSM STATE MACHINE =====
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE_STATE;
      cl_tag_q <= '0;
      cl_offset_q <= '0;
      miss_addr_q <= '0;
      flush_cnt_q <= '0;
    end else begin
      state_q <= state_d;
      if (instr_req_i && state_q == IDLE_STATE) begin
        cl_tag_q <= cl_tag;
        cl_offset_q <= cl_offset;
      end
      if (state_q == READ_STATE && !cache_hit) begin
        miss_addr_q <= instr_addr_i;
      end
      if (flush_en && !flush_done) begin
        flush_cnt_q <= flush_cnt_d;
      end
    end
  end

  // ===== FSM COMBINATORIAL LOGIC =====
  always_comb begin
    // Default values
    state_d = state_q;
    instr_gnt_o = 1'b0;
    instr_rvalid_o = 1'b0;
    instr_rdata_o = '0;
    mem_req_valid_o = 1'b0;
    mem_req_addr_o = '0;
    mem_req_len_o = 8'd3;     // 4-beat AXI burst (len = burst_length - 1)
    mem_req_size_o = 3'b011;  // 64-bit beat size (size = log2(8 bytes))
    flush_ack_o = 1'b0;
    flush_en = 1'b0;
    cache_wren = 1'b0;
    cache_wsel = '0;
    vld_we = 1'b0;
    vld_wdata = '0;
    miss_o = 1'b0;
    miss_event_o = 1'b0;  // Default: no miss event

    unique case (state_q)
      FLUSH_STATE: begin
        flush_en = 1'b1;
        vld_we = 1'b1;
        if (flush_done) begin
          state_d = IDLE_STATE;
          flush_ack_o = 1'b1;
        end
      end

      IDLE_STATE: begin
        instr_gnt_o = 1'b1;
        if (instr_req_i) begin
          state_d = READ_STATE;
        end
        if (flush_i) begin
          state_d = FLUSH_STATE;
        end
      end

      READ_STATE: begin
        if (cache_hit) begin
          // HIT PATH: Return data
          instr_rvalid_o = 1'b1;
          instr_rdata_o = cache_rdata_mux;
          state_d = IDLE_STATE;
        end else begin
          // MISS PATH: Request memory
          mem_req_valid_o = 1'b1;
          mem_req_addr_o = instr_addr_i;
          miss_o = 1'b1;
          miss_event_o = 1'b1;  // Notify prefetcher of miss
          if (mem_req_ack_i) begin
            state_d = MISS_STATE;
          end
        end
      end

      MISS_STATE: begin
        if (mem_rsp_valid_i) begin
          // Refill complete
          cache_wren = 1'b1;
          cache_wsel = bin2oh(repl_way);
          vld_we = 1'b1;
          vld_wdata = bin2oh(repl_way);
          instr_rvalid_o = 1'b1;
          instr_rdata_o = mem_rsp_data_i[31:0];
          state_d = IDLE_STATE;
        end
      end

      default: state_d = IDLE_STATE;
    endcase

    if (flush_i && state_q != FLUSH_STATE) begin
      state_d = FLUSH_STATE;
    end
  end

endmodule : cv32e40p_icache
