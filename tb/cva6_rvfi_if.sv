interface cva6_rvfi_if(input logic clk_i, input logic rst_ni);
    
    // ===== RVFI Signals from CVA6 (commit_valid → core committed instruction)
    logic              commit_valid;      // Instruction committed this cycle
    logic [63:0]       commit_pc;         // Committed instruction PC
    logic [63:0]       commit_pc_next;    // Next PC (PC + 4 or branch target)
    logic [31:0]       commit_instr;      // Committed instruction opcode
    logic [4:0]        commit_rd_addr;    // Destination register (x0–x31, x0=never written)
    logic              commit_rd_we;      // Register write enable
    logic [63:0]       commit_rd_wdata;   // Register write data
    
    // ===== Exception / Trap Signals
    logic              exception_valid;   // Exception occurred this cycle
    logic [3:0]        mcause;            // Exception cause (RISC-V standard)
    logic [63:0]       mepc;              // Exception PC (address that caused trap)
    
    // ===== CSR Write Signals (optional, for TC 1.3)
    logic              csr_valid;         // CSR written this cycle
    logic [11:0]       csr_addr;          // CSR address [11:0]
    logic [63:0]       csr_wdata;         // CSR write data
    
    // Modport: monitor only (read-only observation)
    modport monitor_mp (
        input clk_i, rst_ni,
        input commit_valid, commit_pc, commit_pc_next, commit_instr,
              commit_rd_addr, commit_rd_we, commit_rd_wdata,
              exception_valid, mcause, mepc,
              csr_valid, csr_addr, csr_wdata
    );
    
endinterface : cva6_rvfi_if