/*******************************************************************
*
* Module: hazardunit
* Project: RISCV Processor
* Author: Janna Alfiky
* Emails: jannabassem@aucegypt.edu
* Description: Hazard detection unit that stalls when the instruction in decode reads a register 
* that the load in ID/EX is still fetching (load use hazard)
*
* Change history: 11/17/2026
*
*
**********************************************************************/


`include "defines.v"

module hazardUnit(input [4:0] IFIDOpcode, input [4:0] IFIDRegisterRs1, input [4:0] IFIDRegisterRs2, input [4:0] IDEXRegisterRd, input IDEXMemRead, output stall);

//for which source registers the decode instruction needs
reg usesRs1;
reg usesRs2;

always @(*) begin

case (IFIDOpcode)

//read both rs1 and rs2
`OPCODE_Branch,
`OPCODE_Store,

`OPCODE_Arith_R: begin

usesRs1 = 1'b1;
usesRs2 = 1'b1;

end

//read rs1 only
`OPCODE_Load,
`OPCODE_Arith_I,

`OPCODE_JALR: begin

usesRs1 = 1'b1;
usesRs2 = 1'b0;

end

//lui, auipc, jal, fence, system read no register
default: begin

usesRs1 = 1'b0;
usesRs2 = 1'b0;

end

endcase

end

assign stall = (IDEXMemRead == 1'b1) && (IDEXRegisterRd != `REG_X0) && 
((usesRs1 && (IDEXRegisterRd == IFIDRegisterRs1))  || 
(usesRs2 && (IDEXRegisterRd == IFIDRegisterRs2)));

endmodule
