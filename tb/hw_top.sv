// =============================================================================
// hw_top.sv
// Hardware top: CV32E40P (optional) + HPDcache DUT + Behavioral AXI Memory Model
//
// Architecture:
//   CV32E40P (32-bit RISC-V) → OBI Interface → HPDcache Wrapper → AXI Memory
//
// HPDCache Configuration (from hpdcache_config.svh):
//   - 64 sets × 8 ways = 32 KB D-Cache
//   - 64 byte cacheline (8 words × 8 bytes)
//   - 56-bit physical address (from wrapper)
//   - 512-bit AXI data width (8 words × 64 bits)
//   - Domino Prefetcher with MHT1/MHT2 patterns
//
// Phase 1 (Current - HPDcache-only):
//   - DUT: hpdcache_wrapper (D-cache only)
//   - Stimulus: Mock transaction generator (UVM testbench)
//   - No CV32E40P core (can be integrated in Phase 2)
//
// AXI Memory Model:
//   - Read FIFO: depth=16 (MSHR_SETS × MSHR_WAYS = 4 × 4)
//   - Write Response FIFO: depth=4 (WBUF_DIR_ENTRIES)
//   - Shadow memory: indexed by cacheline address [55:6]
// =============================================================================
`timescale 1ns/1ps

module hw_top;

    // =========================================================================
    // Configuration Parameters
    // From: hpdcache_config.svh + hpdcache_uvm_pkg.sv
    // =========================================================================

    // Physical address & data width (HPDCache)
    localparam int unsigned PA_WIDTH       = 56;    // Physical address width
    localparam int unsigned MEM_AW         = 56;    // Memory address width (same as PA_WIDTH)
    localparam int unsigned MEM_DW         = 512;   // Memory data width (AXI)
    localparam int unsigned MEM_IDW        = 8;     // Memory ID width (AXI)

    // Cache line configuration
    localparam int unsigned CL_WORDS       = 8;     // Words per cache line (CL_WORDS)
    localparam int unsigned WORD_WIDTH     = 64;    // Bits per word
    localparam int unsigned CL_BYTES       = CL_WORDS * (WORD_WIDTH / 8);  // 64 bytes
    localparam int unsigned AXI_BYTES      = MEM_DW / 8;                   // 64 bytes
    localparam int unsigned BEATS_PER_CL   = CL_BYTES / AXI_BYTES;         // 1 beat

    // MSHR (Miss Status Hold Register) - max outstanding read requests
    localparam int unsigned MSHR_SETS      = 4;     // MSHR set bits
    localparam int unsigned MSHR_WAYS      = 4;     // MSHR ways per set
    localparam int unsigned RD_FIFO_DEPTH  = MSHR_SETS * MSHR_WAYS;  // 16

    // Write buffer configuration
    localparam int unsigned WBUF_DIR_ENTRIES = 4;   // Write directory entries
    localparam int unsigned WBUF_TCW       = 4;     // Write buffer time counter width
    localparam int unsigned WR_RSP_DEPTH   = WBUF_DIR_ENTRIES;

    // Clock configuration
    localparam real CLK_PERIOD = 10.0; // ns (100 MHz)

    // =========================================================================
    // CLOCK & RESET GENERATION
    // =========================================================================
    logic clk_i;
    logic rst_ni;

    initial clk_i = 1'b0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    initial begin
        rst_ni = 1'b0;
        repeat (10) @(posedge clk_i);  // 10 cycles of reset
        @(negedge clk_i);
        rst_ni = 1'b1;
        $display("[HW_TOP] Reset released at %0t ns: rst_ni=%b", $time, rst_ni);
    end

    // =========================================================================
    // INTERFACE INSTANTIATION
    // =========================================================================
    hpdcache_if dut_if (.clk_i(clk_i), .rst_ni(rst_ni));

    // =========================================================================
    // DUT INSTANTIATION: HPDcache Wrapper
    // =========================================================================
    // Intermediate signal: wbuf_threshold_i is 8-bit in wrapper
    // (wbuf_timecnt_t = logic unsigned [7:0] from CONF_HPDCACHE_WBUF_TIMECNT_WIDTH)
    logic [7:0] wbuf_threshold_8b;
    assign wbuf_threshold_8b = dut_if.cfg_wbuf_threshold_i[7:0];

    hpdcache_wrapper i_dut (
        .clk_i                              (clk_i),
        .rst_ni                             (rst_ni),

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
        .cfg_wbuf_threshold_i               (wbuf_threshold_8b),
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

        // Initialize configuration signals (CRITICAL: enable cache!)
        dut_if.cfg_enable_i                        = 1'b1;   // ENABLE CACHE
        dut_if.cfg_wbuf_threshold_i                = 8'd4;   // Default threshold (8-bit)
        dut_if.cfg_wbuf_reset_timecnt_on_write_i   = 1'b0;
        dut_if.cfg_wbuf_sequential_waw_i           = 1'b1;
        dut_if.cfg_wbuf_inhibit_write_coalescing_i = 1'b0;
        dut_if.cfg_prefetch_updt_plru_i            = 1'b1;
        dut_if.cfg_error_on_cacheable_amo_i        = 1'b0;
        dut_if.cfg_rtab_single_entry_i             = 1'b0;
        dut_if.cfg_default_wb_i                    = 1'b1;  // Write-back mode
        dut_if.cfg_scrub_enable_i                  = 1'b0;
        dut_if.cfg_scrub_period_i                  = 6'd0;
        dut_if.cfg_scrub_restart_i                 = 1'b0;
        dut_if.wbuf_flush_i                        = 1'b0;

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
            @(posedge clk_i);
            if (!rst_ni) begin
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
            @(posedge clk_i);
            if (!rst_ni) begin
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
                @(negedge clk_i);
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
                        @(negedge clk_i);
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
                        @(negedge clk_i);
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
                @(posedge clk_i);
                if (!rst_ni) begin
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
                @(posedge clk_i);
                if (!rst_ni) begin
                    wr_rsp_serving = 1'b0;
                    dut_if.mem_resp_write_valid_i = 1'b0;
                end else if (!wr_rsp_serving && wr_fifo_cnt > 0) begin
                    cur_b          = wr_fifo[wr_fifo_rd_ptr];
                    wr_fifo_rd_ptr = (wr_fifo_rd_ptr + 1) % WR_RSP_DEPTH;
                    wr_fifo_cnt--;
                    wr_rsp_serving = 1'b1;
                    @(negedge clk_i);
                    dut_if.mem_resp_write_valid_i     = 1'b1;
                    dut_if.mem_resp_write_id_i        = cur_b.id;
                    dut_if.mem_resp_write_error_i     = hpdcache_pkg::hpdcache_mem_error_e'(0);
                    dut_if.mem_resp_write_is_atomic_i = 1'b0;
                end else if (wr_rsp_serving) begin
                    if (dut_if.mem_resp_write_valid_i && dut_if.mem_resp_write_ready_o) begin
                        $display("[MEM @%0t] WR RESP: id=%0d", $time, cur_b.id);
                        @(negedge clk_i);
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
