// ----------------------------------------------------------------------------
// hpdcache_if.sv
// UVM Testbench Interface for HPDcache (cv32a6_imac_sv32)
// Tu khai bao hpdcache_req_t / hpdcache_rsp_t / hpdcache_tag_t giong het
// cach hpdcache_wrapper.sv lam (qua HPDCACHE_DECL_REQ_T / HPDCACHE_DECL_RSP_T),
// dung chung CONF_HPDCACHE_* macro de dam bao struct layout khop voi DUT.
// ----------------------------------------------------------------------------

`include "hpdcache_typedef.svh"
`include "hpdcache_config.svh"

interface hpdcache_if
import hpdcache_pkg::*;
#(
    localparam hpdcache_user_cfg_t UserCfg = '{
        nRequesters             : (4'b1 << `CONF_HPDCACHE_REQ_SRC_ID_WIDTH),
        paWidth                 : `CONF_HPDCACHE_PA_WIDTH,
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
    },

    localparam hpdcache_cfg_t Cfg = hpdcacheBuildConfig(UserCfg),

    localparam type hpdcache_tag_t        = logic [Cfg.tagWidth-1:0],
    localparam type hpdcache_req_offset_t = logic [Cfg.reqOffsetWidth-1:0],
    localparam type hpdcache_req_data_t   = logic [Cfg.u.reqWords-1:0][Cfg.u.wordWidth-1:0],
    localparam type hpdcache_req_be_t     = logic [Cfg.u.reqWords-1:0][Cfg.u.wordWidth/8-1:0],
    localparam type hpdcache_req_sid_t    = logic [Cfg.u.reqSrcIdWidth-1:0],
    localparam type hpdcache_req_tid_t    = logic [Cfg.u.reqTransIdWidth-1:0],

    localparam type hpdcache_req_t =
            `HPDCACHE_DECL_REQ_T(
                    hpdcache_req_offset_t,
                    hpdcache_req_data_t,
                    hpdcache_req_be_t,
                    hpdcache_req_sid_t,
                    hpdcache_req_tid_t,
                    hpdcache_tag_t),

    localparam type hpdcache_rsp_t =
            `HPDCACHE_DECL_RSP_T(
                    hpdcache_req_data_t,
                    hpdcache_req_sid_t,
                    hpdcache_req_tid_t)
)(
    input bit clk_i,
    input bit rst_ni
);

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic              wbuf_flush_i;

    logic              core_req_valid_i;
    logic              core_req_ready_o;
    hpdcache_req_t     core_req_i;

    logic              core_req_abort_i;
    hpdcache_tag_t     core_req_tag_i;
    hpdcache_pma_t     core_req_pma_i;

    logic              core_rsp_valid_o;
    hpdcache_rsp_t     core_rsp_o;

    // -------------------------------------------------------------------------
    // Modport: Driver
    // -------------------------------------------------------------------------
    modport driver_mp (
        input  clk_i,
        input  rst_ni,
        output core_req_valid_i,
        output core_req_i,
        input  core_req_ready_o,
        output core_req_abort_i,
        output core_req_tag_i,
        output core_req_pma_i,
        output wbuf_flush_i,
        input  core_rsp_valid_o,
        input  core_rsp_o
    );

    // -------------------------------------------------------------------------
    // Modport: Monitor
    // -------------------------------------------------------------------------
    modport monitor_mp (
        input  clk_i,
        input  rst_ni,
        input  core_req_valid_i,
        input  core_req_ready_o,
        input  core_req_i,
        input  core_req_abort_i,
        input  core_req_tag_i,
        input  core_req_pma_i,
        input  core_rsp_valid_o,
        input  core_rsp_o
    );

    // -------------------------------------------------------------------------
    // Helper task
    // -------------------------------------------------------------------------
    task wait_n_clocks(int N);
        if (N > 0) begin
            @(posedge clk_i);
            repeat (N - 1) @(posedge clk_i);
        end
    endtask : wait_n_clocks

    // -------------------------------------------------------------------------
    // Assertions (disable during reset)
    // -------------------------------------------------------------------------
    /* pragma translate_off */
    core_req_valid_assert       : assert property (@(posedge clk_i) disable iff (!rst_ni)
        !$isunknown(core_req_valid_i));
    core_req_ready_assert       : assert property (@(posedge clk_i) disable iff (!rst_ni)
        !$isunknown(core_req_ready_o));

    core_req_addr_assert        : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.addr_offset));
    core_req_wdata_assert       : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.wdata));
    core_req_op_assert          : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.op));
    core_req_be_assert          : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.be));
    core_req_size_assert        : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.size));
    core_req_uncacheable_assert : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.pma.uncacheable));
    core_req_sid_assert         : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.sid));
    core_req_tid_assert         : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.tid));
    core_req_need_rsp_assert    : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_req_valid_i |-> !$isunknown(core_req_i.need_rsp));

    core_rsp_valid_assert       : assert property (@(posedge clk_i) disable iff (!rst_ni)
        !$isunknown(core_rsp_valid_o));
    core_rsp_sid_assert         : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_rsp_valid_o |-> !$isunknown(core_rsp_o.sid));
    core_rsp_tid_assert         : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_rsp_valid_o |-> !$isunknown(core_rsp_o.tid));
    core_rsp_error_assert       : assert property (@(posedge clk_i) disable iff (!rst_ni)
        core_rsp_valid_o |-> !$isunknown(core_rsp_o.error));
    /* pragma translate_on */

endinterface : hpdcache_if