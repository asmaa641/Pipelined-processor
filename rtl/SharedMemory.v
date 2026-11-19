/*******************************************************************
*
* Module: SharedMemory
* Project: RISC-V Pipelined Processor
* Author: Asmaa Elshabshiri
* Email: asmaaelshabshiri@aucegypt.edu
*
* Description:
* Shared memory module used for instruction and data memory access.
*
* Change history:
* 11/19/2026 = ready for submission
*
*******************************************************************/
module SharedMemory(input clk, input phase, input[31:0] inst_addr, input MemRead, input MemWrite, input [2:0] funct3,
					input [31:0] data_addr, input [31:0] data_in, output reg [31:0] data_out, output reg [31:0] inst_out);

reg [31:0] mem [0:63];

wire data_access; // inst mem or data mem
wire [31:0] mem_addr;
assign data_access = phase && (MemRead || MemWrite); 
assign mem_addr = data_access ? data_addr : inst_addr;
wire [5:0] word_index;
wire [1:0] byte_offset;

assign word_index = mem_addr[7:2];
assign byte_offset = data_addr[1:0];

// do synchronous write
always@(posedge clk)
begin
	if(data_access && MemWrite) begin
	case (funct3)
		3'b000: begin // sb
        case (byte_offset)
            2'b00: mem[word_index][7:0] <= data_in[7:0]; 
            2'b01: mem[word_index][15:8] <= data_in[7:0]; 
            2'b10: mem[word_index][23:16] <= data_in[7:0]; 
            2'b11: mem[word_index][31:24] <= data_in[7:0];
        endcase
        end
		3'b001: begin //sh
        case (byte_offset)
            2'b00: mem[word_index][15:0] <= data_in [15:0];
            2'b10: mem[word_index][31:16] <= data_in [15:0]; 
	       default: begin // do nothing
	       end
	    endcase
        end
		3'b010: begin
if (byte_offset == 2'b00)
       			 mem[word_index] <= data_in;  // sw
		end
        default: begin // do nothing
		end
endcase
end
end

//do combinational read
	always@(*) begin
			inst_out = 32'b0;
	       data_out = 32'b0;
		if(phase == 1'b0) begin
			inst_out = mem[inst_addr[7:2]];
		end
		else if(phase == 1'b1 && MemRead == 1'b1) begin
	       case (funct3) 
	          3'b000: begin // lb
                case (byte_offset)
                    2'b00: data_out = {{24{mem[word_index][7]}},mem[word_index][7:0]}; // lb
                    2'b01: data_out =  {{24{mem[word_index][15]}},mem[word_index][15:8]}; 
                    2'b10: data_out =  {{24{mem[word_index][23]}},mem[word_index][23:16]}; 
                    2'b11: data_out =  {{24{mem[word_index][31]}},mem[word_index][31:24]}; 
		        endcase
	          end
	          3'b001: begin // lh
	            case (byte_offset)
	               2'b00: data_out = {{16{mem[word_index][15]}}, mem[word_index][15:0]}; 
	               2'b10: data_out = {{16{mem[word_index][31]}}, mem[word_index][31:16]}; 
	            endcase
	           end
	          3'b010: data_out = mem[word_index]; //lw
	          3'b100: begin  // lbu
	          case (byte_offset)
                    2'b00: data_out = {24'b0,mem[word_index][7:0]}; // lbu
                    2'b01: data_out =  {24'b0,mem[word_index][15:8]}; 
                    2'b10: data_out =  {24'b0,mem[word_index][23:16]}; 
                    2'b11: data_out =  {24'b0,mem[word_index][31:24]}; 
		        endcase
	          end
	          3'b101: begin //lhu
	          case(byte_offset)
                    2'b00: data_out = {16'b0,mem[word_index][15:0]}; // lhu
                    2'b10: data_out =  {16'b0,mem[word_index][31:16]}; 
                    
		        endcase
	         end
	 endcase
	end
	end
   endmodule
