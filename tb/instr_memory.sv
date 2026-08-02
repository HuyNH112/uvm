// =============================================================================
// instr_memory.sv
// Instruction Memory — Load firmware .hex files for CVA6
// =============================================================================

module instr_memory (
    input  logic         clk_i,
    input  logic         rst_ni,
    // Fetch port (from CVA6)
    input  logic [63:0]  fetch_addr_i,
    input  logic         fetch_valid_i,
    output logic [127:0] fetch_data_o,  // 2 x 32-bit instructions
    output logic         fetch_valid_o
);

    // Instruction memory: 64KB (16K 32-bit words)
    logic [31:0] imem [0:16383];

    // Load prog_alu.hex at simulation start
    initial begin
        $readmemh("D:/UVM/testplan/prog_alu.hex", imem);
    end

    // Fetch response (1-cycle latency)
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            fetch_valid_o <= 0;
        end else if (fetch_valid_i) begin
            // Load 2 consecutive instructions (64-bit aligned address)
            fetch_data_o <= {imem[(fetch_addr_i >> 2) + 1], imem[fetch_addr_i >> 2]};
            fetch_valid_o <= 1;
        end else begin
            fetch_valid_o <= 0;
        end
    end

endmodule : instr_memory
