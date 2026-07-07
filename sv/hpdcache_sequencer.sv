// =============================================================================
// hpdcache_sequencer.sv — UVM_HPDCACHE_* only, no CONF macro
// =============================================================================
`ifndef HPDCACHE_SEQUENCER_SV
`define HPDCACHE_SEQUENCER_SV

class hpdcache_sequencer extends uvm_sequencer #(hpdcache_seq_item);

    `uvm_component_utils(hpdcache_sequencer)

    localparam int unsigned MAX_TID = (1 << UVM_HPDCACHE_REQ_TRANS_ID_WIDTH); // 64

    bit tid_in_use [MAX_TID];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        foreach (tid_in_use[i]) tid_in_use[i] = 1'b0;
    endfunction

    function automatic hpdcache_req_tid_t alloc_tid();
        for (int i = 0; i < MAX_TID; i++) begin
            if (!tid_in_use[i]) begin
                tid_in_use[i] = 1'b1;
                return hpdcache_req_tid_t'(i);
            end
        end
        `uvm_fatal("TID", "No free TID — all 64 inflight!")
        return '0;
    endfunction

    function void free_tid(input hpdcache_req_tid_t tid);
        tid_in_use[tid] = 1'b0;
    endfunction

endclass : hpdcache_sequencer

`endif // HPDCACHE_SEQUENCER_SV
