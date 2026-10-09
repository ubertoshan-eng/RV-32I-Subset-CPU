Single-Cycle RISC-V CPU (RV32I subset)

A small single-cycle processor written in SystemVerilog. It implements a subset of the RV32I base instruction set: every instruction is fetched, decoded, executed and written back in one clock cycle.

Supported instructions
Type	Opcode	Instructions
R-type	0110011	ADD, SUB, SLT, OR, AND
I-type	0010011	ADDI, SLTI, ORI, ANDI
Load	0000011	LB, LH, LW, LBU, LHU
Store	0100011	SB, SH, SW
Branch	1100011	BEQ, BNE

Anything else raises illegal_instr, and the register and memory write enables are forced low so the instruction has no effect on state. The PC still advances to PC+4.

Not implemented: jumps (JAL, JALR), LUI, AUIPC, shifts, XOR, SLTU, the other branches (BLT, BGE, BLTU, BGEU), and CSR/system instructions.

Files
File	Module	Description
cpu_single_cycle.sv	cpu_single_cycle	Top level. Wires the datapath and control together.
pc.sv	pc	Program counter register and next-PC mux (PC+4 or branch target).
imem.sv	imem	Instruction memory, loaded from a hex file, combinational read.
control_unit.sv	control_unit	Main decoder, ALU decoder, branch decision, illegal-instruction detection.
reg_file.sv	reg_file	32 x 32-bit registers, two combinational read ports, one synchronous write port, x0 hardwired to zero.
imm_gen.sv	imm_gen	Immediate extraction and sign extension (I, S, B, U, J formats).
alu.sv	alu	Arithmetic/logic unit with a zero flag.
dmem.sv	dmem	Data memory built from four byte-wide banks, synchronous write, combinational read.
Top-level interface
Name	Direction	Description
clk	input	Clock. State updates on the rising edge.
rst_n	input	Asynchronous active-low reset. Clears the PC and all registers.
MEM_DEPTH	parameter	Depth in words of both memories (default 1024, i.e. 4 KiB each).
IMEM_FILE	parameter	Hex file loaded into instruction memory (default program.hex).

The top level has no outputs. Observe illegal_instr, pc_curr, the register file and the memories through the testbench or waveforms.

Datapath
Fetch: pc drives imem, which returns the instruction combinationally.
Decode: control_unit generates control signals; reg_file reads rs1 and rs2; imm_gen builds the immediate.
Execute: the ALU computes on rs1 and either rs2 or the immediate (alu_src). The branch target is PC + imm.
Memory: dmem is addressed by the ALU result. Stores write rs2.
Writeback: rd receives the ALU result or the memory read data (mem_to_reg).

The PC starts at 0x0000_0000 after reset.

Control signals
Signal	Meaning
reg_write	Write rd in the register file.
alu_src	ALU operand B: 0 = rs2, 1 = immediate.
mem_write	Write to data memory.
mem_to_reg	Writeback source: 0 = ALU result, 1 = memory data. Also used as the memory read enable.
pc_select	Next PC: 0 = PC+4, 1 = branch target.
alu_ctrl	ALU operation (see below).
illegal_instr	The current instruction is not supported.
ALU operations
alu_ctrl	Operation
0000	AND
0001	OR
0010	ADD
0110	SUB
0111	SLT (signed)
1100	NOR (present in the ALU, not used by the decoder)
Memory
Instruction and data memory are separate (Harvard style), each MEM_DEPTH words and each starting at address 0.
Both are word-addressed internally using addr[31:2].
Data memory is little-endian and supports byte, halfword and word accesses.
Out-of-range data reads return 0 and out-of-range writes are ignored.
An out-of-range instruction fetch returns 0x0000_0000, which is decoded as an illegal instruction.
Loading a program

imem loads IMEM_FILE with $readmemh: one 32-bit instruction per line, in hex, starting at address 0.

00500093   // addi x1, x0, 5
00a00113   // addi x2, x0, 10
002081b3   // add  x3, x1, x2
00000063   // beq  x0, x0, 0   (halt: loop forever)

End every program with a self-loop like the last line above. Memory beyond the end of the file is uninitialized.

Simulation

Any SystemVerilog-2012 simulator should work. For example, with Icarus Verilog and a testbench named cpu_tb.sv:

iverilog -g2012 -o cpu_sim cpu_tb.sv cpu_single_cycle.sv pc.sv imem.sv control_unit.sv reg_file.sv imm_gen.sv alu.sv dmem.sv
vvp cpu_sim

Adjust the command and file names for your own tool and testbench.

Known limitations
Data memory is not initialized, so loading from an address that was never written returns X in simulation.
Misaligned halfword and word accesses are not detected; the low address bits are ignored.
Loads and stores with an unsupported funct3 are not flagged as illegal. Such a store writes nothing and such a load writes 0 to rd.
There is no exception or trap handling. illegal_instr is only a status flag.
Both memories use combinational reads, which is fine for simulation but will not map to block RAM on most FPGAs.
