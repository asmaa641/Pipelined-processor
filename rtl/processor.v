/*******************************************************************
*
* Module: Processor
* Project: RISCV Processor
* Author: Asmaa Elshabshiri
* Emails: asmaaelshabshiri@aucegypt.edu
* Description: Top module that connects everything in the datapath and control units
*
* Change history: 10/29/2026 = Started
* 11/1/2026 finished
*
**********************************************************************/
`include "defines.v"

module Processor(input clk, 
input rst); 
wire [31:0] IF_ID_PC, IF_ID_Inst;
  Register #(.N(64)) IF_ID (.D({pcout, data_out}),.L(~halt),.clk(clk),.rst(rst),.Q({IF_ID_PC,IF_ID_Inst} ));
// Instruction to Control Unit
ControlUnit control(.opcode(IF_ID_Inst[`IR_opcode]), .funct3(IF_ID_Inst[`IR_funct3]), .inst20(IF_ID_Inst[20]), .branch(branch), .jal(jal), .jalr(jalr), .lui(lui), .memRead(memRead), .memWrite(memWrite), .regWrite(RegWrite), .ALUASel(ALUASel), .ALUBSel(ALUBSel), .WBSel(WBSel), .ALUOp(ALUOp), .halt(halt));

wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
  wire [12:0] ID_EX_Control;
wire [4:0] ID_EX_Rs1,ID_EX_Rs2,ID_EX_Rd;
wire [3:0] ID_EX_Func3, IF_ID_Func3;
wire [4:0] IF_ID__rd, IF_ID__rs1, IF_ID__rs2;
  wire [12:0] ID_EX_Control_input;
assign IF_ID_Func3 = {IF_ID_Inst[30], IF_ID_Inst[14:12]};
assign IF_ID__rd = IF_ID_Inst[11:7];
assign IF_ID__rs1 = IF_ID_Inst[19:15];
assign IF_ID__rs2 = IF_ID_Inst[24:20];
  assign ID_EX_Control_input = {branch,jal,jalr,lui,memRead,memWrite, regWrite, ALUASel, ALUBSel, WBSel, ALUOp};;

//wb = regwrite, wbsel
// m = branch, jal, jalr, lui, memwrite, memRead
// ex = aluasel, alubsel, aluop
Register #(.N(160)) ID_EX (.D({ID_EX_Control_input, IF_ID_PC, readdata1, readdata2, generatedImm, IF_ID_Func3,IF_ID__rs1, IF_ID__rs2,IF_ID__rd }),.L(1'b1),.clk(clk),.rst(rst),
.Q({ID_EX_Control,ID_EX_PC,ID_EX_RegR1,ID_EX_RegR2,ID_EX_Imm, ID_EX_Func3, ID_EX_Rs1,ID_EX_Rs2, ID_EX_Rd} ));

wire [31:0] EX_MEM_ALU_Out, EX_MEM_RegR2, EX_MEM_BranchAddOut;
  wire [8:0] EX_MEM_Control; // wb and mem only
wire [4:0] EX_MEM_rd; 
  wire [8:0] EX_MEM_Control_input;
wire EX_MEM_zero;
assign EX_MEM_Control_input = {ID_EX_Control[13:7], ID_EX_Control[4:3]};
assign targetAddress = ID_EX_PC + ID_EX_Imm;
  Register #(.N(111)) EX_MEM (.D({EX_MEM_Control_input,targetAddress,zf,ALUResult,ALUinput2,ID_EX_Rd}), .L(1'b1),.clk(clk),.rst(rst),
  .Q({EX_MEM_Control,EX_MEM_BranchAddOut,EX_MEM_zero,EX_MEM_ALU_Out,EX_MEM_RegR2,EX_MEM_rd}));

  wire [2:0] MEM_WB_Control;
wire [31:0] MEM_WB_Mem_Out, MEM_WB_ALUout;
wire [4:0] MEM_WB_rd;
  wire [2:0] MEM_WB_Control_input;
assign MEM_WB_Control_input = EX_MEM_Control[3:1];
  Register #(.N(72)) MEM_WB (.D({MEM_WB_Control_input, dataMemOut, EX_MEM_ALU_Out,EX_MEM_rd}),.L(1'b1),.clk(clk),.rst(rst),
                              .Q({MEM_WB_Control,MEM_WB_Mem_Out,MEM_WB_ALUout,MEM_WB_rd}));

wire [1:0] forwardA;
wire [1:0] forwardB;
//forwarding_unit fu(.IDEXRegisterRs1(ID_EX_Rs1), .IDEXRegisterRs2(ID_EX_Rs2), .EXMEMRegisterRd(EX_MEM_Rd), .MEMWBRegisterRd(MEM_WB_Rd), .EXMEMRegWrite(EX_MEM_Ctrl[0] && !EX_MEM_Ctrl[3]), .MEMWBRegWrite(MEM_WB_Ctrl[0]), .forwardA(forwardA), .forwardB(forwardB));


// control wires
wire branch;
wire jal;
wire jalr;
wire lui;
wire memRead;
wire [2:0] ALUOp;
wire memWrite;
wire RegWrite;
wire ALUASel;
wire ALUBSel;
wire halt;
wire [1:0] WBSel;
wire [3:0] ALUSel;
wire cf;
wire zf;
wire vf;
wire sf;
wire [1:0] PCSel;

// data wires
wire [31:0] instruction_mem_data_out; 
wire [31:0] pcout;
wire [31:0] pcin;
wire [31:0] write_data;
wire [31:0] readdata1;
wire [31:0] readdata2;
wire[31:0] generatedImm;
wire [31:0] pcplus4;
wire [31:0] ALUinput1;
wire [31:0] ALUinput2;
wire [31:0] ALUResult;
wire [31:0] dataMemOut;

wire [31:0] targetAddress;
wire [31:0] dataMemOrALUMUXOutput;
wire [31:0] PCorDMorALUOutput;
wire [31:0] pc4OrtargetAddressOutput;
wire [31:0] jalRTarget;

// First step: PC Register
Register pcdut (.D(pcin), .L(~halt), .clk(clk), .rst(rst), .Q(pcout)); 
// when halt is zero -> load = 1, updates pc

// PC to instruction memory
InstMem im(.addr(pcout), .data_out(instruction_mem_data_out));


// Instruction to Control Unit
ControlUnit control(.opcode(instruction_mem_data_out[`IR_opcode]), .funct3(instruction_mem_data_out[`IR_funct3]), .inst20(instruction_mem_data_out[20]), .branch(branch), .jal(jal), .jalr(jalr), .lui(lui), .memRead(memRead), .memWrite(memWrite), .regWrite(RegWrite), .ALUASel(ALUASel), .ALUBSel(ALUBSel), .WBSel(WBSel), .ALUOp(ALUOp), .halt(halt));

// instruction to register
RegFile register(.clk(clk), .rst(rst), .readreg1(instruction_mem_data_out[`IR_rs1]), .readreg2(instruction_mem_data_out[`IR_rs2]), .writereg(instruction_mem_data_out[`IR_rd]), .writedata(write_data), .regwrite(RegWrite), .readdata1(readdata1),.readdata2(readdata2));

