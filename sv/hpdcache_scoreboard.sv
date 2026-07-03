`ifndef HPDCACHE_SCOREBOARD_SV
`define HPDCACHE_SCOREBOARD_SV

class hpdcache_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(hpdcache_scoreboard)

    uvm_tlm_analysis_fifo #(hpdcache_req_mon_t) af_hpdcache_req;
    uvm_tlm_analysis_fifo #(hpdcache_rsp_t)     af_hpdcache_rsp;

    typedef struct {
        hpdcache_req_data_t  data;
        hpdcache_req_be_t    be;
        bit                  error;
    } shadow_entry_t;

    shadow_entry_t m_memory[hpdcache_req_addr_t];

    hpdcache_req_mon_t m_inflight[hpdcache_req_tid_t][$];

    bit m_error[hpdcache_set_t][hpdcache_tag_t];

    int m_req_counter;
    int m_rsp_counter;
    int m_pass_counter;
    int m_fail_counter;

    event reset_asserted;
    event reset_deasserted;

    function new(string name = "hpdcache_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        af_hpdcache_req = new("af_hpdcache_req", this);
        af_hpdcache_rsp = new("af_hpdcache_rsp", this);
        m_req_counter   = 0;
        m_rsp_counter   = 0;
        m_pass_counter  = 0;
        m_fail_counter  = 0;
        `uvm_info("SB", "Build phase complete.", UVM_LOW)
    endfunction

    virtual task pre_reset_phase(uvm_phase phase);
        super.pre_reset_phase(phase);
        -> reset_asserted;
    endtask

    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        m_memory.delete();
        m_inflight.delete();
        m_error.delete();
        af_hpdcache_req.flush();
        af_hpdcache_rsp.flush();
        m_req_counter  = 0;
        m_rsp_counter  = 0;
        m_pass_counter = 0;
        m_fail_counter = 0;
        `uvm_info("SB", "Reset phase complete.", UVM_LOW)
    endtask

    virtual task post_reset_phase(uvm_phase phase);
        super.post_reset_phase(phase);
        -> reset_deasserted;
    endtask

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        fork
            process_req();
            process_rsp();
        join_none
        `uvm_info("SB", "Main phase started.", UVM_LOW)
    endtask

    virtual task process_req();
        hpdcache_req_mon_t req;
        hpdcache_set_t     set;
        hpdcache_tag_t     tag;

        forever begin
            af_hpdcache_req.get(req);

            if (req.phys_indexed == 1'b0 && req.second_cycle == 1'b1) begin
                if (m_inflight.exists(req.tid) && m_inflight[req.tid].size() > 0) begin
                    m_inflight[req.tid][$].addr     = req.addr;
                    m_inflight[req.tid][$].addr_tag = req.addr_tag;
                end
                continue;
            end

            set = req.addr[UVM_CL_OFFSET_WIDTH +: UVM_SET_WIDTH];
            tag = req.addr_tag;

            m_req_counter++;

            if (req.need_rsp)
                m_inflight[req.tid].push_back(req);

            // ---------------------------------------------------------------
            // STORE: update shadow memory
            // ---------------------------------------------------------------
            if (req.op == hpdcache_pkg::HPDCACHE_REQ_STORE) begin
                shadow_entry_t entry;
                hpdcache_req_addr_t key = req.addr;

                if (m_memory.exists(key))
                    entry = m_memory[key];
                else begin
                    entry.data  = '0;
                    entry.be    = '0;
                    entry.error = 1'b0;
                end

                foreach (req.be[i, j]) begin
                    if (req.be[i][j]) begin
                        entry.data[i][j*8 +: 8] = req.wdata[i][j*8 +: 8];
                        entry.be[i][j]           = 1'b1;
                    end
                end

                m_memory[key] = entry;

                if (!req.pma.uncacheable)
                    m_error[set][tag] = 1'b0;

                `uvm_info("SB",
                    $sformatf("STORE shadow: PA=0x%08h SET=%0d TAG=0x%05h WDATA=0x%016h BE=0x%02h",
                              req.addr, set, tag, req.wdata, req.be),
                    UVM_HIGH)
            end
        end
    endtask : process_req

    virtual task process_rsp();
        hpdcache_rsp_t     rsp;
        hpdcache_req_mon_t req;
        hpdcache_set_t     set;
        hpdcache_tag_t     tag;

        forever begin
            af_hpdcache_rsp.get(rsp);
            m_rsp_counter++;

            if (!m_inflight.exists(rsp.tid) || m_inflight[rsp.tid].size() == 0) begin
                `uvm_error("SB",
                    $sformatf("UNSOLICITED RSP: TID=%0d SID=%0d — no matching request",
                              rsp.tid, rsp.sid))
                continue;
            end

            req = m_inflight[rsp.tid].pop_front();
            set = req.addr[UVM_CL_OFFSET_WIDTH +: UVM_SET_WIDTH];
            tag = req.addr_tag;

            // ---------------------------------------------------------------
            // Error bit check
            // ---------------------------------------------------------------
            if (req.op == hpdcache_pkg::HPDCACHE_REQ_LOAD ||
                (req.op == hpdcache_pkg::HPDCACHE_REQ_STORE && req.pma.uncacheable)) begin

                bit exp_err = (m_error.exists(set) && m_error[set].exists(tag))
                              ? m_error[set][tag] : 1'b0;

                if (rsp.error !== exp_err) begin
                    `uvm_error("SB",
                        $sformatf("ERROR BIT MISMATCH: PA=0x%08h SET=%0d TAG=0x%05h EXP=%0b GOT=%0b",
                                  req.addr, set, tag, exp_err, rsp.error))
                    m_fail_counter++;
                end
            end

            // ---------------------------------------------------------------
            // Data check: LOAD
            // ---------------------------------------------------------------
            if (req.op == hpdcache_pkg::HPDCACHE_REQ_LOAD && rsp.error == 1'b0) begin
                check_load_data(req, rsp);
            end
        end
    endtask : process_rsp

    function void check_load_data(hpdcache_req_mon_t req, hpdcache_rsp_t rsp);
        hpdcache_set_t      set  = req.addr[UVM_CL_OFFSET_WIDTH +: UVM_SET_WIDTH];
        hpdcache_tag_t      tag  = req.addr_tag;
        hpdcache_req_addr_t key  = req.addr;
        bit                 fail = 1'b0;

        if (!m_memory.exists(key)) begin
            `uvm_info("SB",
                $sformatf("LOAD PA=0x%08h: cold miss / no shadow entry (skip data check)",
                          req.addr),
                UVM_HIGH)
            return;
        end

        begin
            shadow_entry_t entry = m_memory[key];

            foreach (req.be[i, j]) begin
                if (req.be[i][j] && entry.be[i][j]) begin
                    if (rsp.rdata[i][j*8 +: 8] !== entry.data[i][j*8 +: 8]) begin
                        `uvm_error("SB",
                            $sformatf("DATA MISMATCH: PA=0x%08h BYTE[%0d] EXP=0x%02h GOT=0x%02h",
                                      req.addr, j + i*(UVM_HPDCACHE_WORD_WIDTH/8),
                                      entry.data[i][j*8 +: 8],
                                      rsp.rdata[i][j*8 +: 8]))
                        fail = 1'b1;
                    end
                end
            end

            if (fail) begin
                m_fail_counter++;
                `uvm_error("SB",
                    $sformatf("LOAD FAIL: PA=0x%08h SET=%0d TAG=0x%05h TID=%0d",
                              req.addr, set, tag, req.tid))
            end else begin
                m_pass_counter++;
                `uvm_info("SB",
                    $sformatf("LOAD PASS: PA=0x%08h SET=%0d TAG=0x%05h TID=%0d RDATA=0x%016h",
                              req.addr, set, tag, req.tid, rsp.rdata),
                    UVM_MEDIUM)
            end
        end
    endfunction : check_load_data

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB", $sformatf(
            "\n========== SCOREBOARD REPORT ==========\n  REQ  : %0d\n  RSP  : %0d\n  PASS : %0d\n  FAIL : %0d\n=======================================",
            m_req_counter, m_rsp_counter, m_pass_counter, m_fail_counter),
            UVM_LOW)
        if (m_fail_counter > 0)
            `uvm_error("SB", "TEST FAILED: Data/error mismatches detected!")
        else if (m_rsp_counter > 0)
            `uvm_info("SB", "TEST PASSED!", UVM_LOW)
    endfunction

endclass : hpdcache_scoreboard

`endif // HPDCACHE_SCOREBOARD_SV
