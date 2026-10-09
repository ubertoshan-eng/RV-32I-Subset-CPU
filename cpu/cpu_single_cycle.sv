`timescale 1ns/1ps

module cpu_single_cycle #(
    parameter MEM_DEPTH = 1024,
    parameter IMEM_FILE = "program.hex"
) (
    input logic clk,
    input logic rst_n
);

        //Internal Interconnect wires

        //Instruction and PC signals
        logic [31:0] pc_curr, pc_plus_4, pc_target, inst;

        //Control unit signals
        logic reg_write;
        logic alu_src;
        logic mem_write;
        logic mem_to_reg;
        logic pc_sel;
        logic [3:0] alu_ctrl;
        logic illegal_instr;

        //register file signals
        logic [4:0] rs1_addr, rs2_addr, rd_addr;
        logic [31:0] reg_rdata1;
        logic [31:0] reg_rdata2;
        logic [31:0] reg_wdata;

        //Immediate & ALU operands
        logic [31:0] imm_ext;
        logic [31:0] alu_operandb;
        logic [31:0] alu_result;
        logic alu_zero;

        //Data memory signals
        logic [31:0] mem_rdata;

        // Instruction field extraction
        assign rs1_addr = inst[19:15];
        assign rs2_addr = inst[24:20];
        assign rd_addr = inst[11:7];


        // Submodule instantiations

        // PC unit
        pc u_pc (
            .clk (clk),
            .rst_n (rst_n),
            .pc_sel (pc_sel),
            .target_pc (pc_target),
            .pc_out (pc_curr),
            .pc_plus_4 (pc_plus_4)
        );

        // Instruction memory
        imem #(
            .MEM_DEPTH(MEM_DEPTH),
            .MEM_FILE(IMEM_FILE)
        ) u_imem (
            .pc (pc_curr),
            .inst (inst)
        );

        // Control unit
        control_unit u_control_unit (
            .opcode (inst[6:0]),
            .funct3 (inst[14:12]),
            .funct7 (inst[31:25]),
            .alu_zero (alu_zero),
            .reg_write (reg_write),
            .alu_src (alu_src),
            .mem_write (mem_write),
            .mem_to_reg (mem_to_reg),
            .pc_select (pc_sel),
            .alu_ctrl (alu_ctrl),
            .illegal_instr (illegal_instr)
        );

        // Register file
        reg_file u_reg_file (
            .clk (clk),
            .rst_n (rst_n),
            .raddr1 (rs1_addr),
            .raddr2 (rs2_addr),
            .waddr (rd_addr),
            .rdata1 (reg_rdata1),
            .rdata2 (reg_rdata2),
            .wdata (reg_wdata),
            .wen (reg_write)
        );

        // Immediate generator
        imm_gen u_imm_gen (
            .inst (inst),
            .imm_out (imm_ext)
        );


        // Execution datapath

        // Branch target calculation: PC + immediate
        assign pc_target = pc_curr + imm_ext;

        // ALU operand B selection: register or immediate
        assign alu_operandb = (alu_src) ? imm_ext : reg_rdata2;

        // ALU operation
        alu u_alu (
            .a (reg_rdata1),
            .b (alu_operandb),
            .alu_ctrl (alu_ctrl),
            .result (alu_result),
            .zero (alu_zero)
        );

        // Data memory
        dmem #(
            .MEM_DEPTH(MEM_DEPTH)
        ) u_dmem (
            .clk (clk),
            .mem_write (mem_write),
            .mem_read (mem_to_reg),
            .funct3 (inst[14:12]),
            .addr (alu_result),
            .wdata (reg_rdata2),
            .rdata (mem_rdata)
        );

        // Writeback
        // If mem_to_reg is 1, write data from memory; else write ALU result
        assign reg_wdata = (mem_to_reg) ? mem_rdata : alu_result;
        
endmodule