// instruction to immediate generator
rv32_ImmGen immGen(.IR(instruction_mem_data_out), .Imm(generatedImm));


// ALUinput1
  TwoBy1Mux ALUinput1mux(.A(readdata1), .B(pcout), .S(ALUASel), .C(ALUinput1));
// ALUinput2
  TwoBy1Mux ALUinput2mux(.A(readdata2), .B(generatedImm), .S(ALUBSel), .C(ALUinput2));

// ALUControl
ALUControl alucontrol(.ALUOp(ALUOp), .funct3(instruction_mem_data_out[`IR_funct3]),.inst30(instruction_mem_data_out[30]), .lui(lui), .ALUSel(ALUSel));

// ALU
prv32_ALU ALU(.a(ALUinput1), .b(ALUinput2), .shamt(ALUinput2[4:0]), .r(ALUResult), .cf(cf), .zf(zf), .vf(vf), .sf(sf), .alufn(ALUSel));

// ALU to DataMem
DataMem DataMem(.clk(clk), .MemRead(memRead), .MemWrite(memWrite), .funct3(instruction_mem_data_out[`IR_funct3]),
.addr(ALUResult), .data_in(readdata2), .data_out(dataMemOut));




  TwoBy1Mux dataMemOrALUMUX(.A(ALUResult), .B(dataMemOut), .S(WBSel[0]), .C(dataMemOrALUMUXOutput));

assign pcplus4 = pcout +4;
  TwoBy1Mux PCorDMorALU(.A(dataMemOrALUMUXOutput), .B(pcplus4), .S(WBSel[1]), .C(write_data));



  TwoBy1Mux pc4OrtargetAddress(.A(pcplus4), .B(targetAddress), .S(PCSel[0]), .C(pc4OrtargetAddressOutput));

  assign jalRTarget = {ALUResult[31:1], 1'b0};

  TwoBy1Mux pc4OrtargetAddressorJal(.A(pc4OrtargetAddressOutput), .B(jalRTarget), .S(PCSel[1]), .C(pcin));

BranchUnit branchU(.branch(branch), .jal(jal), .jalr(jalr), .funct3(instruction_mem_data_out[`IR_funct3]), .cf(cf), .zf(zf), .vf(vf), .sf(sf), .PCSel(PCSel));










endmodule
