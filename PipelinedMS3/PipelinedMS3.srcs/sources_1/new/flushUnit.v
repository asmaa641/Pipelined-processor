/*******************************************************************
*
* Module: flushUnit
* Project: RISCV Processor
* Author: Janna Alfiky
* Emails: jannabassem@aucegypt.edu
* Description: Control hazard unit. When a branch is taken or a jump executes the two most 
* recent instructions are turned into bubbles. Merges the load use stall into ID/EX bubble signal.
*
* Change history: 11/17/2026
*
*
**********************************************************************/


`include "defines.v"


module flushUnit (input [1:0] PCSel, input stall, input flushIFID, output bubbleIDEX);

//PC is redirected: taken branch, jal, or jalr
wire redirect;

assign redirect = (PCSel != `PC_PLUS4);

//wrong path instruction in fetch becomes nop
assign flushIFID = redirect;

//wrong path instruction in decode or load use stall becomes a bubble
//stall and redirect cannot happen together
//stall needs a load in EX, redirect needs a branch/jump in EX

assign bubbleIDEX = redirect || stall;

endmodule

