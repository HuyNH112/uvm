`ifndef HPDCACHE_SEQ_ITEM_SV
`define HPDCACHE_SEQ_ITEM_SV

class hpdcache_seq_item extends uvm_sequence_item;

    `uvm_object_utils(hpdcache_seq_item)

    // -------------------------------------------------------------------------
    // Request fields
    // -------------------------------------------------------------------------
    rand hpdcache_pkg::hpdcache_req_op_t   op;
    rand hpdcache_pkg::hpdcache_req_size_t size;
    rand hpdcache_tag_t                    addr_tag;
    rand hpdcache_req_offset_t             addr_offset;
    rand hpdcache_req_data_t               wdata;
    rand hpdcache_req_be_t                 be;
    rand hpdcache_req_tid_t                tid;
    rand hpdcache_req_sid_t                sid;
    rand logic                             need_rsp;
    rand logic                             phys_indexed;
    rand hpdcache_pkg::hpdcache_pma_t      pma;

    // Optional knobs
    rand int unsigned                      m_txn_idle_cycles;
    rand logic                             m_req_abort;

    // -------------------------------------------------------------------------
    // Response fields (filled by driver/monitor — khong randomize)
    // -------------------------------------------------------------------------
    hpdcache_req_data_t  rdata;
    logic                rsp_error;
    logic                rsp_aborted;

    // -------------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------------
    constraint c_op_type {
        op inside {
            hpdcache_pkg::HPDCACHE_REQ_LOAD,
            hpdcache_pkg::HPDCACHE_REQ_STORE
        };
    }

    constraint c_size {
        size inside {3'b010, 3'b011};
    }

    constraint c_addr_align {
        if (size == 3'b010) addr_offset[1:0] == 2'b00;
        if (size == 3'b011) addr_offset[2:0] == 3'b000;
    }

    constraint c_addr_tag_range {
        addr_tag inside {[18'h0 : 18'h3_FFFF]};
    }

    constraint c_be {
        if (size == 3'b010) be == 8'h0F;
        if (size == 3'b011) be == 8'hFF;
    }

    constraint c_wdata_load {
        if (op == hpdcache_pkg::HPDCACHE_REQ_LOAD) wdata == '0;
    }

    constraint c_ctrl {
        need_rsp     == 1'b1;
        phys_indexed == 1'b1;
        m_req_abort  == 1'b0;
    }

    constraint c_pma {
        pma.uncacheable    == 1'b0;
        pma.io             == 1'b0;
        pma.wr_policy_hint == hpdcache_pkg::HPDCACHE_WR_POLICY_AUTO;
    }

    constraint c_sid {
        sid inside {[3'h0 : 3'h7]};
    }

    constraint c_idle {
        m_txn_idle_cycles inside {[0:3]};
    }

    // -------------------------------------------------------------------------
    function new(string name = "hpdcache_seq_item");
        super.new(name);
    endfunction

    function logic [31:0] get_paddr();
        return {addr_tag, addr_offset};
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("OP:%-12s | PA:32'h%08h | SZ:%0d | SID:%0d | TID:%0d",
                      op.name(), get_paddr(), size, sid, tid);
        if (op == hpdcache_pkg::HPDCACHE_REQ_STORE)
            s = {s, $sformatf(" | WDATA:64'h%016h | BE:8'h%02h", wdata, be)};
        return s;
    endfunction

endclass : hpdcache_seq_item

`endif