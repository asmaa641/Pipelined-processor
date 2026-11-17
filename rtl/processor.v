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
  Register #(.N(64)) IF_ID (.D({pcout, instruction_mem_data_out}),.L(~halt),.clk(clk),.rst(rst),.Q({IF_ID_PC,IF_ID_Inst} ));
// Instruction to Control Unit
ControlUnit control(.opcode(IF_ID_Inst[`IR_opcode]), .funct3(IF_ID_Inst[`IR_funct3]), .inst20(IF_ID_Inst[20]), .branch(branch), .jal(jal), .jalr(jalr), .lui(lui), .memRead(memRead), .memWrite(memWrite), .regWrite(RegWrite), .ALUASel(ALUASel), .ALUBSel(ALUBSel), .WBSel(WBSel), .ALUOp(ALUOp), .halt(halt));

wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
  wire [13:0] ID_EX_Control;
wire [4:0] ID_EX_Rs1,ID_EX_Rs2,ID_EX_Rd;
wire [3:0] ID_EX_Func3, IF_ID_Func3;
wire [4:0] IF_ID__rd, IF_ID__rs1, IF_ID__rs2;
  wire [13:0] ID_EX_Control_input;
assign IF_ID_Func3 = {IF_ID_Inst[30], IF_ID_Inst[14:12]};
assign IF_ID__rd = IF_ID_Inst[11:7];
assign IF_ID__rs1 = IF_ID_Inst[19:15];
assign IF_ID__rs2 = IF_ID_Inst[24:20];
  assign ID_EX_Control_input = {branch,jal,jalr,lui,memRead,memWrite, regWrite, ALUASel, ALUBSel, WBSel, ALUOp};;

//wb = regwrite, wbsel
// m = branch, jal, jalr, lui, memwrite, memRead
// ex = aluasel, alubsel, aluop
  Register #(.N(161)) ID_EX (.D({ID_EX_Control_input, IF_ID_PC, readdata1, readdata2, generatedImm, IF_ID_Func3,IF_ID__rs1, IF_ID__rs2,IF_ID__rd }),.L(1'b1),.clk(clk),.rst(rst),
.Q({ID_EX_Control,ID_EX_PC,ID_EX_RegR1,ID_EX_RegR2,ID_EX_Imm, ID_EX_Func3, ID_EX_Rs1,ID_EX_Rs2, ID_EX_Rd} ));

wire [31:0] EX_MEM_ALU_Out, EX_MEM_RegR2, EX_MEM_BranchAddOut;
  wire [4:0] EX_MEM_Control; // wb and mem only
wire [4:0] EX_MEM_rd; 
  wire [4:0] EX_MEM_Control_input;
wire EX_MEM_zero;
  assign EX_MEM_Control_input = {ID_EX_Control[9:7], ID_EX_Control[4:3]}; //memread,memwrite,regwrite,wbsel
assign targetAddress = ID_EX_PC + ID_EX_Imm;
  Register #(.N(107)) EX_MEM (.D({EX_MEM_Control_input,targetAddress,zf,ALUResult,ALUinput2,ID_EX_Rd}), .L(1'b1),.clk(clk),.rst(rst),
  .Q({EX_MEM_Control,EX_MEM_BranchAddOut,EX_MEM_zero,EX_MEM_ALU_Out,EX_MEM_RegR2,EX_MEM_rd}));

  wire [2:0] MEM_WB_Control;
wire [31:0] MEM_WB_Mem_Out, MEM_WB_ALUout;
wire [4:0] MEM_WB_rd;
  wire [2:0] MEM_WB_Control_input;
  assign MEM_WB_Control_input = EX_MEM_Control[2:0]; // regwrite,wbsel
  Register #(.N(72)) MEM_WB (.D({MEM_WB_Control_input, dataMemOut, EX_MEM_ALU_Out,EX_MEM_rd}),.L(1'b1),.clk(clk),.rst(rst),
                              .Q({MEM_WB_Control,MEM_WB_Mem_Out,MEM_WB_ALUout,MEM_WB_rd}));
wire [31:0] MEM_WB_WriteData;
assign MEM_WB_WriteData = MEM_WB_Ctrl[2] ? MEM_WB_Mem_out : MEM_WB_ALU_out;

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


// instruction to register
RegFile register(.clk(clk), .rst(rst), .readreg1(IF_ID_Inst[`IR_rs1]), .readreg2(IF_ID_Inst[`IR_rs2]), .writereg(MEM_WB_rd), .writedata(MEM_WB_WriteData), .regwrite(MEM_WB_Control[2]), .readdata1(readdata1),.readdata2(readdata2));

// instruction to immediate generator
rv32_ImmGen immGen(.IR(IF_ID_Inst), .Imm(generatedImm));


// ALUinput1
  TwoBy1Mux ALUinput1mux(.A(ID_EX_RegR1), .B(ID_EX_PC), .S(ID_EX_Control[6]), .C(ALUinput1));
// ALUinput2
  TwoBy1Mux ALUinput2mux(.A(ID_EX_RegR2), .B(ID_EX_Imm), .S(ID_EX_Control[5]), .C(ALUinput2));

// ALUControl
  ALUControl alucontrol(.ALUOp(ID_EX_Contol[2:0]), .funct3(ID_EX_Func3[2:0]),.inst30(ID_EX_Func3[2:0]), .lui(lui), .ALUSel(ALUSel));

// ALU
prv32_ALU ALU(.a(ALUinput1), .b(ALUinput2), .shamt(ALUinput2[4:0]), .r(ALUResult), .cf(cf), .zf(zf), .vf(vf), .sf(sf), .alufn(ALUSel));

// ALU to DataMem
  DataMem DataMem(.clk(clk), .MemRead(EX_MEM_Control[4]), .MemWrite(EX_MEM_Control[3]), .funct3(instruction_mem_data_out[`IR_funct3]),
.addr(ALUResult), .data_in(readdata2), .data_out(dataMemOut));




  TwoBy1Mux dataMemOrALUMUX(.A(ALUResult), .B(dataMemOut), .S(WBSel[0]), .C(dataMemOrALUMUXOutput));

assign pcplus4 = pcout +4;
  TwoBy1Mux PCorDMorALU(.A(dataMemOrALUMUXOutput), .B(pcplus4), .S(WBSel[1]), .C(write_data));



  TwoBy1Mux pc4OrtargetAddress(.A(pcplus4), .B(targetAddress), .S(PCSel[0]), .C(pc4OrtargetAddressOutput));

  assign jalRTarget = {ALUResult[31:1], 1'b0};

  TwoBy1Mux pc4OrtargetAddressorJal(.A(pc4OrtargetAddressOutput), .B(jalRTarget), .S(PCSel[1]), .C(pcin));

BranchUnit branchU(.branch(branch), .jal(jal), .jalr(jalr), .funct3(instruction_mem_data_out[`IR_funct3]), .cf(cf), .zf(zf), .vf(vf), .sf(sf), .PCSel(PCSel));










endmodule
