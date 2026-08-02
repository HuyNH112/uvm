// =============================================================================
// hpdcache_scoreboard.sv
// Self-checking scoreboard với shadow memory model
//
// Logic:
//   STORE → shadow_mem[PA] = data masked by BE
//   LOAD  → khi nhận RSP, compare DUT rdata với shadow_mem[PA]
//           Cold miss → skip (no reference data)
//           Hit → check byte-by-byte
//
// Dùng op_is_load/op_is_store helper functions từ pkg
// UVM 1.1d: run_phase, fork process_req + process_rsp
// =============================================================================

class hpdcache_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(hpdcache_scoreboard)

    // UVM 1.1d: uvm_tlm_analysis_fifo.analysis_export kiểu uvm_analysis_imp,
    // KHÔNG phải uvm_analysis_export → không thể gán chéo kiểu.
    // Fix: expose fifo.analysis_export trực tiếp, env connect vào đây.
    uvm_tlm_analysis_fifo #(hpdcache_seq_item) fifo_req;
    uvm_tlm_analysis_fifo #(hpdcache_seq_item) fifo_rsp;

    // Width shortcuts
    localparam int unsigned PA_W   = UVM_HPDCACHE_PA_WIDTH;           // 56
    localparam int unsigned DATA_W = UVM_REQ_DATA_WIDTH;              // 128
    localparam int unsigned BE_W   = UVM_REQ_BE_WIDTH;                // 16
    localparam int unsigned TID_W  = UVM_HPDCACHE_REQ_TRANS_ID_WIDTH; // 6

    logic [DATA_W-1:0]  shadow_mem [logic [PA_W-1:0]];
    logic [BE_W-1:0]    shadow_be  [logic [PA_W-1:0]];
    logic [PA_W-1:0]    pending_load [logic [TID_W-1:0]];

    int unsigned cnt_req, cnt_rsp, cnt_pass, cnt_fail, cnt_cold_miss;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cnt_req = 0; cnt_rsp = 0; cnt_pass = 0;
        cnt_fail = 0; cnt_cold_miss = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_req = new("fifo_req", this);
        fifo_rsp = new("fifo_rsp", this);
        // env.connect_phase kết nối monitor.ap_req → scoreboard.fifo_req.analysis_export
        // và monitor.ap_rsp → scoreboard.fifo_rsp.analysis_export trực tiếp
    endfunction

    task run_phase(uvm_phase phase);
        fork
            process_req();
            process_rsp();
        join_none
    endtask

    // -------------------------------------------------------------------------
    // process_req
    // -------------------------------------------------------------------------
    task process_req();
        hpdcache_seq_item item;
        logic [PA_W-1:0] pa;
        forever begin
            fifo_req.get(item);
            cnt_req++;
            pa = item.get_pa();

            if (is_store(item.op)) begin
                if (!shadow_mem.exists(pa)) begin
                    shadow_mem[pa] = '0;
                    shadow_be[pa]  = '0;
                end
                for (int b = 0; b < BE_W; b++) begin
                    if (item.be[b]) begin
                        shadow_mem[pa][b*8 +: 8] = item.wdata[b*8 +: 8];
                        shadow_be[pa][b]          = 1'b1;
                    end
                end
                `uvm_info("SB",
                    $sformatf("STORE: PA=0x%014h DATA=0x%032h BE=0x%04h",
                              pa, item.wdata, item.be),
                    UVM_HIGH)

            end else if (is_load(item.op) && item.need_rsp) begin
                // Track pending LOAD: TID → PA
                if (pending_load.exists(item.tid))
                    `uvm_warning("SB",
                        $sformatf("TID=%0d already pending (collision?)", item.tid))
                pending_load[item.tid] = pa;
                `uvm_info("SB",
                    $sformatf("LOAD req: PA=0x%014h TID=%0d", pa, item.tid),
                    UVM_HIGH)

            end else if (is_cmo(item.op)) begin
                `uvm_info("SB",
                    $sformatf("CMO/PREFETCH: PA=0x%014h TID=%0d", pa, item.tid),
                    UVM_HIGH)
                // Prefetch không tạo response → không track

            end else if (is_amo(item.op)) begin
                `uvm_info("SB",
                    $sformatf("AMO: PA=0x%014h TID=%0d (not data-checked)", pa, item.tid),
                    UVM_MEDIUM)
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // process_rsp
    // -------------------------------------------------------------------------
    task process_rsp();
        hpdcache_seq_item rsp;
        logic [PA_W-1:0]   pa;
        logic [DATA_W-1:0] expected;
        int                check_ok;

        forever begin
            fifo_rsp.get(rsp);
            cnt_rsp++;

            if (!pending_load.exists(rsp.tid)) begin
                `uvm_warning("SB",
                    $sformatf("RSP TID=%0d: no pending LOAD — skip", rsp.tid))
                continue;
            end

            pa = pending_load[rsp.tid];
            pending_load.delete(rsp.tid);

            if (!shadow_mem.exists(pa)) begin
                cnt_cold_miss++;
                `uvm_info("SB",
                    $sformatf("COLD MISS: PA=0x%014h TID=%0d RDATA=0x%032h (no ref)",
                              pa, rsp.tid, rsp.wdata),
                    UVM_MEDIUM)
                continue;
            end

            expected = shadow_mem[pa];
            check_ok = 1;
            for (int b = 0; b < BE_W; b++) begin
                if (shadow_be[pa][b]) begin
                    if (^(rsp.wdata[b*8 +: 8]) === 1'bx) continue;
                    if ((rsp.wdata[b*8 +: 8] & 8'hFF) !== (expected[b*8 +: 8] & 8'hFF)) begin
                        check_ok = 0;
                        `uvm_error("SB",
                            $sformatf("MISMATCH: PA=0x%014h TID=%0d byte[%0d] GOT=0x%02h EXP=0x%02h",
                                pa, rsp.tid, b,
                                rsp.wdata[b*8 +: 8] & 8'hFF,
                                expected[b*8 +: 8] & 8'hFF))
                    end
                end
            end

            if (check_ok) begin
                cnt_pass++;
                `uvm_info("SB",
                    $sformatf("LOAD PASS: PA=0x%014h TID=%0d RDATA=0x%032h",
                              pa, rsp.tid, rsp.wdata),
                    UVM_MEDIUM)
            end else begin
                cnt_fail++;
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf(
            "\n========== SCOREBOARD REPORT ==========\n  REQ       : %0d\n  RSP       : %0d\n  PASS      : %0d\n  FAIL      : %0d\n  COLD MISS : %0d\n=======================================\n[SB] %s",
            cnt_req, cnt_rsp, cnt_pass, cnt_fail, cnt_cold_miss,
            (cnt_fail == 0) ? "TEST PASSED!" : "TEST FAILED!"),
            UVM_NONE)
        if (cnt_fail > 0)
            `uvm_error("SB", $sformatf("%0d data mismatches!", cnt_fail))
    endfunction

endclass : hpdcache_scoreboard
