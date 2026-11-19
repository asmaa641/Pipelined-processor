/*******************************************************************
*
* Module: DFlipFlop
* Project: RISC-V Pipelined Processor
* Author: Asmaa Elshabshiri
* Email: asmaaelshabshiri@aucegypt.edu
*
* Description:
* D flip-flop module used to store and update data on the clock edge.
*
* Change history:
* 9/19/2026 = Created
*
*******************************************************************/

module DFlipFlop(input clk, input rst, input D, output reg Q);
always @ (negedge clk or posedge rst) begin // Asynchronous Reset
if (rst)
Q <= 1'b0;
else
Q <= D;
end
endmodule
