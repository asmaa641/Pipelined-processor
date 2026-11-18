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

// Phase Controller
// phase = 0: C0
// phase = 1: C1
reg phase;
always @(posedge clk or posedge rst) begin
    if (rst)
        phase <= 1'b1;
    else
        phase <= ~phase;
end
wire C0 = ~phase;
wire C1 = phase;
// Control Signals
wire branch, jal, jalr, lui;
wire memRead, memWrite, RegWrite, halt;
wire ALUASel, ALUBSel;
wire [1:0] WBSel;
wire [2:0] ALUOp;
wire [3:0] ALUSel;

wire cf, zf, vf, sf;
wire [1:0] PCSel;

wire stall;
wire flushIFID;
wire bubbleIDEX;
// Data Wires
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
wire [1:0] forwardA;
wire [1:0] forwardB;
wire [31:0] ALU_input_A;
wire [31:0] ALU_input_B;

// IF/ID Stage
wire [31:0] IF_ID_PC;
wire [31:0] IF_ID_Inst;
wire [63:0] IF_ID_Input;
assign IF_ID_Input = flushIFID ? {32'b0, 32'h00000013} : {pcout, instruction_mem_data_out}; //ADDI x0, x0, 0
Register #(.N(64)) IF_ID (.D(IF_ID_Input),.L(C0 &&((~halt && ~stall) || flushIFID)),.clk(clk),.rst(rst),.Q({IF_ID_PC,IF_ID_Inst} ));

// Instruction to Control Unit
ControlUnit control(.opcode(IF_ID_Inst[`IR_opcode]), .funct3(IF_ID_Inst[`IR_funct3]), .inst20(IF_ID_Inst[20]), .branch(branch), .jal(jal), .jalr(jalr), .lui(lui), .memRead(memRead), .memWrite(memWrite), .regWrite(RegWrite), .ALUASel(ALUASel), .ALUBSel(ALUBSel), .WBSel(WBSel), .ALUOp(ALUOp), .halt(halt));

// Register File
// Register reads during C1
// Register writes during C0
RegFile register(.clk(clk), .rst(rst), .readreg1(IF_ID_Inst[`IR_rs1]), .readreg2(IF_ID_Inst[`IR_rs2]), .writereg(MEM_WB_rd), .writedata(MEM_WB_WriteData), .regwrite(MEM_WB_Control[2] && C0), .readdata1(readdata1),.readdata2(readdata2));

// Immediate Generator
rv32_ImmGen immGen(.IR(IF_ID_Inst), .Imm(generatedImm));

// Hazard and flush control
hazard_unit hazard_inst(.IFIDOpcode(IF_ID_Inst[6:0]),.IFIDRegisterRs1(IF_ID_Inst[19:15]),.IFIDRegisterRs2(IF_ID_Inst[24:20]), .IDEXRegisterRd(ID_EX_Rd), .IDEXMemRead(ID_EX_Control[9]), .stall(stall));

flushUnit flush_inst (.PCSel(PCSel), .stall(stall), .flushIFID(flushIFID), .bubbleIDEX(bubbleIDEX));

// ID/EX Stage (C1)
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
assign ID_EX_Control_input = (bubbleIDEX || halt) ? 14'b0 : {branch,jal,jalr,lui,memRead,memWrite, RegWrite,ALUASel,ALUBSel,WBSel,ALUOp};
//wb = regwrite, wbsel
// m = branch, jal, jalr, lui, memwrite, memRead
// ex = aluasel, alubsel, aluop
Register #(.N(161)) ID_EX (.D({ID_EX_Control_input, IF_ID_PC, readdata1, readdata2, generatedImm, IF_ID_Func3,IF_ID__rs1, IF_ID__rs2,IF_ID__rd }),.L(C1),.clk(clk),.rst(rst),
.Q({ID_EX_Control,ID_EX_PC,ID_EX_RegR1,ID_EX_RegR2,ID_EX_Imm, ID_EX_Func3, ID_EX_Rs1,ID_EX_Rs2, ID_EX_Rd} ));

