`ifndef HPDCACHE_SEQUENCER_SV
`define HPDCACHE_SEQUENCER_SV

class hpdcache_sequencer extends uvm_sequencer #(hpdcache_seq_item);
    `uvm_component_utils(hpdcache_sequencer)

    // In-flight TID tracking (xoa boi monitor khi nhan response)
    bit q_inflight_tid[hpdcache_req_tid_t];

    function new(string name = "hpdcache_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : hpdcache_sequencer

`endif
