`ifndef HPDCACHE_DRIVER_SV
`define HPDCACHE_DRIVER_SV

class hpdcache_driver extends uvm_driver #(hpdcache_seq_item);
    `uvm_component_utils(hpdcache_driver)

    virtual hpdcache_if hpdcache_vif;

    hpdcache_seq_item rsp_list[int][$];

    function new(string name = "hpdcache_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);

        hpdcache_vif.core_req_valid_i              <= 1'b0;
        hpdcache_vif.core_req_i.addr_offset        <= '0;
        hpdcache_vif.core_req_i.wdata               <= '0;
        hpdcache_vif.core_req_i.op                  <= hpdcache_pkg::HPDCACHE_REQ_LOAD;
        hpdcache_vif.core_req_i.be                  <= '0;
        hpdcache_vif.core_req_i.size                <= '0;
        hpdcache_vif.core_req_i.sid                 <= '0;
        hpdcache_vif.core_req_i.tid                 <= '0;
        hpdcache_vif.core_req_i.need_rsp            <= 1'b0;
        hpdcache_vif.core_req_i.phys_indexed        <= 1'b1;
        hpdcache_vif.core_req_i.pma.uncacheable     <= 1'b0;
        hpdcache_vif.core_req_i.pma.io              <= 1'b0;
        hpdcache_vif.core_req_i.pma.wr_policy_hint  <= hpdcache_pkg::HPDCACHE_WR_POLICY_AUTO;
        hpdcache_vif.core_req_abort_i               <= 1'b0;
        hpdcache_vif.core_req_tag_i                 <= '0;
        hpdcache_vif.core_req_pma_i.uncacheable     <= 1'b0;
        hpdcache_vif.core_req_pma_i.io              <= 1'b0;
        hpdcache_vif.core_req_pma_i.wr_policy_hint  <= hpdcache_pkg::HPDCACHE_WR_POLICY_AUTO;
        hpdcache_vif.wbuf_flush_i                   <= 1'b0;

        `uvm_info("DRV", "Reset phase complete.", UVM_LOW)
    endtask

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        fork
            get_and_drive_req();
            spy_and_drive_rsp();
        join_none
    endtask

    virtual task get_and_drive_req();
        hpdcache_seq_item req_item;

        forever begin
            seq_item_port.get_next_item(req_item);

            if (req_item.m_txn_idle_cycles > 0)
                hpdcache_vif.wait_n_clocks(req_item.m_txn_idle_cycles);

            // ------------------------------------------------------------------
            // Phase 1: drive core_req_i
            // ------------------------------------------------------------------
            hpdcache_vif.core_req_valid_i              <= 1'b1;
            hpdcache_vif.core_req_i.addr_offset        <= req_item.addr_offset;
            hpdcache_vif.core_req_i.wdata               <= req_item.wdata;
            hpdcache_vif.core_req_i.op                  <= req_item.op;
            hpdcache_vif.core_req_i.be                  <= req_item.be;
            hpdcache_vif.core_req_i.size                <= req_item.size;
            hpdcache_vif.core_req_i.sid                 <= req_item.sid;
            hpdcache_vif.core_req_i.tid                 <= req_item.tid;
            hpdcache_vif.core_req_i.need_rsp            <= req_item.need_rsp;
            hpdcache_vif.core_req_i.phys_indexed        <= req_item.phys_indexed;
            hpdcache_vif.core_req_i.pma.uncacheable     <= req_item.pma.uncacheable;
            hpdcache_vif.core_req_i.pma.io              <= req_item.pma.io;
            hpdcache_vif.core_req_i.pma.wr_policy_hint  <= req_item.pma.wr_policy_hint;
            hpdcache_vif.core_req_abort_i               <= 1'b0;
            // Phys-indexed: tag duoc gui ngay trong cycle dau qua core_req_tag_i
            hpdcache_vif.core_req_tag_i                 <= req_item.addr_tag;
            hpdcache_vif.core_req_pma_i.uncacheable     <= req_item.pma.uncacheable;
            hpdcache_vif.core_req_pma_i.io              <= req_item.pma.io;
            hpdcache_vif.core_req_pma_i.wr_policy_hint  <= req_item.pma.wr_policy_hint;

            do begin
                @(posedge hpdcache_vif.clk_i);
            end while (!hpdcache_vif.core_req_ready_o);

            hpdcache_vif.core_req_valid_i              <= 1'b0;
            hpdcache_vif.core_req_i.addr_offset        <= 'x;
            hpdcache_vif.core_req_i.wdata               <= 'x;
            hpdcache_vif.core_req_i.be                  <= 'x;
            hpdcache_vif.core_req_i.size                <= 'x;
            hpdcache_vif.core_req_i.sid                 <= 'x;
            hpdcache_vif.core_req_i.tid                 <= 'x;
            hpdcache_vif.core_req_i.need_rsp            <= 'x;

            if (req_item.need_rsp)
                rsp_list[int'(req_item.tid)].push_back(req_item);

            // ------------------------------------------------------------------
            // Phase 2 (virtually-indexed only): abort tag co the cap nhat lai
            // ------------------------------------------------------------------
            if (!req_item.phys_indexed) begin
                hpdcache_vif.core_req_abort_i           <= req_item.m_req_abort;
                hpdcache_vif.core_req_tag_i             <= req_item.addr_tag;
                hpdcache_vif.core_req_pma_i.uncacheable <= req_item.pma.uncacheable;
                hpdcache_vif.core_req_pma_i.io          <= req_item.pma.io;
                @(posedge hpdcache_vif.clk_i);
            end

            seq_item_port.item_done();

            `uvm_info("DRV",
                $sformatf("Drove: OP=%s PA=0x%08h TID=%0d SID=%0d",
                          req_item.op.name(),
                          {req_item.addr_tag, req_item.addr_offset},
                          req_item.tid, req_item.sid),
                UVM_HIGH)
        end
    endtask

    virtual task spy_and_drive_rsp();
        hpdcache_seq_item rsp_item;

        forever begin
            @(posedge hpdcache_vif.clk_i);

            if (hpdcache_vif.core_rsp_valid_o) begin
                int tid_key = int'(hpdcache_vif.core_rsp_o.tid);

                if (rsp_list.exists(tid_key) && rsp_list[tid_key].size() > 0) begin
                    rsp_item = rsp_list[tid_key].pop_front();
                    rsp_item.rdata       = hpdcache_vif.core_rsp_o.rdata;
                    rsp_item.rsp_error   = hpdcache_vif.core_rsp_o.error;
                    rsp_item.rsp_aborted = hpdcache_vif.core_rsp_o.aborted;
                    seq_item_port.put(rsp_item);

                    `uvm_info("DRV",
                        $sformatf("RSP: TID=%0d SID=%0d RDATA=0x%016h ERR=%0b",
                                  rsp_item.tid, rsp_item.sid,
                                  rsp_item.rdata, rsp_item.rsp_error),
                        UVM_HIGH)
                end else begin
                    `uvm_warning("DRV",
                        $sformatf("Response received for unknown/untracked TID=%0d", tid_key))
                end
            end
        end
    endtask

    function void set_hpdcache_vif(virtual hpdcache_if I);
        hpdcache_vif = I;
    endfunction

endclass : hpdcache_driver

`endif // HPDCACHE_DRIVER_SV
