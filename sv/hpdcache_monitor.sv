// =============================================================================
// hpdcache_monitor.sv
// Monitor: sample posedge, fork collect_reqs + collect_resps + perf_events
// Dùng UVM_HPDCACHE_* localparam và hpdcache_pkg:: types từ package
// UVM 1.1d: chỉ run_phase
// =============================================================================
`ifndef HPDCACHE_MONITOR_SV
`define HPDCACHE_MONITOR_SV

class hpdcache_monitor extends uvm_monitor;

    `uvm_component_utils(hpdcache_monitor)

    virtual hpdcache_if.monitor_mp vif;

    // Analysis ports → scoreboard
    uvm_analysis_port #(hpdcache_seq_item) ap_req;
    uvm_analysis_port #(hpdcache_seq_item) ap_rsp;

    // Width shortcuts từ pkg localparam
    localparam int unsigned PA_W     = UVM_HPDCACHE_PA_WIDTH;
    localparam int unsigned TAG_W    = UVM_TAG_WIDTH;
    localparam int unsigned OFF_W    = UVM_REQ_OFFSET_WIDTH;

    // Performance event counters
    int unsigned cnt_read_miss;
    int unsigned cnt_write_miss;
    int unsigned cnt_prefetch;
    int unsigned cnt_stall;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cnt_read_miss = 0; cnt_write_miss = 0;
        cnt_prefetch  = 0; cnt_stall      = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_req = new("ap_req", this);
        ap_rsp = new("ap_rsp", this);
        if (!uvm_config_db #(virtual hpdcache_if.monitor_mp)::get(
                this, "", "hpdcache_vif_monitor", vif))
            `uvm_fatal("NOVIF", "Monitor: hpdcache_vif_monitor not found")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.rst_ni);
        repeat (2) @(posedge vif.clk_i);
        fork
            collect_reqs();
            collect_resps();
            collect_perf_events();
        join_none
    endtask

    // -------------------------------------------------------------------------
    // collect_reqs: sample accepted request (valid & ready posedge)
    // -------------------------------------------------------------------------
    task collect_reqs();
        hpdcache_seq_item item;
        forever begin
            @(posedge vif.clk_i);
            if (vif.core_req_valid_i && vif.core_req_ready_o) begin
                item = hpdcache_seq_item::type_id::create("mon_req");
                // op, size, pma: dùng pkg types trực tiếp từ interface
                item.op           = vif.core_req_i.op;
                item.addr_tag     = vif.core_req_i.addr_tag;
                item.addr_offset  = vif.core_req_i.addr_offset;
                item.wdata        = vif.core_req_i.wdata;
                item.be           = vif.core_req_i.be;
                item.size         = vif.core_req_i.size;
                item.tid          = vif.core_req_i.tid;
                item.sid          = vif.core_req_i.sid;
                item.need_rsp     = vif.core_req_i.need_rsp;
                item.phys_indexed = vif.core_req_i.phys_indexed;
                item.pma          = vif.core_req_pma_i;
                `uvm_info("MON", {"REQ: ", item.convert2string()}, UVM_HIGH)
                ap_req.write(item);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // collect_resps: sample core_rsp_valid_o posedge
    // -------------------------------------------------------------------------
    task collect_resps();
        hpdcache_seq_item rsp;
        forever begin
            @(posedge vif.clk_i);
            if (vif.core_rsp_valid_o) begin
                rsp = hpdcache_seq_item::type_id::create("mon_rsp");
                // Dùng LOAD op làm placeholder cho response item
                rsp.op    = HPDCACHE_REQ_LOAD;
                rsp.tid   = vif.core_rsp_o.tid;
                rsp.sid   = vif.core_rsp_o.sid;
                rsp.wdata = vif.core_rsp_o.rdata;
                `uvm_info("MON",
                    $sformatf("RSP: TID=%0d SID=%0d ERR=%0b RDATA=0x%032h",
                              rsp.tid, rsp.sid,
                              vif.core_rsp_o.error, rsp.wdata),
                    UVM_HIGH)
                ap_rsp.write(rsp);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // collect_perf_events
    // -------------------------------------------------------------------------
    task collect_perf_events();
        forever begin
            @(posedge vif.clk_i);
            if (vif.evt_cache_read_miss_o)  cnt_read_miss++;
            if (vif.evt_cache_write_miss_o) cnt_write_miss++;
            if (vif.evt_prefetch_req_o)     cnt_prefetch++;
            if (vif.evt_stall_o)            cnt_stall++;
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("MON", $sformatf(
            "\n=== Performance Events ===\n  Read Miss : %0d\n  Write Miss: %0d\n  Prefetch  : %0d\n  Stall     : %0d\n==========================",
            cnt_read_miss, cnt_write_miss, cnt_prefetch, cnt_stall),
            UVM_MEDIUM)
    endfunction

endclass : hpdcache_monitor

`endif // HPDCACHE_MONITOR_SV
