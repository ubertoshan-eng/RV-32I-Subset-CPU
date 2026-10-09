`timescale 1ns/1ps

module imem #(
    parameter MEM_DEPTH = 1024,
    parameter MEM_FILE = "program.hex"
)(
    input logic [31:0] pc,
    output logic [31:0] inst
);

    logic [31:0] memory [0:MEM_DEPTH-1];

    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, memory);
        end
    end

    wire [31:0] word_addr = pc[31:2]; // Word-aligned address

    always_comb begin
        if (word_addr < MEM_DEPTH) begin
            inst = memory[word_addr];
        end
        else begin
            inst = 32'h0000_0000; // Return NOP if address is out of bounds
        end
    end
endmodule
