// High-level overview of an RV32I CPU architecture
//
// RV32I is a 32-bit load/store instruction set. A typical CPU contains:
// - A program counter (PC) that selects the instruction address and advances
//   by 4 bytes, or changes to a branch or jump target.
// - Instruction memory and a decoder that identify the operation, registers,
//   and immediate value encoded in each 32-bit instruction.
// - A 32-entry, 32-bit integer register file with x0 hardwired to zero; most
//   operations read two source registers and optionally write a destination.
// - Immediate-generation logic for the RISC-V I, S, B, U, and J formats.
// - An ALU for arithmetic, logic, comparisons, and effective-address
//   calculations.
// - Data-memory access logic for loads and stores, including byte/halfword/
//   word selection and the required sign or zero extension on loads.
// - Control logic to choose the next PC and route results. Branches and jumps
//   redirect execution; JAL/JALR also save PC + 4 as a return address.
// - A writeback path that selects an ALU result, loaded data, or PC + 4 for
//   the destination register.
//
// A simple single-cycle design completes an instruction in one cycle. A
// pipelined design commonly divides work into fetch, decode, execute, memory,
// and writeback stages, with additional logic for data/control hazards.


