
module tb_ProcessorBonusFeatures;

reg clk;
reg rst;

integer i;
integer errors;

ProcessorBonusFeatures DUT(
    .clk(clk),
    .rst(rst)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin

    errors = 0;
    rst = 1;

    // Initialize shared memory with NOP instructions
    for (i = 0; i < 64; i = i + 1) begin
        DUT.SharedMem.mem[i] = 32'h00000013;
    end

    // Program instructions

    DUT.SharedMem.mem[0] = 32'h08000093; // addi x1, x0, 128
    DUT.SharedMem.mem[1] = 32'h02A00113; // addi x2, x0, 42
    DUT.SharedMem.mem[2] = 32'h01100193; // addi x3, x0, 17

    DUT.SharedMem.mem[3] = 32'h0020A023; // sw x2, 0(x1)
    DUT.SharedMem.mem[4] = 32'h0030A223; // sw x3, 4(x1)

    DUT.SharedMem.mem[5] = 32'h0000A203; // lw x4, 0(x1)
    DUT.SharedMem.mem[6] = 32'h0040A283; // lw x5, 4(x1)

    DUT.SharedMem.mem[7] = 32'h00520333; // add x6, x4, x5

    // Apply reset
    #12;
    rst = 0;

    // Allow processor to execute
    #1000;

    $display("\n========== BONUS 5 TEST ==========");

    $display("x1 = %0d", DUT.register.q[1]);
    $display("x2 = %0d", DUT.register.q[2]);
    $display("x3 = %0d", DUT.register.q[3]);
    $display("x4 = %0d", DUT.register.q[4]);
    $display("x5 = %0d", DUT.register.q[5]);
    $display("x6 = %0d", DUT.register.q[6]);

    $display("mem[32] = %0d", DUT.SharedMem.mem[32]);
    $display("mem[33] = %0d", DUT.SharedMem.mem[33]);

    // Check register values
    if (DUT.register.q[4] !== 32'd42) begin
        $display("FAIL: x4 should be 42");
        errors = errors + 1;
    end

    if (DUT.register.q[5] !== 32'd17) begin
        $display("FAIL: x5 should be 17");
        errors = errors + 1;
    end

    if (DUT.register.q[6] !== 32'd59) begin
        $display("FAIL: x6 should be 59");
        errors = errors + 1;
    end

    // Check memory values
    if (DUT.SharedMem.mem[32] !== 32'd42) begin
        $display("FAIL: mem[128] should be 42");
        errors = errors + 1;
    end

    if (DUT.SharedMem.mem[33] !== 32'd17) begin
        $display("FAIL: mem[132] should be 17");
        errors = errors + 1;
    end

    if (errors == 0)
        $display("\nALL TESTS PASSED!");
    else
        $display("\nTEST FAILED: %0d errors", errors);

    $finish;
end

endmodule
