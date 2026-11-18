
/*******************************************************************
*
* Module: SharedMemoryBonus5
* Project: RISCV Processor
* Author: Asmaa Elshabshiri
* Description: Shared single-ported, byte-addressable memory with
*              priority-based arbitration for instruction and data
*              memory requests.
*
*              Data memory requests have priority over instruction
*              fetches. Instruction fetching is delayed whenever
*              a data memory request is active.
*
*              A completion signal indicates when a data request
*              has been serviced. Stores are performed only once
*              for each request.
*
* Change history: 11/18/2026 = Created for Bonus 5
*
********************************************************************/

module SharedMemoryBonus5(
    input clk,
    input [31:0] inst_addr,
    input MemRead,
    input MemWrite,
    input [2:0] funct3,
    input [31:0] data_addr,
    input [31:0] data_in,

    output reg [31:0] data_out,
    output reg [31:0] inst_out,
    output data_grant,
    output inst_grant,
    output reg data_done // A status signal sent to the processor to tell it that the memory operation has finished
);

reg [31:0] mem [0:63];

wire data_request;
wire [31:0] mem_addr;
wire [5:0] word_index;
wire [1:0] byte_offset;

// Request-based arbitration
assign data_request = MemRead || MemWrite; //load or store

// Data memory has priority over instruction fetch
assign data_grant = data_request;
assign inst_grant = ~data_request;

// Select the address of the granted request
assign mem_addr = data_grant ? data_addr : inst_addr;

assign word_index = mem_addr[7:2];
assign byte_offset = data_addr[1:0];

// Synchronous write and request completion
always @(posedge clk) begin

    if (!data_request) begin 
        data_done <= 1'b0; // if theres no request, update the flag so processor knows the memory operation is not completed
    end

    else if (data_grant && !data_done) begin

        data_done <= 1'b1; // update the flag so processor knows the memory operation is completed

        if (MemWrite) begin
            case (funct3)

                3'b000: begin // SB
                    case (byte_offset)
                        2'b00: mem[word_index][7:0] <= data_in[7:0];
                        2'b01: mem[word_index][15:8] <= data_in[7:0];
                        2'b10: mem[word_index][23:16] <= data_in[7:0];
                        2'b11: mem[word_index][31:24] <= data_in[7:0];
                    endcase
                end

                3'b001: begin // SH
                    case (byte_offset)
                        2'b00: mem[word_index][15:0] <= data_in[15:0];
                        2'b10: mem[word_index][31:16] <= data_in[15:0];
                        default: begin
                        end
                    endcase
                end

                3'b010: begin // SW
                    if (byte_offset == 2'b00)
                        mem[word_index] <= data_in;
                end

                default: begin
                end

            endcase
        end
    end
end

// Combinational reads
always @(*) begin

    inst_out = 32'b0;
    data_out = 32'b0;

    // Instruction fetch is allowed only when data memory is idle
    if (inst_grant) begin
        inst_out = mem[inst_addr[7:2]];
    end

    // Only read data from memory when the processor has requested a load instruction and has been granted access to the memory.
    if (data_grant && MemRead) begin

        case (funct3)

            3'b000: begin // LB
                case (byte_offset)
                    2'b00: data_out = {{24{mem[word_index][7]}}, mem[word_index][7:0]};
                    2'b01: data_out = {{24{mem[word_index][15]}}, mem[word_index][15:8]};
                    2'b10: data_out = {{24{mem[word_index][23]}}, mem[word_index][23:16]};
                    2'b11: data_out = {{24{mem[word_index][31]}}, mem[word_index][31:24]};
                endcase
            end

            3'b001: begin // LH
                case (byte_offset)
                    2'b00: data_out = {{16{mem[word_index][15]}}, mem[word_index][15:0]};
                    2'b10: data_out = {{16{mem[word_index][31]}}, mem[word_index][31:16]};
                    default: data_out = 32'b0;
                endcase
            end

            3'b010: begin // LW
                data_out = mem[word_index];
            end

            3'b100: begin // LBU
                case (byte_offset)
                    2'b00: data_out = {24'b0, mem[word_index][7:0]};
                    2'b01: data_out = {24'b0, mem[word_index][15:8]};
                    2'b10: data_out = {24'b0, mem[word_index][23:16]};
                    2'b11: data_out = {24'b0, mem[word_index][31:24]};
                endcase
            end

            3'b101: begin // LHU
                case (byte_offset)
                    2'b00: data_out = {16'b0, mem[word_index][15:0]};
                    2'b10: data_out = {16'b0, mem[word_index][31:16]};
                    default: data_out = 32'b0;
                endcase
            end

            default: begin
                data_out = 32'b0;
            end

        endcase
    end
end

endmodule
