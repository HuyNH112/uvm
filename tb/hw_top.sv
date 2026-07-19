// =============================================================================
// hw_top.sv
// Hardware top: DUT (hpdcache_wrapper) + Behavioral AXI Memory Model
//
// CRITICAL FIXES vs. bug report:
//   FIX-1: mem_resp_read_ready_o là OUTPUT của DUT — memory model POLL sẵn
//           Không drive vào DUT, chỉ sample. Serve beat CHỈ KHI DUT assert.
//   FIX-2: FIFO depth = MSHR_SETS × MSHR_WAYS = 4 × 4 = 16 outstanding misses
//   FIX-3: shadow_mem[addr] indexed bằng cacheline address (addr[55:6])
//          để lookup đúng 64 bytes per cacheline cho 512-bit AXI burst
//   FIX-4: Write response ACK: chờ mem_resp_write_ready_o trước khi assert valid
//
// AXI Read Protocol:
//   DUT → mem_req_read_valid_o + addr/id → ENQ vào rd_fifo[]
//   Memory → DEQ khi idle → serve N beats (512-bit × len) → DUT
//   Mỗi beat: assert valid, đợi DUT ready (mem_resp_read_ready_o=1), deassert
//
// AXI Write Protocol:
//   DUT → mem_req_write_valid_o + data valid → capture + ACK
// =============================================================================
`include "hpdcache_config.svh"
`include "hpdcache_typedef.svh"

