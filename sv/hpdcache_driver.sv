// =============================================================================
// hpdcache_driver.sv
// Driver: negedge drive, 80-cycle post-reset delay, posedge ready poll
// Dùng UVM_HPDCACHE_* pkg localparam + hpdcache_pkg types — không dùng CONF macro
// =============================================================================
`ifndef HPDCACHE_DRIVER_SV
`define HPDCACHE_DRIVER_SV

class hpdcache_driver extends uvm_driver #(hpdcache_seq_item);

    `uvm_component_utils(hpdcache_driver)

    virtual hpdcache_if.driver_mp vif;

    // Width shortcuts từ pkg localparam
    localparam int unsigned TID_W    = UVM_HPDCACHE_REQ_TRANS_ID_WIDTH;  // 6
    localparam int unsigned TAG_W    = UVM_TAG_WIDTH;                     // 44
    localparam int unsigned WBUF_TCW = 4; // CONF_HPDCACHE_WBUF_TIMECNT_WIDTH

    localparam int unsigned DRIVE_TIMEOUT = 200; // cycles per transaction
    localparam int unsigned INIT_DELAY    = 80;  // post-reset: 64 sets + 16 margin

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual hpdcache_if.driver_mp)::get(
                this, "", "hpdcache_vif_driver", vif))
            `uvm_fatal("NOVIF", "Driver: hpdcache_vif_driver not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        init_signals();
        @(posedge vif.rst_ni);
        `uvm_info("DRV", "Reset released", UVM_MEDIUM)
        repeat (INIT_DELAY) @(posedge vif.clk_i);
        `uvm_info("DRV", $sformatf("Init delay done (%0d cycles)", INIT_DELAY), UVM_MEDIUM)

        forever begin
            hpdcache_seq_item item;
            seq_item_port.get_next_item(item);
            `uvm_info("DRV", {"TX: ", item.convert2string()}, UVM_HIGH)
            if (item.delay_cycles > 0)
                repeat (item.delay_cycles) @(posedge vif.clk_i);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask

    task automatic drive_item(input hpdcache_seq_item item);
        int unsigned timeout_cnt = 0;

        @(negedge vif.clk_i);
        vif.core_req_valid_i        <= 1'b1;
        vif.core_req_i.addr_offset  <= item.addr_offset;
        vif.core_req_i.wdata        <= item.wdata;
        vif.core_req_i.op           <= item.op;
        vif.core_req_i.be           <= item.be;
        vif.core_req_i.size         <= item.size;
        vif.core_req_i.sid          <= item.sid;
        vif.core_req_i.tid          <= item.tid;
        vif.core_req_i.need_rsp     <= item.need_rsp;
        vif.core_req_i.phys_indexed <= item.phys_indexed;
        vif.core_req_i.addr_tag     <= item.addr_tag;
        vif.core_req_i.pma          <= item.pma;
        vif.core_req_tag_i          <= item.addr_tag;
        vif.core_req_pma_i          <= item.pma;
        vif.core_req_abort_i        <= 1'b0;

        forever begin
            @(posedge vif.clk_i);
            timeout_cnt++;
            if (timeout_cnt >= DRIVE_TIMEOUT) begin
                `uvm_error("DRV_TMO",
                    $sformatf("ready_o timeout %0d cycles: %s",
                              DRIVE_TIMEOUT, item.convert2string()))
                break;
            end
            if (vif.core_req_ready_o) break;
            @(negedge vif.clk_i); // re-drive on next negedge
        end

        @(negedge vif.clk_i);
        vif.core_req_valid_i  <= 1'b0;
        vif.core_req_i        <= '0;
        vif.core_req_tag_i    <= '0;
        vif.core_req_abort_i  <= 1'b0;
    endtask

    task init_signals();
        vif.core_req_valid_i    <= 1'b0;
        vif.core_req_i          <= '0;
        vif.core_req_abort_i    <= 1'b0;
        vif.core_req_tag_i      <= '0;
        vif.core_req_pma_i      <= '0;
        vif.wbuf_flush_i        <= 1'b0;
        // AXI memory side: always ready
        vif.mem_req_read_ready_i         <= 1'b1;
        vif.mem_resp_read_valid_i        <= 1'b0;
        vif.mem_resp_read_error_i  <= hpdcache_pkg::hpdcache_mem_error_e'(0);
        vif.mem_resp_read_id_i           <= '0;
        vif.mem_resp_read_data_i         <= '0;
        vif.mem_resp_read_last_i         <= 1'b0;
        vif.mem_req_write_ready_i        <= 1'b1;
        vif.mem_req_write_data_ready_i   <= 1'b1;
        vif.mem_resp_write_valid_i       <= 1'b0;
        vif.mem_resp_write_is_atomic_i   <= 1'b0;
        vif.mem_resp_write_error_i <= hpdcache_pkg::hpdcache_mem_error_e'(0);
        vif.mem_resp_write_id_i          <= '0;
        // Config
        vif.cfg_enable_i                        <= 1'b1;
        vif.cfg_wbuf_threshold_i                <= {{(WBUF_TCW-2){1'b0}}, 2'd2};
        vif.cfg_wbuf_reset_timecnt_on_write_i   <= 1'b1;
        vif.cfg_wbuf_sequential_waw_i           <= 1'b0;
        vif.cfg_wbuf_inhibit_write_coalescing_i <= 1'b0;
        vif.cfg_prefetch_updt_plru_i            <= 1'b1;
        vif.cfg_error_on_cacheable_amo_i        <= 1'b0;
        vif.cfg_rtab_single_entry_i             <= 1'b0;
        vif.cfg_default_wb_i                    <= 1'b1;
        vif.cfg_scrub_enable_i                  <= 1'b0;
        vif.cfg_scrub_period_i                  <= 6'h3F;
        vif.cfg_scrub_restart_i                 <= 1'b0;
    endtask

endclass : hpdcache_driver

`endif // HPDCACHE_DRIVER_SV
