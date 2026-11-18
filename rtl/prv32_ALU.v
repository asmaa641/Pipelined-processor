
module prv32_ALU(
    input wire [31:0] a, b,
    input wire [4:0] shamt,
    output reg [31:0] r,
    output wire cf, zf, vf, sf,
    input wire [3:0] alufn
);

    wire [31:0] add, op_b;
    
    assign op_b = ~b;

    assign {cf, add} = alufn[0] ?
                       (a + op_b + 1'b1) :
                       (a + b);

    wire [31:0] effective_b;
    assign effective_b = b ^ {32{alufn[0]}};

    assign zf = (add == 0);
    assign sf = add[31];

    // Correct signed overflow calculation
    assign vf = (~(a[31] ^ effective_b[31])) &
                 (a[31] ^ add[31]);

    wire [31:0] sh;

    shifter shifter0(
        .a(a),
        .shamt(shamt),
        .type(alufn[1:0]),
        .r(sh)
    );

    always @(*) begin
        r = 0;

        case (alufn)
            // Arithmetic
            4'b00_00: r = add;
            4'b00_01: r = add;
            4'b00_11: r = b;

            // Logic
            4'b01_00: r = a | b;
            4'b01_01: r = a & b;
            4'b01_11: r = a ^ b;

            // Shift
            4'b10_00: r = sh;
            4'b10_01: r = sh;
            4'b10_10: r = sh;

            // SLT and SLTU
            4'b11_01: r = {31'b0, (sf != vf)};
            4'b11_11: r = {31'b0, (~cf)};

            default: r = 0;
        endcase
    end

endmodule