module hw_top;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int unsigned MEM_AW       = `CONF_HPDCACHE_MEM_ADDR_WIDTH;  // 56
    localparam int unsigned MEM_DW       = `CONF_HPDCACHE_MEM_DATA_WIDTH;  // 512
    localparam int unsigned MEM_IDW      = `CONF_HPDCACHE_MEM_ID_WIDTH;    // 8
    localparam int unsigned CL_WORDS     = `CONF_HPDCACHE_CL_WORDS;        // 8
    localparam int unsigned WORD_W       = `CONF_HPDCACHE_WORD_WIDTH;       // 64
    localparam int unsigned CL_BYTES     = CL_WORDS * (WORD_W / 8);        // 64
    localparam int unsigned AXI_BYTES    = MEM_DW / 8;                     // 64
    // Number of AXI beats per cacheline refill
    localparam int unsigned BEATS_PER_CL = CL_BYTES / AXI_BYTES;           // 1
    // MSHR: max outstanding misses
    localparam int unsigned RD_FIFO_DEPTH = `CONF_HPDCACHE_MSHR_SETS
                                          * `CONF_HPDCACHE_MSHR_WAYS;      // 16
    localparam int unsigned WBUF_TCW     = `CONF_HPDCACHE_WBUF_TIMECNT_WIDTH;

    // Clock / Reset
    localparam real CLK_PERIOD = 10.0; // ns

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk);  // 10 cycles reset
        @(negedge clk);
        rst_n = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Interface instantiation
    // -------------------------------------------------------------------------
    hpdcache_if dut_if (.clk_i(clk), .rst_ni(rst_n));
	
	// -------------------------------------------------------------------------
    // RVFI Interface instantiation (CVA6 Core observation)
    // -------------------------------------------------------------------------
    cva6_rvfi_if rvfi_vif (.clk_i(clk), .rst_ni(rst_n));
    
    // Placeholder: Connect RVFI signals from CVA6 core
    // CRITICAL: This assumes CVA6 has rvfi_probes_o or similar output
    // If core is not directly instantiated in hw_top, remove these assigns
    // and handle in top-level integration
    
    // assign rvfi_vif.commit_valid    = /* from CVA6 */;
    // assign rvfi_vif.commit_pc       = /* from CVA6 */;
    // assign rvfi_vif.commit_pc_next  = /* from CVA6 */;
    // assign rvfi_vif.commit_instr    = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_addr  = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_we    = /* from CVA6 */;
    // assign rvfi_vif.commit_rd_wdata = /* from CVA6 */;
    // assign rvfi_vif.exception_valid = /* from CVA6 */;
    // assign rvfi_vif.mcause          = /* from CVA6 */;
    // assign rvfi_vif.mepc            = /* from CVA6 */;
    // assign rvfi_vif.csr_valid       = /* from CVA6 */;
    // assign rvfi_vif.csr_addr        = /* from CVA6 */;
    // assign rvfi_vif.csr_wdata       = /* from CVA6 */;
    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    // Intermediate signal: wbuf_threshold_i là 4-bit trong wrapper
    // (wbuf_timecnt_t = logic unsigned [3:0]). Interface signal có thể
    // khác origin typedef → Questa vsim-3015. Dùng explicit 4-bit slice.
    logic [3:0] wbuf_threshold_4b;
    assign wbuf_threshold_4b = dut_if.cfg_wbuf_threshold_i[3:0];

    hpdcache_wrapper i_dut (
        .clk_i                              (clk),
        .rst_ni                             (rst_n),

        .wbuf_flush_i                       (dut_if.wbuf_flush_i),

        // Core request
        .core_req_valid_i                   (dut_if.core_req_valid_i),
        .core_req_ready_o                   (dut_if.core_req_ready_o),
        .core_req_i                         (dut_if.core_req_i),
        .core_req_abort_i                   (dut_if.core_req_abort_i),
        .core_req_tag_i                     (dut_if.core_req_tag_i),
        .core_req_pma_i                     (dut_if.core_req_pma_i),

        // Core response
        .core_rsp_valid_o                   (dut_if.core_rsp_valid_o),
        .core_rsp_o                         (dut_if.core_rsp_o),

        // Memory read
        .mem_req_read_ready_i               (dut_if.mem_req_read_ready_i),
        .mem_req_read_valid_o               (dut_if.mem_req_read_valid_o),
        .mem_req_read_addr_o                (dut_if.mem_req_read_addr_o),
        .mem_req_read_len_o                 (dut_if.mem_req_read_len_o),
        .mem_req_read_size_o                (dut_if.mem_req_read_size_o),
        .mem_req_read_id_o                  (dut_if.mem_req_read_id_o),
        .mem_req_read_command_o             (dut_if.mem_req_read_command_o),
        .mem_req_read_atomic_o              (dut_if.mem_req_read_atomic_o),
        .mem_req_read_cacheable_o           (dut_if.mem_req_read_cacheable_o),

        .mem_resp_read_ready_o              (dut_if.mem_resp_read_ready_o),  // DUT OUTPUT
        .mem_resp_read_valid_i              (dut_if.mem_resp_read_valid_i),
        .mem_resp_read_error_i              (dut_if.mem_resp_read_error_i),
        .mem_resp_read_id_i                 (dut_if.mem_resp_read_id_i),
        .mem_resp_read_data_i               (dut_if.mem_resp_read_data_i),
        .mem_resp_read_last_i               (dut_if.mem_resp_read_last_i),

        // Memory write
        .mem_req_write_ready_i              (dut_if.mem_req_write_ready_i),
        .mem_req_write_valid_o              (dut_if.mem_req_write_valid_o),
        .mem_req_write_addr_o               (dut_if.mem_req_write_addr_o),
        .mem_req_write_len_o                (dut_if.mem_req_write_len_o),
        .mem_req_write_size_o               (dut_if.mem_req_write_size_o),
        .mem_req_write_id_o                 (dut_if.mem_req_write_id_o),
        .mem_req_write_command_o            (dut_if.mem_req_write_command_o),
        .mem_req_write_atomic_o             (dut_if.mem_req_write_atomic_o),
        .mem_req_write_cacheable_o          (dut_if.mem_req_write_cacheable_o),

        .mem_req_write_data_ready_i         (dut_if.mem_req_write_data_ready_i),
        .mem_req_write_data_valid_o         (dut_if.mem_req_write_data_valid_o),
        .mem_req_write_data_o               (dut_if.mem_req_write_data_o),
        .mem_req_write_be_o                 (dut_if.mem_req_write_be_o),
        .mem_req_write_last_o               (dut_if.mem_req_write_last_o),

        .mem_resp_write_ready_o             (dut_if.mem_resp_write_ready_o),  // DUT OUTPUT
        .mem_resp_write_valid_i             (dut_if.mem_resp_write_valid_i),
        .mem_resp_write_is_atomic_i         (dut_if.mem_resp_write_is_atomic_i),
        .mem_resp_write_error_i             (dut_if.mem_resp_write_error_i),
        .mem_resp_write_id_i                (dut_if.mem_resp_write_id_i),

        // Performance events
        .evt_cache_write_miss_o             (dut_if.evt_cache_write_miss_o),
        .evt_cache_read_miss_o              (dut_if.evt_cache_read_miss_o),
        .evt_cache_dir_unc_err_o            (dut_if.evt_cache_dir_unc_err_o),
        .evt_cache_dir_cor_err_o            (dut_if.evt_cache_dir_cor_err_o),
        .evt_cache_dat_unc_err_o            (dut_if.evt_cache_dat_unc_err_o),
        .evt_cache_dat_cor_err_o            (dut_if.evt_cache_dat_cor_err_o),
        .evt_scrub_complete_o               (dut_if.evt_scrub_complete_o),
        .evt_uncached_req_o                 (dut_if.evt_uncached_req_o),
        .evt_cmo_req_o                      (dut_if.evt_cmo_req_o),
        .evt_write_req_o                    (dut_if.evt_write_req_o),
        .evt_read_req_o                     (dut_if.evt_read_req_o),
        .evt_prefetch_req_o                 (dut_if.evt_prefetch_req_o),
        .evt_req_on_hold_o                  (dut_if.evt_req_on_hold_o),
        .evt_rtab_rollback_o                (dut_if.evt_rtab_rollback_o),
        .evt_stall_refill_o                 (dut_if.evt_stall_refill_o),
        .evt_stall_o                        (dut_if.evt_stall_o),
        .wbuf_empty_o                       (dut_if.wbuf_empty_o),

        // Config
        .cfg_enable_i                       (dut_if.cfg_enable_i),
        .cfg_wbuf_threshold_i               (wbuf_threshold_4b),
        .cfg_wbuf_reset_timecnt_on_write_i  (dut_if.cfg_wbuf_reset_timecnt_on_write_i),
        .cfg_wbuf_sequential_waw_i          (dut_if.cfg_wbuf_sequential_waw_i),
        .cfg_wbuf_inhibit_write_coalescing_i(dut_if.cfg_wbuf_inhibit_write_coalescing_i),
        .cfg_prefetch_updt_plru_i           (dut_if.cfg_prefetch_updt_plru_i),
        .cfg_error_on_cacheable_amo_i       (dut_if.cfg_error_on_cacheable_amo_i),
        .cfg_rtab_single_entry_i            (dut_if.cfg_rtab_single_entry_i),
        .cfg_default_wb_i                   (dut_if.cfg_default_wb_i),
        .cfg_scrub_enable_i                 (dut_if.cfg_scrub_enable_i),
        .cfg_scrub_period_i                 (dut_if.cfg_scrub_period_i),
        .cfg_scrub_restart_i                (dut_if.cfg_scrub_restart_i)
    );

    // -------------------------------------------------------------------------
    // Behavioral AXI Memory Model
    // -------------------------------------------------------------------------
    // Shadow memory: indexed bằng cacheline address (addr >> log2(CL_BYTES))
    // Mỗi entry = 1 cacheline = CL_BYTES bytes = MEM_DW bits (512-bit cho 1 beat)
    // Note: BEATS_PER_CL=1 khi MEM_DW=512 và CL_BYTES=64
    logic [MEM_DW-1:0] mem_model [logic [MEM_AW-1:0]];

    // Read FIFO
    typedef struct {
        logic [MEM_AW-1:0]  addr;
        logic [MEM_IDW-1:0] id;
        logic [7:0]         len;    // AXI burst length - 1
    } rd_req_t;

    rd_req_t  rd_fifo [0:RD_FIFO_DEPTH-1];
    int       rd_fifo_wr_ptr;
    int       rd_fifo_rd_ptr;
    int       rd_fifo_cnt;
    logic     rd_serving;
    rd_req_t  rd_current;
    int       rd_beat_cnt;

    // Write RSP FIFO — depth >= WBUF_DIR_ENTRIES=4
    localparam int unsigned WR_RSP_DEPTH = `CONF_HPDCACHE_WBUF_DIR_ENTRIES;

    typedef struct {
        logic [MEM_AW-1:0]  addr;
        logic [MEM_IDW-1:0] id;
    } wr_entry_t;

    wr_entry_t  wr_fifo     [0:WR_RSP_DEPTH-1];
    int         wr_fifo_wr_ptr;
    int         wr_fifo_rd_ptr;
    int         wr_fifo_cnt;
    logic       wr_rsp_serving;

    initial begin
        rd_fifo_wr_ptr = 0;
        rd_fifo_rd_ptr = 0;
        rd_fifo_cnt    = 0;
        rd_serving      = 1'b0;
        rd_beat_cnt     = 0;
        wr_fifo_wr_ptr  = 0;
        wr_fifo_rd_ptr  = 0;
        wr_fifo_cnt     = 0;
        wr_rsp_serving  = 1'b0;

        // Initialize mem_resp response signals (tb side)
        dut_if.mem_resp_read_valid_i    = 1'b0;
        dut_if.mem_resp_read_error_i  = hpdcache_pkg::hpdcache_mem_error_e'(0);
        dut_if.mem_resp_read_id_i       = '0;
        dut_if.mem_resp_read_data_i     = '0;
        dut_if.mem_resp_read_last_i     = 1'b0;
        dut_if.mem_resp_write_valid_i   = 1'b0;
        dut_if.mem_resp_write_error_i = hpdcache_pkg::hpdcache_mem_error_e'(0);
        dut_if.mem_resp_write_id_i      = '0;
        dut_if.mem_resp_write_is_atomic_i = 1'b0;

        // Accept all DUT read/write requests (memory always ready)
        dut_if.mem_req_read_ready_i         = 1'b1;
        dut_if.mem_req_write_ready_i        = 1'b1;
        dut_if.mem_req_write_data_ready_i   = 1'b1;

        fork
            axi_read_req_enqueue();
            axi_read_resp_serve();
            axi_write_handle();
        join_none
    end

    // -------------------------------------------------------------------------
    // AXI Read: ENQ requests into FIFO
    // -------------------------------------------------------------------------
    task automatic axi_read_req_enqueue();
        forever begin
            @(posedge clk);
            if (!rst_n) begin
                rd_fifo_wr_ptr = 0; rd_fifo_rd_ptr = 0; rd_fifo_cnt = 0;
            end else if (dut_if.mem_req_read_valid_o && dut_if.mem_req_read_ready_i) begin
                if (rd_fifo_cnt >= RD_FIFO_DEPTH) begin
                    $display("[MEM @%0t] ERROR: RD FIFO FULL! depth=%0d", $time, RD_FIFO_DEPTH);
                    // Backpressure: deassert ready (rare — normally MSHR limits to 16)
                    dut_if.mem_req_read_ready_i = 1'b0;
                end else begin
                    rd_fifo[rd_fifo_wr_ptr].addr = dut_if.mem_req_read_addr_o;
                    rd_fifo[rd_fifo_wr_ptr].id   = dut_if.mem_req_read_id_o;
                    rd_fifo[rd_fifo_wr_ptr].len  = dut_if.mem_req_read_len_o;
                    rd_fifo_wr_ptr = (rd_fifo_wr_ptr + 1) % RD_FIFO_DEPTH;
                    rd_fifo_cnt++;
                    dut_if.mem_req_read_ready_i = 1'b1;
                    $display("[MEM @%0t] RD FIFO ENQ: addr=0x%014h id=%0d len=%0d cnt=%0d",
                             $time, dut_if.mem_req_read_addr_o, dut_if.mem_req_read_id_o,
                             dut_if.mem_req_read_len_o, rd_fifo_cnt);
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // AXI Read: DEQ + SERVE beats
    // FIX-1: POLL dut_if.mem_resp_read_ready_o (DUT OUTPUT) trước khi serve
    // -------------------------------------------------------------------------
    task automatic axi_read_resp_serve();
        // FIX: AXI4 protocol — sender drives valid INDEPENDENTLY of ready.
        // Bug cũ: chờ ready_o=1 mới drive valid_i=1 → deadlock vì DUT
        // (hpdcache_miss_handler) chỉ assert ready_o sau khi thấy valid_i=1.
        // Fix: DEQ → drive valid+data ngay trên negedge → đợi posedge handshake
        //      (valid & ready) → advance beat. Deassert valid chỉ sau last beat.
        logic [MEM_AW-1:0] cl_addr;
        logic [MEM_DW-1:0] resp_data;

        forever begin
            @(posedge clk);
            if (!rst_n) begin
                rd_serving = 1'b0;
                dut_if.mem_resp_read_valid_i = 1'b0;
                dut_if.mem_resp_read_last_i  = 1'b0;
            end else if (!rd_serving && rd_fifo_cnt > 0) begin
                // DEQ next request
                rd_current     = rd_fifo[rd_fifo_rd_ptr];
                rd_fifo_rd_ptr = (rd_fifo_rd_ptr + 1) % RD_FIFO_DEPTH;
                rd_fifo_cnt--;
                rd_beat_cnt    = 0;
                rd_serving     = 1'b1;
                $display("[MEM @%0t] RD FIFO DEQ: addr=0x%014h id=%0d",
                         $time, rd_current.addr, rd_current.id);

                // Lookup data
                cl_addr = rd_current.addr >> $clog2(CL_BYTES);
                if (mem_model.exists(cl_addr))
                    resp_data = mem_model[cl_addr];
                else begin
                    mem_model[cl_addr] = {16{cl_addr[31:0]}};
                    resp_data = mem_model[cl_addr];
                end

                // Drive valid+data ngay trên negedge (không chờ ready_o)
                @(negedge clk);
                dut_if.mem_resp_read_valid_i = 1'b1;
                dut_if.mem_resp_read_id_i    = rd_current.id;
                dut_if.mem_resp_read_data_i  = resp_data;
                dut_if.mem_resp_read_error_i = hpdcache_pkg::hpdcache_mem_error_e'(0);
                dut_if.mem_resp_read_last_i  = (rd_current.len == 0) ? 1'b1 : 1'b0;

            end else if (rd_serving) begin
                // Handshake: beat accepted khi valid_i=1 && ready_o=1 tại posedge
                if (dut_if.mem_resp_read_valid_i && dut_if.mem_resp_read_ready_o) begin
                    $display("[MEM @%0t] RD SERVE beat=%0d/%0d id=%0d addr=0x%014h",
                             $time, rd_beat_cnt, rd_current.len,
                             rd_current.id, rd_current.addr);

                    if (rd_beat_cnt == rd_current.len) begin
                        // Last beat accepted → deassert valid
                        @(negedge clk);
                        dut_if.mem_resp_read_valid_i = 1'b0;
                        dut_if.mem_resp_read_last_i  = 1'b0;
                        rd_serving = 1'b0;
                        $display("[MEM @%0t] RD DONE: id=%0d", $time, rd_current.id);
                    end else begin
                        // Advance to next beat
                        rd_beat_cnt++;
                        cl_addr = (rd_current.addr >> $clog2(CL_BYTES)) + rd_beat_cnt;
                        if (mem_model.exists(cl_addr))
                            resp_data = mem_model[cl_addr];
                        else begin
                            mem_model[cl_addr] = {16{cl_addr[31:0]}};
                            resp_data = mem_model[cl_addr];
                        end
                        @(negedge clk);
                        dut_if.mem_resp_read_data_i = resp_data;
                        dut_if.mem_resp_read_last_i = (rd_beat_cnt == rd_current.len) ? 1'b1 : 1'b0;
                    end
                end
                // valid_i stays asserted until ready_o=1 (AXI4 rule: cannot deassert valid)
            end
        end
    endtask

    task automatic axi_write_handle();
        logic [MEM_AW-1:0]  cl_addr;
        wr_entry_t           cur_aw;
        wr_entry_t           cur_b;

        fork
            forever begin
                @(posedge clk);
                if (!rst_n) begin
                    wr_fifo_wr_ptr = 0;
                    wr_fifo_rd_ptr = 0;
                    wr_fifo_cnt    = 0;
                end else begin
                    if (dut_if.mem_req_write_valid_o && dut_if.mem_req_write_ready_i) begin
                        cur_aw.addr = dut_if.mem_req_write_addr_o;
                        cur_aw.id   = dut_if.mem_req_write_id_o;
                    end
                    if (dut_if.mem_req_write_data_valid_o && dut_if.mem_req_write_data_ready_i) begin
                        cl_addr = cur_aw.addr >> $clog2(CL_BYTES);
                        if (!mem_model.exists(cl_addr)) mem_model[cl_addr] = '0;
                        for (int b = 0; b < MEM_DW/8; b++) begin
                            if (dut_if.mem_req_write_be_o[b])
                                mem_model[cl_addr][b*8 +: 8] = dut_if.mem_req_write_data_o[b*8 +: 8];
                        end
                        $display("[MEM @%0t] WR: addr=0x%014h id=%0d last=%0b",
                                 $time, cur_aw.addr, cur_aw.id, dut_if.mem_req_write_last_o);
                        if (dut_if.mem_req_write_last_o) begin
                            if (wr_fifo_cnt < WR_RSP_DEPTH) begin
                                wr_fifo[wr_fifo_wr_ptr] = cur_aw;
                                wr_fifo_wr_ptr = (wr_fifo_wr_ptr + 1) % WR_RSP_DEPTH;
                                wr_fifo_cnt++;
                            end else
                                $display("[MEM @%0t] ERROR: WR RSP FIFO FULL!", $time);
                        end
                    end
                end
            end

            forever begin
                @(posedge clk);
                if (!rst_n) begin
                    wr_rsp_serving = 1'b0;
                    dut_if.mem_resp_write_valid_i = 1'b0;
                end else if (!wr_rsp_serving && wr_fifo_cnt > 0) begin
                    cur_b          = wr_fifo[wr_fifo_rd_ptr];
                    wr_fifo_rd_ptr = (wr_fifo_rd_ptr + 1) % WR_RSP_DEPTH;
                    wr_fifo_cnt--;
                    wr_rsp_serving = 1'b1;
                    @(negedge clk);
                    dut_if.mem_resp_write_valid_i     = 1'b1;
                    dut_if.mem_resp_write_id_i        = cur_b.id;
                    dut_if.mem_resp_write_error_i     = hpdcache_pkg::hpdcache_mem_error_e'(0);
                    dut_if.mem_resp_write_is_atomic_i = 1'b0;
                end else if (wr_rsp_serving) begin
                    if (dut_if.mem_resp_write_valid_i && dut_if.mem_resp_write_ready_o) begin
                        $display("[MEM @%0t] WR RESP: id=%0d", $time, cur_b.id);
                        @(negedge clk);
                        dut_if.mem_resp_write_valid_i = 1'b0;
                        wr_rsp_serving = 1'b0;
                    end
                end
            end
        join_none
    endtask

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("dump_hpdcache.vcd");
        $dumpvars(0, hw_top);
    end

endmodule : hw_top
