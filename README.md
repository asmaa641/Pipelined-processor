# RISC-V Pipelined Processor with Bonus Features

## Overview

This project implements a pipelined RISC-V processor using Verilog. It extends a basic processor design with additional features, including multiplication and division instructions, hazard handling, forwarding, and shared memory access.

The processor supports RV32I instructions and selected RV32M instructions.

## Features

- **5-stage pipeline:** Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write Back (WB).
- **RV32I instruction support:**
  - Arithmetic and logical operations
  - Immediate operations
  - Load and store instructions
  - Conditional branches
  - Jump instructions
  - Upper immediate instructions (`LUI`, `AUIPC`)
- **RV32M extension:**
  - Multiplication: `MUL`, `MULH`, `MULHSU`, `MULHU`
  - Division: `DIV`, `DIVU`
  - Remainder: `REM`, `REMU`
- **Hazard handling:** Forwarding and stalling mechanisms to handle data dependencies.
- **Shared memory:** A shared memory module handles instruction and data memory access.
- **Control logic:** Dedicated control units for instruction decoding, ALU operations, and pipeline control.

## Architecture

The processor uses a five-stage pipeline:

| Stage | Description |
|---|---|
| IF | Fetches instructions from instruction memory. |
| ID | Decodes instructions and reads register values. |
| EX | Performs ALU operations and calculates addresses. |
| MEM | Performs memory reads and writes. |
| WB | Writes results back to the register file. |

## Bonus Features

- RV32M multiplication and division unit.
- Forwarding unit for resolving data dependencies.
- Stall-on-conflict handling for instructions that require multi-cycle execution.
- Shared instruction and data memory access.
- Support for additional control-flow and memory operations.

## Testing and Verification

The processor was tested using Verilog testbenches in Vivado simulation.

Testing covered:

- R-type instructions
- I-type instructions
- Load instructions
- Store instructions (`SB`, `SH`, `SW`)
- Branch instructions
- Jump instructions
- Upper immediate instructions (`LUI`, `AUIPC`)
- RV32M multiplication and division operations
- Bonus feature functionality

During verification, an issue was identified in the `SH` instruction test. Debugging revealed that the `LUI` instruction was incorrectly using a register value as its first ALU operand instead of zero. The ALU input selection logic was corrected, resolving the issue.

## Tools and Technologies

- Verilog HDL
- Xilinx Vivado
- RISC-V RV32I / RV32M ISA
- Simulation-based verification

## Project Structure

The project is organized into separate Verilog modules for the processor datapath, control logic, memory, register file, and bonus features.

Key modules include:

- `ProcessorBonusFeatures`
- `SharedMemoryBonus5`
- `ControlUnit`
- `ALUControl`
- `forwardingUnit`
- `mulDivUnit`
- Register and pipeline-register modules
- Processor testbenches

## Running the Project

1. Open the project in Xilinx Vivado.
2. Add the Verilog source files to the project.
3. Set the desired testbench as the simulation top module.
4. Run Behavioral Simulation.
5. Review the simulation output to verify instruction execution and test results.

## Contributors

Developed as part of the Computer Architecture course at The American University in Cairo.
