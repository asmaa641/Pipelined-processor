
/*******************************************************************
*
* Module: mulDivUnit
* Project: RISCV Processor
* Author: Janna Alfiky
* Emails: jannabassem@aucegypt.edu
* Description: Multiplication and division unit.
*              Handles MUL, MULH, MULHSU, MULHU,
*              DIV, DIVU, REM, REMU.
*
* Change history: 11/15/2026
*
********************************************************************/

`include "defines.v"

module mulDivUnit (
    input clk,
    input rst,
    input valid,
    input [2:0] funct3,
    input [31:0] a,
    input [31:0] b,
    output ready,
    output reg [31:0] result
);

// FSM states
localparam ST_IDLE = 2'd0;
localparam ST_RUN  = 2'd1;
localparam ST_DONE = 2'd2;

reg [1:0] state;
reg [5:0] count;

reg [2:0] op;

reg negRes;
reg negRem;
reg bIsZero;

reg [31:0] aRaw;

reg [63:0] mcand;
reg [31:0] mplier;
reg [63:0] prod;

reg [31:0] divisor;
reg [31:0] rem;
reg [31:0] quot;

// Signed/unsigned operand selection
reg signA;
reg signB;

always @(*) begin
    case (funct3)

        `MD_MULH: begin
            signA = 1'b1;
            signB = 1'b1;
        end

        `MD_MULHSU: begin
            signA = 1'b1;
            signB = 1'b0;
        end

        `MD_DIV,
        `MD_REM: begin
            signA = 1'b1;
            signB = 1'b1;
        end

        default: begin
            signA = 1'b0;
            signB = 1'b0;
        end

    endcase
end

// Operand magnitudes
wire aNeg;
wire bNeg;

wire [31:0] aMag;
wire [31:0] bMag;

assign aNeg = signA && a[31];
assign bNeg = signB && b[31];

assign aMag = aNeg ? (~a + 32'd1) : a;
assign bMag = bNeg ? (~b + 32'd1) : b;

// Division intermediate values
wire [32:0] divTmp;
wire divGe;

assign divTmp = {rem, quot[31]};
assign divGe  = (divTmp >= {1'b0, divisor});

// Restore multiplication result sign
wire [63:0] prodFinal;

assign prodFinal = negRes ? (~prod + 64'd1) : prod;

// Ready is high during ST_DONE
assign ready = (state == ST_DONE);


// FSM and datapath registers
always @(posedge clk or posedge rst) begin

    if (rst) begin

        state   <= ST_IDLE;
        count   <= 6'd0;
        op      <= 3'd0;

        negRes  <= 1'b0;
        negRem  <= 1'b0;
        bIsZero <= 1'b0;

        aRaw    <= 32'd0;

        mcand   <= 64'd0;
        mplier  <= 32'd0;
        prod    <= 64'd0;

        divisor <= 32'd0;
        rem     <= 32'd0;
        quot    <= 32'd0;

    end else begin

        case (state)

            // Wait for a new multiplication/division request
            ST_IDLE: begin

                if (valid == 1'b1) begin

                    // Latch operation and operands
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
                    rem <= 32'd0;
                    divisor <= bMag;

                    state <= ST_RUN;

                end

            end


            // Perform 32 multiplication/division iterations
            ST_RUN: begin

                if (op[2] == 1'b0) begin

                    // Multiplication: shift and add
                    if (mplier[0] == 1'b1)
                        prod <= prod + mcand;

                    mcand <= mcand << 1;
                    mplier <= mplier >> 1;

                end else begin

                    // Division: restoring division
                    if (divGe == 1'b1) begin

                        rem <= divTmp[31:0] - divisor;
                        quot <= {quot[30:0], 1'b1};

                    end else begin

                        rem <= divTmp[31:0];
                        quot <= {quot[30:0], 1'b0};

                    end

                end

                count <= count + 6'd1;

                // Finish after 32 iterations.
                // Do NOT check valid here: the request is already latched.
                if (count == 6'd31)
                    state <= ST_DONE;

            end


            // Result is available for the processor to capture
            ST_DONE: begin

                state <= ST_IDLE;

            end


            default: begin

                state <= ST_IDLE;

            end

        endcase

    end

end


// Result selection
always @(*) begin

    case (op)

        // MUL: lower 32 bits
        `MD_MUL: begin

            result = prodFinal[31:0];

        end


        // MULH, MULHSU, MULHU: upper 32 bits
        `MD_MULH,
        `MD_MULHSU,
        `MD_MULHU: begin

            result = prodFinal[63:32];

        end


        // DIV and DIVU
        `MD_DIV,
        `MD_DIVU: begin

            if (bIsZero == 1'b1)
                result = `ALL_ONES;

            else if (negRes == 1'b1)
                result = ~quot + 32'd1;

            else
                result = quot;

        end


        // REM and REMU
        default: begin

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
