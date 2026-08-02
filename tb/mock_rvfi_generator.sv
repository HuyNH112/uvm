// =============================================================================
// mock_rvfi_generator.sv
// Mock RVFI Generator — Injects commit events for ISA agent testing
// =============================================================================

module mock_rvfi_generator (
    input  logic clk_i,
    input  logic rst_ni,
    output logic commit_valid_o,
    output logic [63:0] commit_pc_o,
    output logic [31:0] commit_instr_o,
    output logic [4:0] commit_rd_addr_o,
    output logic commit_rd_we_o,
    output logic [63:0] commit_rd_wdata_o,
    output logic ex_valid_o,
    output logic [63:0] mcause_o,
    output logic [63:0] mepc_o
);

    // TC 1.1: Basic ALU (prog_alu.hex)
    logic [63:0] golden_pc[$]       = '{64'h0000_0000, 64'h0000_0004, 64'h0000_0008, 64'h0000_000C};
    logic [31:0] golden_instr[$]    = '{32'h0010_0113, 32'h0010_0193, 32'h003001B3, 32'h00000073};
    logic [4:0]  golden_rd[$]       = '{5'd2, 5'd3, 5'd6, 5'd0};
    logic [63:0] golden_wdata[$]    = '{64'h0000_0001, 64'h0000_0002, 64'h0000_0000, 64'h0000_0000};

    int idx = 0;
    int cycle = 0;

    always @(posedge clk_i) begin
        if (!rst_ni) begin
            idx <= 0;
            cycle <= 0;
            commit_valid_o <= 0;
            ex_valid_o <= 0;
        end else begin
            cycle <= cycle + 1;

            // Generate commit every 10 cycles, starting at cycle 50
            if (cycle >= 50 && cycle < 50 + (golden_pc.size() * 10) && (cycle - 50) % 10 == 0) begin
                if (idx < golden_pc.size()) begin
                    commit_valid_o    <= 1;
                    commit_pc_o       <= golden_pc[idx];
                    commit_instr_o    <= golden_instr[idx];
                    commit_rd_addr_o  <= golden_rd[idx];
                    commit_rd_wdata_o <= golden_wdata[idx];
                    // Set commit_rd_we_o if rd_addr != x0
                    commit_rd_we_o    <= (golden_rd[idx] != 5'b0) ? 1'b1 : 1'b0;
                    // No exception in basic ALU test (except last ECALL)
                    ex_valid_o        <= (idx == golden_pc.size() - 1) ? 1'b1 : 1'b0;
                    mcause_o          <= (idx == golden_pc.size() - 1) ? 64'h0000_0008 : 64'h0;  // ECALL = 8
                    mepc_o            <= golden_pc[idx];
                    idx <= idx + 1;
                end
            end else begin
                commit_valid_o <= 0;
                ex_valid_o <= 0;
            end
        end
    end

endmodule : mock_rvfi_generator
