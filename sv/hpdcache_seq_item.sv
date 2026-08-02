// =============================================================================
// hpdcache_seq_item.sv
// UVM Transaction Item — dùng UVM_* localparam từ hpdcache_uvm_pkg
// KHÔNG dùng `CONF_HPDCACHE_* macro (undefined khi compile trong package)
// KHÔNG dùng rand/randomize (cần svverification license)
// =============================================================================

class hpdcache_seq_item extends uvm_sequence_item;

    `uvm_object_utils(hpdcache_seq_item)

    // -------------------------------------------------------------------------
    // Width shortcuts — dùng pkg localparam (visible trong package scope)
    // -------------------------------------------------------------------------
    localparam int unsigned PA_W      = UVM_HPDCACHE_PA_WIDTH;            // 56
    localparam int unsigned TID_W     = UVM_HPDCACHE_REQ_TRANS_ID_WIDTH;  // 6
    localparam int unsigned SID_W     = UVM_HPDCACHE_REQ_SRC_ID_WIDTH;    // 3
    localparam int unsigned TAG_W     = UVM_TAG_WIDTH;                     // 44
    localparam int unsigned OFF_W     = UVM_REQ_OFFSET_WIDTH;              // 12
    localparam int unsigned SET_W     = UVM_SET_WIDTH;                     // 6
    localparam int unsigned CL_OFF_W  = UVM_CL_OFFSET_WIDTH;              // 6
    localparam int unsigned DATA_W    = UVM_REQ_DATA_WIDTH;                // 128
    localparam int unsigned BE_W      = UVM_HPDCACHE_REQ_WORDS
                                      * (UVM_HPDCACHE_WORD_WIDTH / 8);    // 16

    // -------------------------------------------------------------------------
    // Transaction fields — dùng pkg types
    // -------------------------------------------------------------------------
    hpdcache_req_op_t   op;
    hpdcache_tag_t                    addr_tag;
    hpdcache_req_offset_t             addr_offset;
    hpdcache_req_data_t               wdata;
    hpdcache_req_be_t                 be;
    hpdcache_req_tid_t                tid;
    hpdcache_req_sid_t                sid;
    logic                             need_rsp;
    logic                             phys_indexed;
    hpdcache_req_size_t size;
    hpdcache_pma_t      pma;

    // Inject inter-transaction delay
    int unsigned                      delay_cycles;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "hpdcache_seq_item");
        super.new(name);
        op           = HPDCACHE_REQ_LOAD;
        addr_tag     = '0;
        addr_offset  = '0;
        wdata        = '0;
        be           = '0;
        tid          = '0;
        sid          = '0;
        need_rsp     = 1'b1;
        phys_indexed = 1'b1;   // Physically Indexed Physically Tagged
        size         = hpdcache_req_size_t'(3); // 8-byte
        pma          = '0;
        delay_cycles = 0;
    endfunction

    // -------------------------------------------------------------------------
    // Helper: reconstruct Physical Address
    // -------------------------------------------------------------------------
    function logic [PA_W-1:0] get_pa();
        return {addr_tag, addr_offset};
    endfunction

    // -------------------------------------------------------------------------
    // set_random_load — LOAD ngẫu nhiên, địa chỉ cacheable
    // -------------------------------------------------------------------------
    function void set_random_load(input hpdcache_req_tid_t i_tid,
                                   input hpdcache_req_sid_t i_sid = '0);
        op           = HPDCACHE_REQ_LOAD;
        tid          = i_tid;
        sid          = i_sid;
        need_rsp     = 1'b1;
        phys_indexed = 1'b1;
        size         = hpdcache_req_size_t'(3);
        pma          = '0;  // cacheable
        // Tag: zero-extend từ 32-bit để tránh X trên bit cao
        addr_tag     = hpdcache_tag_t'({{(TAG_W-32){1'b0}}, $urandom()});
        // Offset: random set, word-aligned (bit[2:0]=0)
        addr_offset  = hpdcache_req_offset_t'({$urandom_range(0,63), {CL_OFF_W{1'b0}}});
        wdata        = '0;
        // BE: size=3 (8B) → chọn upper/lower word theo addr_offset[3]
        be           = hpdcache_req_be_t'(addr_offset[3] ? 16'hFF00 : 16'h00FF);
    endfunction

    // -------------------------------------------------------------------------
    // set_random_store — STORE ngẫu nhiên
    // -------------------------------------------------------------------------
    function void set_random_store(input hpdcache_req_tid_t i_tid,
                                    input hpdcache_req_sid_t i_sid = '0);
        op           = HPDCACHE_REQ_STORE;
        tid          = i_tid;
        sid          = i_sid;
        need_rsp     = 1'b0;
        phys_indexed = 1'b1;
        size         = hpdcache_req_size_t'(3);
        pma          = '0;
        addr_tag     = hpdcache_tag_t'({{(TAG_W-32){1'b0}}, $urandom()});
        addr_offset  = hpdcache_req_offset_t'({$urandom_range(0,63), {CL_OFF_W{1'b0}}});
        wdata        = hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()});
        be           = hpdcache_req_be_t'(addr_offset[3] ? 16'hFF00 : 16'h00FF);
    endfunction

    // -------------------------------------------------------------------------
    // set_store_to_addr — STORE đến địa chỉ cố định
    // -------------------------------------------------------------------------
    function void set_store_to_addr(input logic [PA_W-1:0]   i_pa,
                                     input hpdcache_req_data_t i_data,
                                     input hpdcache_req_tid_t  i_tid,
                                     input hpdcache_req_sid_t  i_sid = '0);
        op           = HPDCACHE_REQ_STORE;
        tid          = i_tid;
        sid          = i_sid;
        need_rsp     = 1'b0;
        phys_indexed = 1'b1;
        size         = hpdcache_req_size_t'(3);
        pma          = '0;
        addr_tag     = hpdcache_tag_t'(i_pa[PA_W-1 : OFF_W]);
        addr_offset  = hpdcache_req_offset_t'(i_pa[OFF_W-1 : 0]);
        wdata        = i_data;
        be           = hpdcache_req_be_t'(i_pa[3] ? 16'hFF00 : 16'h00FF);
    endfunction

    // -------------------------------------------------------------------------
    // set_load_from_addr — LOAD từ địa chỉ cố định
    // -------------------------------------------------------------------------
    function void set_load_from_addr(input logic [PA_W-1:0]  i_pa,
                                      input hpdcache_req_tid_t i_tid,
                                      input hpdcache_req_sid_t i_sid = '0);
        op           = HPDCACHE_REQ_LOAD;
        tid          = i_tid;
        sid          = i_sid;
        need_rsp     = 1'b1;
        phys_indexed = 1'b1;
        size         = hpdcache_req_size_t'(3);
        pma          = '0;
        addr_tag     = hpdcache_tag_t'(i_pa[PA_W-1 : OFF_W]);
        addr_offset  = hpdcache_req_offset_t'(i_pa[OFF_W-1 : 0]);
        wdata        = '0;
        be           = hpdcache_req_be_t'(i_pa[3] ? 16'hFF00 : 16'h00FF);
    endfunction

    // -------------------------------------------------------------------------
    // set_prefetch — CMO prefetch
    // -------------------------------------------------------------------------
    function void set_prefetch(input logic [PA_W-1:0]  i_pa,
                                input hpdcache_req_tid_t i_tid,
                                input hpdcache_req_sid_t i_sid = '0);
        op           = HPDCACHE_REQ_CMO_PREFETCH;
        tid          = i_tid;
        sid          = i_sid;
        need_rsp     = 1'b0;
        phys_indexed = 1'b1;
        size         = hpdcache_req_size_t'(6);
        pma          = '0;
        addr_tag     = hpdcache_tag_t'(i_pa[PA_W-1 : OFF_W]);
        addr_offset  = hpdcache_req_offset_t'(i_pa[OFF_W-1 : 0]);
        wdata        = '0;
        be           = '0;
    endfunction

    // -------------------------------------------------------------------------
    // do_copy / convert2string
    // -------------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        hpdcache_seq_item rhs_c;
        super.do_copy(rhs);
        if (!$cast(rhs_c, rhs)) begin
            `uvm_error("CAST", "do_copy: type mismatch"); return;
        end
        op = rhs_c.op; addr_tag = rhs_c.addr_tag; addr_offset = rhs_c.addr_offset;
        wdata = rhs_c.wdata; be = rhs_c.be; tid = rhs_c.tid; sid = rhs_c.sid;
        need_rsp = rhs_c.need_rsp; phys_indexed = rhs_c.phys_indexed;
        size = rhs_c.size; pma = rhs_c.pma; delay_cycles = rhs_c.delay_cycles;
    endfunction

    function string convert2string();
        return $sformatf("op=%0d PA=0x%014h TID=%0d SID=%0d BE=0x%04h need_rsp=%0b",
            int'(op), get_pa(), tid, sid, be, need_rsp);
    endfunction

endclass : hpdcache_seq_item
