`timescale 1ns / 1ps

module reg_file (
    input logic clk,
    input logic rst_n,

    input logic [4:0] raddr1, raddr2,
    output logic [31:0] rdata1, rdata2,

    input logic wen,
    input logic [4:0] waddr,
    input logic [31:0] wdata

);

    logic [31:0] registers [31:0];

    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : registers[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : registers[raddr2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'd0;
            end
        end else if (wen && (waddr != 5'd0)) begin
            registers[waddr] <= wdata;
        end
    end
endmodule
