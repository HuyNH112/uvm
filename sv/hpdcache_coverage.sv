// ============================================================================
// hpdcache_coverage.sv
// Functional coverage for HPDcache UVM testbench (CV32E40P + HPDcache)
// Dung UVM_HPDCACHE_* localparam tu hpdcache_uvm_pkg thay vi
// HPDCACHE_* tu hpdcache_common_pkg (khong co trong project)
// ============================================================================

// NOTE: This file can be INCLUDED in hpdcache_uvm_pkg.sv OR compiled standalone
// If included in package: inherits UVM imports/macros from package scope
// If compiled standalone: needs its own imports/macros (via guards)

`ifndef HPDCACHE_COVERAGE_SV_INCLUDED
`define HPDCACHE_COVERAGE_SV_INCLUDED
import uvm_pkg::*;
`include "uvm_macros.svh"
`endif

// NOTE: When included in package, the above guards prevent re-execution
// When compiled standalone, they ensure macros are loaded

// ----------------------------------------------------------------------------
// `uvm_analysis_imp_decl phai o ngoai class, trong package
// ----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_rsp)

// ----------------------------------------------------------------------------
// Covergroup: Request bus
// ----------------------------------------------------------------------------
covergroup hpdcache_req_cg(ref hpdcache_req_mon_t pkt);
    type_option.merge_instances = 1;
    option.get_inst_coverage    = 1;
    option.per_instance         = 1;

    cov_op: coverpoint pkt.op {
        bins op_load                   = {hpdcache_pkg::HPDCACHE_REQ_LOAD             };
        bins op_store                  = {hpdcache_pkg::HPDCACHE_REQ_STORE            };
        bins op_amo_lr                 = {hpdcache_pkg::HPDCACHE_REQ_AMO_LR           };
        bins op_amo_sc                 = {hpdcache_pkg::HPDCACHE_REQ_AMO_SC           };
        bins op_amo_swap               = {hpdcache_pkg::HPDCACHE_REQ_AMO_SWAP         };
        bins op_amo_add                = {hpdcache_pkg::HPDCACHE_REQ_AMO_ADD          };
        bins op_amo_and                = {hpdcache_pkg::HPDCACHE_REQ_AMO_AND          };
        bins op_amo_or                 = {hpdcache_pkg::HPDCACHE_REQ_AMO_OR           };
        bins op_amo_xor                = {hpdcache_pkg::HPDCACHE_REQ_AMO_XOR          };
        bins op_amo_max                = {hpdcache_pkg::HPDCACHE_REQ_AMO_MAX          };
        bins op_amo_maxu               = {hpdcache_pkg::HPDCACHE_REQ_AMO_MAXU         };
        bins op_amo_min                = {hpdcache_pkg::HPDCACHE_REQ_AMO_MIN          };
        bins op_amo_minu               = {hpdcache_pkg::HPDCACHE_REQ_AMO_MINU         };
        bins op_cmo_fence              = {hpdcache_pkg::HPDCACHE_REQ_CMO_FENCE            };
        bins op_cmo_prefetch           = {hpdcache_pkg::HPDCACHE_REQ_CMO_PREFETCH         };
        bins op_cmo_inval_nline        = {hpdcache_pkg::HPDCACHE_REQ_CMO_INVAL_NLINE      };
        bins op_cmo_inval_all          = {hpdcache_pkg::HPDCACHE_REQ_CMO_INVAL_ALL        };
        bins op_cmo_flush_nline        = {hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_NLINE      };
        bins op_cmo_flush_all          = {hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_ALL        };
        bins op_cmo_flush_inval_nline  = {hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE};
        bins op_cmo_flush_inval_all    = {hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL  };
    }

    cov_size: coverpoint pkt.size {
        bins size_0 = {3'h0};
        bins size_1 = {3'h1};
        bins size_2 = {3'h2};
        bins size_3 = {3'h3};
        bins size_4 = {3'h4};
        bins size_5 = {3'h5};
        bins size_6 = {3'h6};
        bins size_7 = {3'h7};
    }

    cov_uncacheable: coverpoint pkt.pma.uncacheable {
        bins cacheable   = {1'b0};
        bins uncacheable = {1'b1};
    }

    cov_sid: coverpoint pkt.sid {
        bins all[] = {[0 : (1 << UVM_HPDCACHE_REQ_SRC_ID_WIDTH)-1]};
    }

    cov_tid: coverpoint pkt.tid {
        bins all[] = {[0 : (1 << UVM_HPDCACHE_REQ_TRANS_ID_WIDTH)-1]};
    }

    cov_need_rsp: coverpoint pkt.need_rsp {
        bins no_rsp = {1'b0};
        bins rsp    = {1'b1};
    }

    // Set index = addr[13:6] (offset=6bit, set=8bit)
    cov_set: coverpoint pkt.addr[UVM_CL_OFFSET_WIDTH +: UVM_SET_WIDTH] {
        bins all_set[] = {[0 : UVM_HPDCACHE_SETS-1]};
    }

    // Word offset trong cacheline = addr[5:3] (64-bit word = 3bit)
    cov_word: coverpoint pkt.addr[UVM_CL_OFFSET_WIDTH-1 : $clog2(UVM_HPDCACHE_WORD_WIDTH/8)];

    // addr[31:28] — vung dia chi
    cov_addr_region: coverpoint pkt.addr[UVM_HPDCACHE_PA_WIDTH-1 -: 4] {
        bins low_mem  = {4'h0, 4'h1};
        bins mid_mem  = {[4'h2 : 4'h7]};
        bins high_mem = {[4'h8 : 4'hF]};
    }

    // Cross coverage
    cov_cross_op_need_rsp    : cross cov_need_rsp,    cov_op;
    cov_cross_op_uncacheable : cross cov_uncacheable, cov_op;
    cov_cross_op_size        : cross cov_size,        cov_op;
    cov_cross_op_set         : cross cov_set,         cov_op;

endgroup : hpdcache_req_cg

// ----------------------------------------------------------------------------
// Covergroup: Response bus
// ----------------------------------------------------------------------------
covergroup hpdcache_rsp_cg(ref hpdcache_rsp_t pkt);
    type_option.merge_instances = 1;
    option.get_inst_coverage    = 1;
    option.per_instance         = 1;

    cov_sid: coverpoint pkt.sid {
        bins all[] = {[0 : (1 << UVM_HPDCACHE_REQ_SRC_ID_WIDTH)-1]};
    }

    cov_tid: coverpoint pkt.tid {
        bins all[] = {[0 : (1 << UVM_HPDCACHE_REQ_TRANS_ID_WIDTH)-1]};
    }

    cov_error: coverpoint pkt.error {
        bins no_error = {1'b0};
        bins error    = {1'b1};
    }

    cov_aborted: coverpoint pkt.aborted {
        bins not_aborted = {1'b0};
        bins aborted     = {1'b1};
    }

    cov_cross_error_aborted : cross cov_error, cov_aborted;

endgroup : hpdcache_rsp_cg

// ----------------------------------------------------------------------------
// Coverage collector class
// ----------------------------------------------------------------------------
class hpdcache_coverage extends uvm_component;
    `uvm_component_utils(hpdcache_coverage)

    // Analysis exports — noi tu monitor ap_hpdcache_req / ap_hpdcache_rsp
    uvm_analysis_imp_req #(hpdcache_req_mon_t, hpdcache_coverage) analysis_export_req;
    uvm_analysis_imp_rsp #(hpdcache_rsp_t,     hpdcache_coverage) analysis_export_rsp;

    // Snapshot variables (ref targets cho covergroup)
    hpdcache_req_mon_t m_req_pkt;
    hpdcache_rsp_t     m_rsp_pkt;

    // Covergroup instances
    hpdcache_req_cg m_req_cg;
    hpdcache_rsp_cg m_rsp_cg;

    function new(string name = "hpdcache_coverage", uvm_component parent = null);
        super.new(name, parent);
        m_req_cg = new(m_req_pkt);
        m_rsp_cg = new(m_rsp_pkt);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export_req = new("analysis_export_req", this);
        analysis_export_rsp = new("analysis_export_rsp", this);
    endfunction

    // Callback tu monitor ap_hpdcache_req
    function void write_req(hpdcache_req_mon_t pkt);
        if (!pkt.phys_indexed && pkt.second_cycle) return;
        m_req_pkt = pkt;
        m_req_cg.sample();
    endfunction

    // Callback tu monitor ap_hpdcache_rsp
    function void write_rsp(hpdcache_rsp_t pkt);
        m_rsp_pkt = pkt;
        m_rsp_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("COV",
            $sformatf("\n========== COVERAGE REPORT ==========\n  REQ cg : %.2f%%\n  RSP cg : %.2f%%\n=====================================",
                      m_req_cg.get_coverage(),
                      m_rsp_cg.get_coverage()),
            UVM_LOW)
    endfunction

endclass : hpdcache_coverage

// NOTE: No `endif` here - file is included in hpdcache_uvm_pkg.sv package scope
// The `endif` for HPDCACHE_COVERAGE_SV_INCLUDED guard is only needed when compiled standalone
// When included in package, the guard controls imports but not the closing endif