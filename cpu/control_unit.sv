`timescale 1ns/1ps

module control_unit (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic alu_zero, // input signal indicating if the ALU result is zero

    output logic illegal_instr, // 1: illegal instruction detected
    
    output logic reg_write, // 1: enable writing to the register file
    output logic alu_src, // 0: register B, 1: immediate
    output logic mem_write, // 1: enable writing to data memory (SW)
    output logic mem_to_reg, // 0: ALU result, 1: data memory read data (LW)
    output logic pc_select, // 0: PC+4, 1: branch target
    output logic [3:0] alu_ctrl //encoded operation sent to ALU
);

    // RISC-V opcodes
    localparam logic [6:0] OPCODE_R_TYPE = 7'b0110011; // ADD, SUB, AND, OR, SLT
    localparam logic [6:0] OPCODE_I_TYPE = 7'b0010011; // ADDI
    localparam logic [6:0] OPCODE_LOAD = 7'b0000011; // LW
    localparam logic [6:0] OPCODE_STORE = 7'b0100011; // SW
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011; // BEQ, BNE

    // ALU Control Codes
    localparam logic [3:0] ALU_ADD = 4'b0010;
    localparam logic [3:0] ALU_SUB = 4'b0110;
    localparam logic [3:0] ALU_SLT = 4'b0111;
    localparam logic [3:0] ALU_OR = 4'b0001;
    localparam logic [3:0] ALU_AND = 4'b0000;

    // Internal signals
    logic [1:0] alu_op; // 2-bit ALU operation code
    logic branch;
    logic reg_write_raw, mem_write_raw;
    logic alu_illegal; // 1: illegal ALU operation detected
    logic opcode_illegal; // 1: illegal opcode detected
    logic branch_illegal; // 1: illegal branch instruction detected

    // 1. Main Decoder

    always_comb begin
        // Default values
        reg_write = 1'b0;
        alu_src = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        alu_op = 2'b00;
        opcode_illegal = 1'b0;       

        unique case (opcode)
            OPCODE_R_TYPE: begin
                reg_write_raw = 1'b1;
                alu_src = 1'b0; // operand B is from rs2
                mem_to_reg = 1'b0; // write ALU result to register
                alu_op = 2'b10; // decode using funct3/funct7
            end

            OPCODE_I_TYPE: begin
                reg_write_raw = 1'b1;
                alu_src = 1'b1; // operand B is immediate
                mem_to_reg = 1'b0; // write ALU result to register
                alu_op = 2'b10; // decode using funct3 
            end

            OPCODE_LOAD: begin
                reg_write_raw = 1'b1;
                alu_src = 1'b1; // base address + offset
                mem_to_reg = 1'b1; // write memory data to register
                alu_op = 2'b00; // ALU performs addition for address calculation
            end

            OPCODE_STORE: begin
                alu_src = 1'b1; // base address + offset
                mem_write_raw = 1'b1; // enable memory write
                alu_op = 2'b00; // ALU performs addition for address calculation
            end

            OPCODE_BRANCH: begin
                branch = 1'b1; // enable branch decision
                alu_src = 1'b0; // compare rs1 from rs2
                alu_op = 2'b01; // ALU performs subtraction for comparison
            end

            default: begin
                // For unsupported opcodes, keep all control signals at default (inactive)
                opcode_illegal = 1'b1; // illegal opcode detected
            end
        endcase
    end

    // 2. ALU Decoder
    always_comb begin
        alu_ctrl = ALU_ADD; // Default operation
        alu_illegal = 1'b0; // Default: no illegal instruction
        
        case (alu_op)
            2'b00: alu_ctrl = ALU_ADD; // Address calculation for load/store
            2'b01: alu_ctrl = ALU_SUB; // Branch comparison

            2'b10: begin // R and I type arithmetic
                case (funct3)
                    3'b000: begin
                        // distiguish between ADD and SUB using funct7[5]
                        if ((opcode == OPCODE_R_TYPE) && funct7 == 7'b0100000)
                            alu_ctrl = ALU_SUB; // SUB
                        else if ((opcode == OPCODE_R_TYPE) && funct7 != 7'b0000000)
                            alu_illegal = 1'b1; // illegal funct7 for R-type                        
                        else
                            alu_ctrl = ALU_ADD; // ADD or ADDI
                    end
                    3'b010: begin
                        alu_ctrl = ALU_SLT; // SLT
                        alu_illegal = (opcode == OPCODE_R_TYPE) && (funct7 != 7'b0);
                    end
                    3'b110: begin
                        alu_ctrl = ALU_OR; // OR
                        alu_illegal = (opcode == OPCODE_R_TYPE) && (funct7 != 7'b0);
                    end
                    3'b111: begin
                        alu_ctrl = ALU_AND; // AND
                        alu_illegal = (opcode == OPCODE_R_TYPE) && (funct7 != 7'b0);
                    end
                    default: alu_illegal = 1'b1;
                endcase
            end

            default: alu_illegal = 1'b1; 

        endcase
    end

    //3. Branch Decision Logic (BEQ, BNE)
    logic branch_condition_met;
    
    always_comb begin
        branch_illegal = 1'b0; // default: no illegal branch instruction
        case (funct3)
            3'b000: branch_condition_met = alu_zero; // BEQ rs1 == rs2
            3'b001: branch_condition_met = !alu_zero; // BNE rs1 != rs2
            default: begin
                branch_condition_met = 1'b0;
                branch_illegal = branch;
            end
        endcase
    end

    assign illegal_instr = opcode_illegal | alu_illegal | branch_illegal;
    assign reg_write = reg_write_raw & !illegal_instr;
    assign mem_write = mem_write_raw & !illegal_instr;

    // 4. PC Select Logic
    assign pc_select = branch & branch_condition_met;

endmodule

