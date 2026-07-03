`timescale 1ns/1ps
`include "hpdcache_typedef.svh"
`include "hpdcache_config.svh"

module hw_top
import hpdcache_pkg::*;
(
    input  bit clk_i,
    input  bit rst_ni,
    hpdcache_if hpdcache_vif
);

    // =========================================================================
    // Config
    // =========================================================================
    localparam hpdcache_user_cfg_t UserCfg = '{
        nRequesters              : (4'b1 << `CONF_HPDCACHE_REQ_SRC_ID_WIDTH),
        paWidth                  : `CONF_HPDCACHE_PA_WIDTH,
        wordWidth                : `CONF_HPDCACHE_WORD_WIDTH,
        sets                     : `CONF_HPDCACHE_SETS,
        ways                     : `CONF_HPDCACHE_WAYS,
        clWords                  : `CONF_HPDCACHE_CL_WORDS,
        reqWords                 : `CONF_HPDCACHE_REQ_WORDS,
        reqTransIdWidth          : `CONF_HPDCACHE_REQ_TRANS_ID_WIDTH,
        reqSrcIdWidth            : `CONF_HPDCACHE_REQ_SRC_ID_WIDTH,
        victimSel                : `CONF_HPDCACHE_VICTIM_SEL,
        dataWaysPerRamWord       : `CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD,
        dataSetsPerRam           : `CONF_HPDCACHE_DATA_SETS_PER_RAM,
        dataRamByteEnable        : `CONF_HPDCACHE_DATA_RAM_WBYTEENABLE,
        accessWords              : `CONF_HPDCACHE_ACCESS_WORDS,
        mshrSets                 : `CONF_HPDCACHE_MSHR_SETS,
        mshrWays                 : `CONF_HPDCACHE_MSHR_WAYS,
        mshrWaysPerRamWord       : `CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD,
        mshrSetsPerRam           : `CONF_HPDCACHE_MSHR_SETS_PER_RAM,
        mshrRamByteEnable        : `CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE,
        mshrUseRegbank           : `CONF_HPDCACHE_MSHR_USE_REGBANK,
        cbufEntries              : `CONF_HPDCACHE_CBUF_ENTRIES,
        refillCoreRspFeedthrough : `CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH,
        refillFifoDepth          : `CONF_HPDCACHE_REFILL_FIFO_DEPTH,
        wbufDirEntries           : `CONF_HPDCACHE_WBUF_DIR_ENTRIES,
        wbufDataEntries          : `CONF_HPDCACHE_WBUF_DATA_ENTRIES,
        wbufWords                : `CONF_HPDCACHE_WBUF_WORDS,
        wbufTimecntWidth         : `CONF_HPDCACHE_WBUF_TIMECNT_WIDTH,
        rtabEntries              : `CONF_HPDCACHE_RTAB_ENTRIES,
        flushEntries             : `CONF_HPDCACHE_FLUSH_ENTRIES,
        flushFifoDepth           : `CONF_HPDCACHE_FLUSH_FIFO_DEPTH,
        memAddrWidth             : `CONF_HPDCACHE_MEM_ADDR_WIDTH,
        memIdWidth               : `CONF_HPDCACHE_MEM_ID_WIDTH,
        memDataWidth             : `CONF_HPDCACHE_MEM_DATA_WIDTH,
        wtEn                     : `CONF_HPDCACHE_WT_ENABLE,
        wbEn                     : `CONF_HPDCACHE_WB_ENABLE,
        lowLatency               : `CONF_HPDCACHE_LOW_LATENCY,
        eccEn                    : `CONF_HPDCACHE_ECC_ENABLE,
        eccScrubberEn            : `CONF_HPDCACHE_ECC_SCRUBBER_ENABLE
    };

    localparam hpdcache_cfg_t Cfg = hpdcacheBuildConfig(UserCfg);

    // =========================================================================
    // Local typedefs
    // =========================================================================
    localparam int unsigned MEM_ADDR_W = Cfg.u.memAddrWidth;
    localparam int unsigned MEM_ID_W   = Cfg.u.memIdWidth;
    localparam int unsigned MEM_DATA_W = Cfg.u.memDataWidth;
    localparam int unsigned MEM_BE_W   = Cfg.u.memDataWidth/8;

    typedef logic [MEM_ADDR_W-1:0] lc_mem_addr_t;
    typedef logic [MEM_ID_W-1:0]   lc_mem_id_t;
    typedef logic [MEM_DATA_W-1:0] lc_mem_data_t;
    typedef logic [MEM_BE_W-1:0]   lc_mem_be_t;

    // =========================================================================
    // Memory interface wires
    // =========================================================================

    // Read channel
    logic              mem_req_read_ready_i;
    logic              mem_req_read_valid_o;
    lc_mem_addr_t      mem_req_read_addr_o;
    hpdcache_mem_len_t     mem_req_read_len_o;
    hpdcache_mem_size_t    mem_req_read_size_o;
    lc_mem_id_t        mem_req_read_id_o;
    hpdcache_mem_command_e mem_req_read_command_o;
    hpdcache_mem_atomic_e  mem_req_read_atomic_o;
    logic              mem_req_read_cacheable_o;

    logic              mem_resp_read_ready_o;
    logic              mem_resp_read_valid_i;
    hpdcache_mem_error_e   mem_resp_read_error_i;
    lc_mem_id_t        mem_resp_read_id_i;
    lc_mem_data_t      mem_resp_read_data_i;
    logic              mem_resp_read_last_i;

    // Write channel
    logic              mem_req_write_ready_i;
    logic              mem_req_write_valid_o;
    lc_mem_addr_t      mem_req_write_addr_o;
    hpdcache_mem_len_t     mem_req_write_len_o;
    hpdcache_mem_size_t    mem_req_write_size_o;
    lc_mem_id_t        mem_req_write_id_o;
    hpdcache_mem_command_e mem_req_write_command_o;
    hpdcache_mem_atomic_e  mem_req_write_atomic_o;
    logic              mem_req_write_cacheable_o;

    logic              mem_req_write_data_ready_i;
    logic              mem_req_write_data_valid_o;
    lc_mem_data_t      mem_req_write_data_o;
    lc_mem_be_t        mem_req_write_be_o;
    logic              mem_req_write_last_o;

    logic              mem_resp_write_ready_o;
    logic              mem_resp_write_valid_i;
    logic              mem_resp_write_is_atomic_i;
    hpdcache_mem_error_e   mem_resp_write_error_i;
    lc_mem_id_t        mem_resp_write_id_i;

    // =========================================================================
    // DUT: hpdcache_wrapper
    // =========================================================================
    hpdcache_wrapper u_hpdcache (
        .clk_i                      (clk_i),
        .rst_ni                     (rst_ni),
        .wbuf_flush_i               (hpdcache_vif.wbuf_flush_i),
        .core_req_valid_i           (hpdcache_vif.core_req_valid_i),
        .core_req_ready_o           (hpdcache_vif.core_req_ready_o),
        .core_req_i                 (hpdcache_vif.core_req_i),
        .core_req_abort_i           (hpdcache_vif.core_req_abort_i),
        .core_req_tag_i             (hpdcache_vif.core_req_tag_i),
        .core_req_pma_i             (hpdcache_vif.core_req_pma_i),
        .core_rsp_valid_o           (hpdcache_vif.core_rsp_valid_o),
        .core_rsp_o                 (hpdcache_vif.core_rsp_o),
        
        .mem_req_read_ready_i       (mem_req_read_ready_i),
        .mem_req_read_valid_o       (mem_req_read_valid_o),
        .mem_req_read_addr_o        (mem_req_read_addr_o),
        .mem_req_read_len_o         (mem_req_read_len_o),
        .mem_req_read_size_o        (mem_req_read_size_o),
        .mem_req_read_id_o          (mem_req_read_id_o),
        .mem_req_read_command_o     (mem_req_read_command_o),
        .mem_req_read_atomic_o      (mem_req_read_atomic_o),
        .mem_req_read_cacheable_o   (mem_req_read_cacheable_o),
        
        .mem_resp_read_ready_o      (mem_resp_read_ready_o),
        .mem_resp_read_valid_i      (mem_resp_read_valid_i),
        .mem_resp_read_error_i      (mem_resp_read_error_i),
        .mem_resp_read_id_i         (mem_resp_read_id_i),
        .mem_resp_read_data_i       (mem_resp_read_data_i),
        .mem_resp_read_last_i       (mem_resp_read_last_i),
        
        .mem_req_write_ready_i      (mem_req_write_ready_i),
        .mem_req_write_valid_o      (mem_req_write_valid_o),
        .mem_req_write_addr_o       (mem_req_write_addr_o),
        .mem_req_write_len_o        (mem_req_write_len_o),
        .mem_req_write_size_o       (mem_req_write_size_o),
        .mem_req_write_id_o         (mem_req_write_id_o),
        .mem_req_write_command_o    (mem_req_write_command_o),
        .mem_req_write_atomic_o     (mem_req_write_atomic_o),
        .mem_req_write_cacheable_o  (mem_req_write_cacheable_o),
        
        .mem_req_write_data_ready_i (mem_req_write_data_ready_i),
        .mem_req_write_data_valid_o (mem_req_write_data_valid_o),
        .mem_req_write_data_o       (mem_req_write_data_o),
        .mem_req_write_be_o         (mem_req_write_be_o),
        .mem_req_write_last_o       (mem_req_write_last_o),
        
        .mem_resp_write_ready_o     (mem_resp_write_ready_o),
        .mem_resp_write_valid_i     (mem_resp_write_valid_i),
        .mem_resp_write_is_atomic_i (mem_resp_write_is_atomic_i),
        .mem_resp_write_error_i     (mem_resp_write_error_i),
        .mem_resp_write_id_i        (mem_resp_write_id_i),

        // ---------------------------------------------------------------------
        // Configuration tie-offs (Fix Lỗi 1)
        // ---------------------------------------------------------------------
        .cfg_enable_i                        (1'b1),
        .cfg_wbuf_threshold_i                ('0),
        .cfg_wbuf_reset_timecnt_on_write_i   (1'b0),
        .cfg_wbuf_sequential_waw_i           (1'b0),
        .cfg_wbuf_inhibit_write_coalescing_i (1'b0),
        .cfg_prefetch_updt_plru_i            (1'b0),
        .cfg_error_on_cacheable_amo_i        (1'b0),
        .cfg_rtab_single_entry_i             (1'b0),
        .cfg_default_wb_i                    (1'b0),
        .cfg_scrub_enable_i                  (1'b0),
        .cfg_scrub_period_i                  ('0),
        .cfg_scrub_restart_i                 (1'b0),

        // ---------------------------------------------------------------------
        // Status and Event float/open (Fix Lỗi 1)
        // ---------------------------------------------------------------------
        .wbuf_empty_o                        (),
        .evt_cache_write_miss_o              (),
        .evt_cache_read_miss_o               (),
        .evt_cache_dir_unc_err_o             (),
        .evt_cache_dir_cor_err_o             (),
        .evt_cache_dat_unc_err_o             (),
        .evt_cache_dat_cor_err_o             (),
        .evt_scrub_complete_o                (),
        .evt_uncached_req_o                  (),
        .evt_cmo_req_o                       (),
        .evt_write_req_o                     (),
        .evt_read_req_o                      (),
        .evt_prefetch_req_o                  (),
        .evt_req_on_hold_o                   (),
        .evt_rtab_rollback_o                 (),
        .evt_stall_refill_o                  (),
        .evt_stall_o                         ()
    );

    // =========================================================================
    // Behavioral SV memory model — 64KB
    // =========================================================================
    localparam int unsigned MEM_DEPTH    = 65536;
    localparam int unsigned BYTES_PER_BT = MEM_DATA_W / 8;  // 8

    logic [7:0] shadow_mem [0:MEM_DEPTH-1];

    // -- Read channel --
    logic         rd_pending;
    lc_mem_id_t   rd_id_q;
    lc_mem_addr_t rd_addr_q;
    int unsigned  rd_beats_total;
    int unsigned  rd_beat_cnt;

    assign mem_req_read_ready_i = 1'b1;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rd_pending            <= 1'b0;
            rd_id_q               <= '0;
            rd_addr_q             <= '0;
            rd_beats_total        <= 0;
            rd_beat_cnt           <= 0;
            mem_resp_read_valid_i <= 1'b0;
            mem_resp_read_error_i <= HPDCACHE_MEM_RESP_OK;
            mem_resp_read_id_i    <= '0;
            mem_resp_read_data_i  <= '0;
            mem_resp_read_last_i  <= 1'b0;
        end else begin
            mem_resp_read_valid_i <= 1'b0;
            mem_resp_read_last_i  <= 1'b0;

            if (mem_req_read_valid_o && mem_req_read_ready_i && !rd_pending) begin
                rd_id_q        <= mem_req_read_id_o;
                rd_addr_q      <= mem_req_read_addr_o;
                rd_beats_total <= int'(mem_req_read_len_o) + 1;
                rd_beat_cnt    <= 0;
                rd_pending     <= 1'b1;
            end

            if (rd_pending && mem_resp_read_ready_o) begin : blk_rd
                lc_mem_data_t rdata;
                lc_mem_addr_t beat_addr;
                int unsigned  idx;

                beat_addr = rd_addr_q + lc_mem_addr_t'(rd_beat_cnt * BYTES_PER_BT);

                for (int b = 0; b < BYTES_PER_BT; b++) begin
                    idx = int'(beat_addr) + b;
                    rdata[b*8 +: 8] = (idx < MEM_DEPTH) ? shadow_mem[idx] : 8'hxx;
                end

                mem_resp_read_valid_i <= 1'b1;
                mem_resp_read_error_i <= HPDCACHE_MEM_RESP_OK;
                mem_resp_read_id_i    <= rd_id_q;
                mem_resp_read_data_i  <= rdata;

                if (rd_beat_cnt == rd_beats_total - 1) begin
                    mem_resp_read_last_i <= 1'b1;
                    rd_pending           <= 1'b0;
                    rd_beat_cnt          <= 0;
                end else begin
                    rd_beat_cnt <= rd_beat_cnt + 1;
                end
            end
        end
    end

    // -- Write channel --
    assign mem_req_write_ready_i      = 1'b1;
    assign mem_req_write_data_ready_i = 1'b1;

    logic         wr_pending;
    lc_mem_id_t   wr_id_q;
    lc_mem_addr_t wr_addr_q;
    int unsigned  wr_beats_total;
    int unsigned  wr_beat_cnt;

    // Sửa Lỗi 2: Sử dụng always thay cho always_ff để chia sẻ biến với khối initial
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_pending                 <= 1'b0;
            wr_id_q                    <= '0;
            wr_addr_q                  <= '0;
            wr_beats_total             <= 0;
            wr_beat_cnt                <= 0;
            mem_resp_write_valid_i     <= 1'b0;
            mem_resp_write_is_atomic_i <= 1'b0;
            mem_resp_write_error_i     <= HPDCACHE_MEM_RESP_OK;
            mem_resp_write_id_i        <= '0;
        end else begin
            mem_resp_write_valid_i <= 1'b0;

            if (mem_req_write_valid_o && mem_req_write_ready_i && !wr_pending) begin
                wr_id_q        <= mem_req_write_id_o;
                wr_addr_q      <= mem_req_write_addr_o;
                wr_beats_total <= int'(mem_req_write_len_o) + 1;
                wr_beat_cnt    <= 0;
                wr_pending     <= 1'b1;
            end

            if (wr_pending && mem_req_write_data_valid_o && mem_req_write_data_ready_i) begin : blk_wr
                lc_mem_addr_t beat_addr;
                int unsigned  idx;

                beat_addr = wr_addr_q + lc_mem_addr_t'(wr_beat_cnt * BYTES_PER_BT);

                for (int b = 0; b < BYTES_PER_BT; b++) begin
                    idx = int'(beat_addr) + b;
                    if (mem_req_write_be_o[b] && idx < MEM_DEPTH)
                        shadow_mem[idx] <= mem_req_write_data_o[b*8 +: 8];
                end

                if (mem_req_write_last_o) begin
                    mem_resp_write_valid_i     <= 1'b1;
                    mem_resp_write_is_atomic_i <= 1'b1;
                    mem_resp_write_error_i     <= HPDCACHE_MEM_RESP_OK;
                    mem_resp_write_id_i        <= wr_id_q;
                    wr_pending                 <= 1'b0;
                    wr_beat_cnt                <= 0;
                end else begin
                    wr_beat_cnt <= wr_beat_cnt + 1;
                end
            end
        end
    end

    initial begin
        for (int i = 0; i < MEM_DEPTH; i++)
            shadow_mem[i] = 8'(i);
    end

endmodule : hw_top