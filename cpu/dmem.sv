`timescale 1ns/1ps

module dmem #(
    parameter int MEM_DEPTH = 1024
) (
    input logic clk,
    input logic mem_write,
    input logic mem_read,
    input logic [2:0] funct3,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    output logic [31:0] rdata
);
    
    //4 independent 8-bit memory banks to support byte addressing
    //bank0: addr[1:0] = 00, bank1: addr[1:0] = 01, bank2: addr[1:0] = 10, bank3: addr[1:0] = 11
    logic [7:0] bank0 [0:MEM_DEPTH-1];
    logic [7:0] bank1 [0:MEM_DEPTH-1];
    logic [7:0] bank2 [0:MEM_DEPTH-1];
    logic [7:0] bank3 [0:MEM_DEPTH-1];

    //decode word address and intra-word byte offset
    wire [29:0] word_addr = addr[31:2]; // Word-aligned address
    wire [1:0] byte_offset = addr[1:0]; // Intra-word byte offset

    //funct3 definitions for loads and stores
    localparam logic [2:0] F3_BYTE = 3'b000;
    localparam logic [2:0] F3_HALF = 3'b001;
    localparam logic [2:0] F3_WORD = 3'b010;
    localparam logic [2:0] F3_BYTE_U = 3'b100;
    localparam logic [2:0] F3_HALF_U = 3'b101;

    //write path synchronous
    logic [3:0] byte_en; // One write-enable signal for each byte in the word
    always_comb begin
        byte_en = 4'b0000; // Default: no write
        if(mem_write && word_addr < MEM_DEPTH) begin
            case(funct3)
                F3_BYTE: begin
                    case(byte_offset)
                        2'b00: byte_en = 4'b0001;
                        2'b01: byte_en = 4'b0010;
                        2'b10: byte_en = 4'b0100;
                        2'b11: byte_en = 4'b1000;
                    endcase
                end
                F3_HALF: begin
                    case(byte_offset[1])
                        1'b0: byte_en = 4'b0011; // Halfword at offset 0
                        1'b1: byte_en = 4'b1100; // Halfword at offset 2
                    endcase
                end
                F3_WORD: begin
                    byte_en = 4'b1111; // Full word
                end
                default: byte_en = 4'b0000; // Invalid funct3 for store
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (byte_en[0]) bank0[word_addr] <= wdata[7:0];
        if (byte_en[1]) bank1[word_addr] <= funct3 == F3_BYTE ? wdata[7:0] : wdata[15:8];
        if (byte_en[2]) bank2[word_addr] <= funct3 == F3_BYTE ? wdata[7:0] : funct3 == F3_HALF ? wdata[7:0] : wdata[23:16];
        if (byte_en[3]) bank3[word_addr] <= funct3 == F3_BYTE ? wdata[7:0] : funct3 == F3_HALF ? wdata[15:8] : wdata[31:24];
    end

    // read path combinational
    logic [31:0] read_word;
    always_comb begin
        if (word_addr < MEM_DEPTH) begin
            read_word = {bank3[word_addr], bank2[word_addr], bank1[word_addr], bank0[word_addr]};
        end else begin
            read_word = 32'h0000_0000; // Return zero if address is out of bounds
        end
    end

    //sub-word extraction and sign/zero extension
    always_comb begin
        if(!mem_read) begin
            rdata = 32'h0000_0000;
        end else begin
            case(funct3)
                F3_BYTE: begin //signed byte
                    case (byte_offset)
                        2'b00: rdata = {{24{read_word[7]}}, read_word[7:0]}; // Sign-extend byte
                        2'b01: rdata = {{24{read_word[15]}}, read_word[15:8]};
                        2'b10: rdata = {{24{read_word[23]}}, read_word[23:16]};
                        2'b11: rdata = {{24{read_word[31]}}, read_word[31:24]};
                    endcase
                end

                F3_BYTE_U: begin //unsigned byte
                    case (byte_offset)
                        2'b00: rdata = {24'b0, read_word[7:0]}; // Zero-extend byte
                        2'b01: rdata = {24'b0, read_word[15:8]};
                        2'b10: rdata = {24'b0, read_word[23:16]};
                        2'b11: rdata = {24'b0, read_word[31:24]};
                    endcase
                end

                F3_HALF: begin //signed halfword
                    case (byte_offset[1])
                        1'b0: rdata = {{16{read_word[15]}}, read_word[15:0]}; // Sign-extend halfword
                        1'b1: rdata = {{16{read_word[31]}}, read_word[31:16]};
                    endcase
                end

                F3_HALF_U: begin //unsigned halfword
                    case (byte_offset[1])
                        1'b0: rdata = {16'b0, read_word[15:0]}; // Zero-extend halfword
                        1'b1: rdata = {16'b0, read_word[31:16]};
                    endcase
                end

                F3_WORD: begin //word
                    rdata = read_word; // No extension needed
                end

                default: begin
                    rdata = 32'h0000_0000;
                end
            endcase
        end
    end
    
endmodule


