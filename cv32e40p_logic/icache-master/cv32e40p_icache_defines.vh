// ============================================================
// cv32e40p_icache_defines.vh
//
// Macro definitions for CV32E40P I-Cache
// Status: [PLACEHOLDER - TO BE IMPLEMENTED]
// ============================================================

// ===== ICACHE CONFIGURATION =====
`define ICACHE_SIZE          16384
`define ICACHE_LINE_SIZE     64
`define ICACHE_WAYS          4
`define ICACHE_SETS          64
`define ICACHE_ADDR_WIDTH    32
`define ICACHE_DATA_WIDTH    256
`define ICACHE_TAG_WIDTH     22
`define ICACHE_INDEX_WIDTH   6
`define ICACHE_OFFSET_WIDTH  6
`define ICACHE_WAY_WIDTH     2

// ===== FSM STATES =====
`define ICACHE_STATE_FLUSH       3'b000
`define ICACHE_STATE_IDLE        3'b001
`define ICACHE_STATE_READ        3'b010
`define ICACHE_STATE_MISS        3'b011
`define ICACHE_STATE_KILL_ATRANS 3'b100
`define ICACHE_STATE_KILL_MISS   3'b101

// ===== AXI PARAMETERS =====
`define AXI_LEN_4BEAT 8'h03    // ar_len for 4-beat burst (0-indexed)
`define AXI_SIZE_64   3'h03    // size for 64-bit beats (2^3 = 8 bytes)
