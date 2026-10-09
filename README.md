# Single-Cycle RISC-V CPU

A single-cycle processor written in SystemVerilog that implements a subset of the RISC-V RV32I instruction set. Each instruction is fetched, decoded and executed in one clock cycle.

## Supported instructions

| Type   | Instructions            |
|--------|-------------------------|
| R-type | ADD, SUB, AND, OR, SLT  |
| I-type | ADDI                    |
| Load   | LW                      |
| Store  | SW                      |
| Branch | BEQ, BNE                |

Unsupported instructions set the `illegal_instr` signal to 1. When this happens, nothing is written to the registers or to memory.

## Project structure

| File                  | Description |
|-----------------------|-------------|
| `cpu_single_cycle.sv` | Top-level module that connects all the components |
| `pc.sv`               | Program counter |
| `imem.sv`             | Instruction memory, loaded from a hex file |
| `control_unit.sv`     | Decodes the instruction and generates the control signals |
| `reg_file.sv`         | 32 registers, with `x0` fixed at zero |
| `imm_gen.sv`          | Extracts and sign-extends the immediate value |
| `alu.sv`              | Arithmetic and logic unit |
| `dmem.sv`             | Data memory used by loads and stores |

## How it works

1. **Fetch**: the program counter addresses the instruction memory, which returns the current instruction.
2. **Decode**: the control unit reads the opcode and sets the control signals. The register file reads the two source registers and the immediate generator builds the immediate.
3. **Execute**: the ALU computes the result, or the memory address for LW and SW.
4. **Memory**: SW writes to data memory and LW reads from it.
5. **Write back**: the result is written to the destination register.
6. **Next PC**: the program counter moves to PC + 4, or to the branch target if a branch is taken.

## Running a simulation

The program is read from `program.hex`, with one 32-bit instruction per line in hexadecimal:

```
00500093   // addi x1, x0, 5
00a00113   // addi x2, x0, 10
002081b3   // add  x3, x1, x2
00000063   // beq  x0, x0, 0   (infinite loop to end the program)
```

To compile and run with Icarus Verilog:

```
iverilog -g2012 -o cpu_sim cpu_tb.sv cpu_single_cycle.sv pc.sv imem.sv control_unit.sv reg_file.sv imm_gen.sv alu.sv dmem.sv
vvp cpu_sim
```

## Limitations

- Jump instructions (JAL, JALR) are not implemented.
- Shift and XOR instructions are not implemented.
- Only BEQ and BNE are supported for branches.
- Data memory is not initialized, so reading an address before writing to it returns X in simulation.
