class isa_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(isa_scoreboard)
    
    // Analysis FIFOs for incoming events
    uvm_tlm_analysis_fifo #(isa_commit_monitor::isa_commit_event) fifo_commit;
    uvm_tlm_analysis_fifo #(isa_csr_monitor::isa_exception_event) fifo_exception;
    
    // Golden reference (from .hex file or hardcoded)
    typedef struct {
        logic [63:0] pc;
        logic [31:0] instr;
        logic [4:0]  rd_addr;
        logic [63:0] rd_wdata;
    } golden_commit_t;
    
    golden_commit_t golden_reference[$];  // Queue of expected commits
    
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fifo_commit    = new("fifo_commit", this);
        fifo_exception = new("fifo_exception", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        load_golden_reference();
    endfunction
    
    function void load_golden_reference();
        // TODO: Load from .hex file or hardcode for each TC
        // Example for TC 1.1 (ALU):
        //   golden_reference = '{
        //       '{pc: 64'h0000_0000, instr: 32'h0010_0113, rd_addr: 5'd2, rd_wdata: 64'h0000_0001}, // ADD x2, x0, 1
        //       '{pc: 64'h0000_0004, instr: 32'h0010_0193, rd_addr: 5'd3, rd_wdata: 64'h0000_0002}, // ADD x3, x0, 2
        //       ...
        //   };
    endfunction
    
    task run_phase(uvm_phase phase);
        int idx = 0;
        forever begin
            isa_commit_monitor::isa_commit_event evt;
            fifo_commit.get(evt);
            
            if (idx < golden_reference.size()) begin
                golden_commit_t gold = golden_reference[idx];
                if (evt.pc == gold.pc && evt.instr == gold.instr &&
                    evt.rd_addr == gold.rd_addr && evt.rd_wdata == gold.rd_wdata) begin
                    `uvm_info("SCOREBOARD", $sformatf("PASS [%0d] PC=%016h", idx, evt.pc), UVM_HIGH)
                    pass_count++;
                end else begin
                    `uvm_error("SCOREBOARD", $sformatf("FAIL [%0d] PC mismatch: expected %016h got %016h",
                               idx, gold.pc, evt.pc))
                    fail_count++;
                end
            end
            idx++;
        end
    endtask
    
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf("PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
        if (fail_count > 0)
            `uvm_error("SCOREBOARD", "Test FAILED")
    endfunction
    
endclass : isa_scoreboard