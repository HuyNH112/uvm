`ifndef HPDCACHE_MONITOR_SV
`define HPDCACHE_MONITOR_SV

class hpdcache_monitor extends uvm_monitor;
    `uvm_component_utils(hpdcache_monitor)

    protected uvm_active_passive_enum is_active = UVM_PASSIVE;

    virtual hpdcache_if vif;

    hpdcache_sequencer m_sequencer;

    int num_req_pkts;
    int num_req_no_resp_pkts;
    int num_resp_pkts;

    uvm_analysis_port #(hpdcache_req_mon_t) ap_hpdcache_req;
    uvm_analysis_port #(hpdcache_rsp_t)     ap_hpdcache_rsp;

    hpdcache_req_mon_t m_req_packet;
    hpdcache_rsp_t     m_rsp_packet;

    event reset_asserted;
    event reset_deasserted;

    function new(string name = "hpdcache_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_hpdcache_req      = new("ap_hpdcache_req", this);
        ap_hpdcache_rsp      = new("ap_hpdcache_rsp", this);
        num_req_pkts         = 0;
        num_req_no_resp_pkts = 0;
        num_resp_pkts        = 0;
        `uvm_info(get_full_name(), "Build phase complete.", UVM_HIGH)
    endfunction

    virtual task pre_reset_phase(uvm_phase phase);
        super.pre_reset_phase(phase);
        -> reset_asserted;
    endtask

    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        num_req_pkts         = 0;
        num_req_no_resp_pkts = 0;
        num_resp_pkts        = 0;
    endtask

    virtual task post_reset_phase(uvm_phase phase);
        super.post_reset_phase(phase);
        -> reset_deasserted;
    endtask

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        `uvm_info("MON", "Entering main_phase", UVM_HIGH)
        fork
            collect_reqs(phase);
            collect_resps(phase);
        join_none
        `uvm_info("MON", "Leaving main_phase", UVM_HIGH)
    endtask

    virtual task collect_reqs(uvm_phase phase);
        hpdcache_req_mon_t req_mon;

        forever begin
            @(posedge vif.clk_i);

            if (vif.core_req_valid_i && vif.core_req_ready_o) begin
                req_mon.addr_offset  = vif.core_req_i.addr_offset;
                req_mon.wdata        = vif.core_req_i.wdata;
                req_mon.op           = vif.core_req_i.op;
                req_mon.be           = vif.core_req_i.be;
                req_mon.size         = vif.core_req_i.size;
                req_mon.sid          = vif.core_req_i.sid;
                req_mon.tid          = vif.core_req_i.tid;
                req_mon.need_rsp     = vif.core_req_i.need_rsp;
                req_mon.phys_indexed = vif.core_req_i.phys_indexed;
                req_mon.pma          = vif.core_req_i.pma;
                req_mon.addr_tag     = vif.core_req_tag_i;
                req_mon.addr         = {req_mon.addr_tag, req_mon.addr_offset};
                req_mon.abort        = vif.core_req_abort_i;
                req_mon.second_cycle = 1'b0;

                m_req_packet = req_mon;

                if (!req_mon.need_rsp)
                    num_req_no_resp_pkts++;

                #0 ap_hpdcache_req.write(req_mon);

                if (!req_mon.phys_indexed) begin
                    @(posedge vif.clk_i);
                    req_mon.abort        = vif.core_req_abort_i;
                    req_mon.addr_tag     = vif.core_req_tag_i;
                    req_mon.pma          = vif.core_req_pma_i;
                    req_mon.addr         = {req_mon.addr_tag, req_mon.addr_offset};
                    req_mon.second_cycle = 1'b1;
                    #0 ap_hpdcache_req.write(req_mon);
                end

                num_req_pkts++;
                `uvm_info("MON",
                    $sformatf("REQ #%0d: OP=%s PA=0x%08h TID=%0d SID=%0d NEED_RSP=%0b",
                              num_req_pkts, req_mon.op.name(), req_mon.addr,
                              req_mon.tid, req_mon.sid, req_mon.need_rsp),
                    UVM_MEDIUM)
            end
        end
    endtask : collect_reqs

    virtual task collect_resps(uvm_phase phase);
        hpdcache_rsp_t rsp;

        forever begin
            @(posedge vif.clk_i);

            if (vif.core_rsp_valid_o) begin
                rsp.rdata   = vif.core_rsp_o.rdata;
                rsp.sid     = vif.core_rsp_o.sid;
                rsp.tid     = vif.core_rsp_o.tid;
                rsp.error   = vif.core_rsp_o.error;
                rsp.aborted = vif.core_rsp_o.aborted;

                m_rsp_packet = rsp;

                if (is_active == UVM_ACTIVE)
                    m_sequencer.q_inflight_tid.delete(rsp.tid);

                #0 ap_hpdcache_rsp.write(rsp);

                num_resp_pkts++;
                `uvm_info("MON",
                    $sformatf("RSP #%0d: TID=%0d SID=%0d ERR=%0b ABORTED=%0b RDATA=0x%016h",
                              num_resp_pkts, rsp.tid, rsp.sid,
                              rsp.error, rsp.aborted, rsp.rdata),
                    UVM_MEDIUM)
            end
        end
    endtask : collect_resps

    virtual task post_shutdown_phase(uvm_phase phase);
        super.post_shutdown_phase(phase);
        phase.raise_objection(this, "Waiting for all responses");
        do begin
            #10;
            `uvm_info("MON",
                $sformatf("REQ=%0d RSP=%0d NO_RSP=%0d",
                          num_req_pkts, num_resp_pkts, num_req_no_resp_pkts),
                UVM_HIGH)
        end while (num_req_pkts != (num_resp_pkts + num_req_no_resp_pkts));
        phase.drop_objection(this, "All responses received");
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(),
            $sformatf("REPORT: REQ=%0d RSP=%0d NO_RSP=%0d",
                      num_req_pkts, num_resp_pkts, num_req_no_resp_pkts),
            UVM_LOW)
    endfunction

    function void set_is_active();
        is_active = UVM_ACTIVE;
    endfunction

    function void set_hpdcache_vif(virtual hpdcache_if I);
        vif = I;
    endfunction

endclass : hpdcache_monitor

`endif // HPDCACHE_MONITOR_SV
