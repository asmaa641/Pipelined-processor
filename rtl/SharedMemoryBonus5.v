
/*******************************************************************
*
* Module: SharedMemoryBonus5
* Project: RISCV Processor
* Author: Asmaa Elshabshiri
* Description: Shared single-ported, byte-addressable memory.
*              Data requests have priority over instruction fetch.
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
    output reg data_done
);

reg [31:0] mem [0:63];

wire data_request;
wire [31:0] selected_addr;
wire [5:0] word_index;
wire [1:0] byte_offset;
reg [31:0] selected_word;

// Arbitration
assign data_request = MemRead || MemWrite;

assign data_grant = data_request;
assign inst_grant = !data_request;

// One selected address for the shared memory port
assign selected_addr = data_grant ? data_addr : inst_addr;

assign word_index = selected_addr[7:2];
assign byte_offset = selected_addr[1:0];


// Memory write and completion
always @(posedge clk) begin

    if (!data_request) begin
        data_done <= 1'b0;
    end

    else if (!data_done) begin

        data_done <= 1'b1;

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


// Single selected memory read
always @(*) begin

    selected_word = mem[word_index];

    inst_out = 32'b0;
    data_out = 32'b0;

    if (inst_grant) begin
        inst_out = selected_word;
    end

    if (data_grant && MemRead) begin

        case (funct3)

            3'b000: begin // LB
                case (byte_offset)
                    2'b00: data_out = {{24{selected_word[7]}}, selected_word[7:0]};
                    2'b01: data_out = {{24{selected_word[15]}}, selected_word[15:8]};
                    2'b10: data_out = {{24{selected_word[23]}}, selected_word[23:16]};
                    2'b11: data_out = {{24{selected_word[31]}}, selected_word[31:24]};
                endcase
            end

            3'b001: begin // LH
                case (byte_offset)
                    2'b00: data_out = {{16{selected_word[15]}}, selected_word[15:0]};
                    2'b10: data_out = {{16{selected_word[31]}}, selected_word[31:16]};
                    default: data_out = 32'b0;
                endcase
            end

            3'b010: begin // LW
                data_out = selected_word;
            end

            3'b100: begin // LBU
                case (byte_offset)
                    2'b00: data_out = {24'b0, selected_word[7:0]};
                    2'b01: data_out = {24'b0, selected_word[15:8]};
                    2'b10: data_out = {24'b0, selected_word[23:16]};
                    2'b11: data_out = {24'b0, selected_word[31:24]};
                endcase
            end

            3'b101: begin // LHU
                case (byte_offset)
                    2'b00: data_out = {16'b0, selected_word[15:0]};
                    2'b10: data_out = {16'b0, selected_word[31:16]};
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

