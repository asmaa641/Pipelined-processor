/*******************************************************************
*
* Module: forwardingUnit
* Project: RISCV Processor
* Author: Janna Alfiky
* Emails: jannabassem@aucegypt.edu
* Description: Forwarding unit that selects for each operand the ID/EX register value, the
* EX/MEM result or MEM/WB write back data.
*
* Change history: 11/15/2026
*
*
**********************************************************************/


`include "defines.v"

module forwardingUnit (input [4:0] IDEXRegisterRs1, input [4:0] IDEXRegisterRs2, input [4:0] EXMEMRegisterRd, input [4:0] MEMWBRegisterRd, input EXMEMRegWrite, input MEMWBRegWrite, output reg [1:0] forwardA, output reg [1:0] forwardB);

//a stage can only supply a value if it writes a register other than x0
wire exmemValid;
wire memwbValid;

//a hit is that the stage’s destination equals the source register
wire exmemHitA;
wire exmemHitB;
wire memwbHitA;
wire memwbHitB;

assign exmemValid = (EXMEMRegWrite == 1'b1) && (EXMEMRegisterRd != `REG_X0);
assign memwbValid = (MEMWBRegWrite == 1'b1) && (MEMWBRegisterRd != `REG_X0);

assign exmemHitA = exmemValid && (EXMEMRegisterRd == IDEXRegisterRs1);
assign exmemHitB = exmemValid && (EXMEMRegisterRd == IDEXRegisterRs2);
assign memwbHitA = memwbValid && (MEMWBRegisterRd == IDEXRegisterRs1);
assign memwbHitB = memwbValid && (MEMWBRegisterRd == IDEXRegisterRs2);


//priority is EX/MEM
always @(*) begin

if (exmemHitA == 1'b1)
forwardA = `FWD_EXMEM;

else if (memwbHitA == 1'b1)
forwardA = `FWD_MEMWB;

else
forwardA = `FWD_REG;

if (exmemHitB == 1'b1)
forwardB = `FWD_EXMEM;

else if (memwbHitB == 1'b1)
forwardB = `FWD_MEMWB;

else
forwardB = `FWD_REG;

end

endmodule
