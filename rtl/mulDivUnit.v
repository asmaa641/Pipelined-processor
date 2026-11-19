/*******************************************************************
*
* Module: forwardingUnit
* Project: RISCV Processor
* Author: Janna Alfiky
* Emails: jannabassem@aucegypt.edu
* Description: multiplication and divison unit. handles MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
* 
*
* Change history: 11/15/2026
*
*
**********************************************************************/
`include "defines.v"

module mulDivUnit (input clk, input rst, input valid, input [2:0] funct3, input [31:0] a, input [31:0] b, output ready,output reg[31:0] result);

//FSM states
localparam ST_IDLE = 2'd0;
localparam ST_RUN  = 2'd1;
localparam ST_DONE = 2'd2;

reg [1:0] state;
reg [5:0] count;//iteration counter (0 to 31)
reg [2:0] op; //latched funct3
reg negRes;//product / quotient is negative
reg negRem; //remainder is negative (dividend negative)
reg bIsZero;//division by zero
reg [31:0] aRaw;//original dividend (for REM by zero)
reg [63:0] mcand; //multiplicand, shifts left
reg [31:0] mplier; //multiplier, shifts right
reg [63:0] prod;//accumulated product (magnitude)
reg [31:0] divisor;//divisor magnitude
reg [31:0] rem;//partial remainder
reg [31:0] quot; //dividend bits shifting out, quotient in

//which operands are treated as signed
reg signA;
reg signB;

always @(*) begin
    case (funct3)
        `MD_MULH: begin 
        signA = 1'b1; signB = 1'b1; 
        end
        `MD_MULHSU: begin 
        signA = 1'b1; signB = 1'b0; 
        end
        `MD_DIV,
        `MD_REM: begin 
        signA = 1'b1; 
        signB = 1'b1; 
        end
        default: begin 
        signA = 1'b0; signB = 1'b0; 
        end
    endcase
end

//operand magnitudes
wire aNeg;
wire bNeg;
wire [31:0] aMag;
wire [31:0] bMag;

assign aNeg = signA && a[31];
assign bNeg = signB && b[31];
assign aMag = aNeg ? (~a + 32'd1) : a;
assign bMag = bNeg ? (~b + 32'd1) : b;

//bring in the next dividend bit
wire [32:0] divTmp;
wire divGe;

assign divTmp = {rem, quot[31]};
assign divGe  = (divTmp >= {1'b0, divisor});

//product with its sign restored
wire [63:0] prodFinal;

assign prodFinal = negRes ? (~prod + 64'd1) : prod;

assign ready = (state == ST_DONE);

//FSM and datapath registers
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= ST_IDLE;
        count <= 6'd0;
        op <= 3'd0;
        negRes <= 1'b0;
        negRem <= 1'b0;
        bIsZero <= 1'b0;
        aRaw <= 32'd0;
        mcand <= 64'd0;
        mplier <= 32'd0;
        prod <= 64'd0;
        divisor <= 32'd0;
        rem <= 32'd0;
        quot <= 32'd0;
    end else begin
        case (state)
            ST_IDLE: begin
                if (valid == 1'b1) begin
                    //latch the operation and set up the operands
                    op <= funct3;
                    aRaw <= a;
                    bIsZero <= (b == 32'd0);
                    negRes <= aNeg ^ bNeg;
                    negRem <= aNeg;
                    count <= 6'd0;
                    mcand <= {32'd0, aMag};
                    mplier <= bMag;
                    prod <= 64'd0;
                    quot <= aMag;
                    rem  <= 32'd0;
                    divisor <= bMag;
                    state <= ST_RUN;
                end
            end
            ST_RUN: begin
                if (op[2] == 1'b0) begin
                    //multiply: add the multiplicand if the bit is 1
                    if (mplier[0] == 1'b1)
                        prod <= prod + mcand;
                    mcand  <= mcand << 1;
                    mplier <= mplier >> 1;
                end else begin
                    //divide: subtract the divisor when it fits
                    if (divGe == 1'b1) begin
                        rem  <= divTmp[31:0] - divisor;
                        quot <= {quot[30:0], 1'b1};
                    end else begin
                        rem  <= divTmp[31:0];
                        quot <= {quot[30:0], 1'b0};
                    end
                end
                count <= count + 6'd1;
                if (count == 6'd31)
                    state <= ST_DONE;
                else if (valid == 1'b0)
                    state <= ST_IDLE;
            end
            ST_DONE: begin
                //the pipeline takes the result in this clock
                state <= ST_IDLE;
            end
            default: state <= ST_IDLE;
        endcase
    end
end

//result selection
always @(*) begin
    case (op)
        `MD_MUL:result = prodFinal[31:0];
        `MD_MULH,
        `MD_MULHSU,
        `MD_MULHU: result = prodFinal[63:32];
        `MD_DIV,
        `MD_DIVU: begin
            if (bIsZero == 1'b1)
                result = `ALL_ONES;
            else if (negRes == 1'b1)
                result = ~quot + 32'd1;
            else
                result = quot;
        end
        default: begin //REM, REMU
            if (bIsZero == 1'b1)
                result = aRaw;
            else if (negRem == 1'b1)
                result = ~rem + 32'd1;
            else
                result = rem;
        end
    endcase
end

endmodule



