module fourby1mux (
    input  [31:0] in00, 
    input  [31:0] in01, 
    input  [31:0] in10,
    input  [31:0] in11, 
    input  [1:0]  sel,
    output reg [31:0] out
);
    always @(*) begin
        case (sel)
            2'b00:   out = in00;
            2'b01:   out = in01;
            2'b10:   out = in10;
            2'b11:   out = in11;
            default: out = 32'd0;
        endcase
    end
endmodule