// forwarding unit
forwardingUnit forwarding_inst(.IDEXRegisterRs1(ID_EX_Rs1), .IDEXRegisterRs2(ID_EX_Rs2), .EXMEMRegisterRd(EX_MEM_rd), .MEMWBRegisterRd(MEM_WB_rd), .EXMEMRegWrite(EX_MEM_Control[2] && !EX_MEM_Control[4]), .MEMWBRegWrite(MEM_WB_Control[2]), .forwardA(forwardA), .forwardB(forwardB));
fourby1mux muxone (.in00(ID_EX_RegR1), .in01(MEM_WB_WriteData), .in10(EX_MEM_ALU_Out),.in11(32'd0), .sel(forwardA), .out(ALU_input_A));
fourby1mux muxtwo (.in00(ID_EX_RegR2), .in01(MEM_WB_WriteData), .in10(EX_MEM_ALU_Out),.in11(32'd0), .sel(forwardB), .out(ALU_input_B));

// execute: c0
assign targetAddress = ID_EX_PC + ID_EX_Imm;
// ALUinput1
TwoBy1Mux ALUinput1mux(.A(ALU_input_A), .B(ID_EX_PC), .S(ID_EX_Control[6]), .C(ALUinput1));
// ALUinput2
TwoBy1Mux ALUinput2mux(.A(ALU_input_B), .B(ID_EX_Imm), .S(ID_EX_Control[5]), .C(ALUinput2));
// ALUControl
ALUControl alucontrol(.ALUOp(ID_EX_Control[2:0]), .funct3(ID_EX_Func3[2:0]),.inst30(ID_EX_Func3[3]), .lui(ID_EX_Control[10]), .ALUSel(ALUSel));
// ALU
prv32_ALU ALU(.a(ALUinput1), .b(ALUinput2), .shamt(ALUinput2[4:0]), .r(ALUResult), .cf(cf), .zf(zf), .vf(vf), .sf(sf), .alufn(ALUSel));

// EX/MEM stage
	
wire [31:0] EX_MEM_ALU_Out, EX_MEM_RegR2, EX_MEM_PCPlus4;
wire [4:0] EX_MEM_Control; // wb and mem only
wire [4:0] EX_MEM_rd; 
wire [4:0] EX_MEM_Control_input;
wire [2:0] EX_MEM_Func3;
assign EX_MEM_Control_input = {ID_EX_Control[9:7], ID_EX_Control[4:3]}; //memread,memwrite,regwrite,wbsel
	Register #(.N(109)) EX_MEM (.D({EX_MEM_Control_input,ID_EX_PC + 32'd4,ALUResult,ALU_input_B,ID_EX_Rd, ID_EX_Func3[2:0]}), .L(C0),.clk(clk),.rst(rst),
                              .Q({EX_MEM_Control,EX_MEM_PCPlus4,EX_MEM_ALU_Out,EX_MEM_RegR2,EX_MEM_rd, EX_MEM_Func3}));

// Memory access: C1
SharedMemory SharedMem(.clk(clk), .phase(phase), .inst_addr(pcout),.MemRead(EX_MEM_Control[4]), .MemWrite(EX_MEM_Control[3]), .funct3(EX_MEM_Func3),
	.data_addr(EX_MEM_ALU_Out), .data_in(EX_MEM_RegR2), .data_out(dataMemOut), .inst_out(instruction_mem_data_out));

	//MEM/WB (C1)
wire [2:0] MEM_WB_Control;
wire [31:0] MEM_WB_Mem_Out, MEM_WB_ALUout, MEM_WB_PCPlus4;
wire [4:0] MEM_WB_rd;
wire [2:0] MEM_WB_Control_input;
assign MEM_WB_Control_input = EX_MEM_Control[2:0]; // regwrite,wbsel
Register #(.N(104)) MEM_WB (.D({MEM_WB_Control_input, dataMemOut, EX_MEM_ALU_Out,EX_MEM_PCPlus4,EX_MEM_rd}),.L(C1),.clk(clk),.rst(rst),
                              .Q({MEM_WB_Control,MEM_WB_Mem_Out,MEM_WB_ALUout,MEM_WB_PCPlus4,MEM_WB_rd}));
wire [31:0] MEM_WB_WriteData;
assign MEM_WB_WriteData = MEM_WB_Control[1] ? MEM_WB_PCPlus4
    : (MEM_WB_Control[0] ? MEM_WB_Mem_Out : MEM_WB_ALUout);

// Program counter (C0)
assign pcplus4 = pcout +4;
TwoBy1Mux pc4OrtargetAddress(.A(pcplus4), .B(targetAddress), .S(PCSel[0]), .C(pc4OrtargetAddressOutput));
assign jalRTarget = {ALUResult[31:1], 1'b0};
TwoBy1Mux pc4OrtargetAddressorJal(.A(pc4OrtargetAddressOutput), .B(jalRTarget), .S(PCSel[1]), .C(pcin));

Register pcdut (.D(pcin), .L(C0 && ((~halt && ~stall) || flushIFID)), .clk(clk), .rst(rst), .Q(pcout)); 
// when halt is zero -> load = 1, updates pc


BranchUnit branchU(.branch(ID_EX_Control[13]),.jal(ID_EX_Control[12]), .jalr(ID_EX_Control[11]), .funct3(ID_EX_Func3[2:0]), .cf(cf),.zf(zf),.vf(vf), .sf(sf),.PCSel(PCSel));





endmodule
