
`timescale 1ns / 1ps

module mulDivUnit_tb;

    reg clk;
    reg rst;
    reg valid;
    reg [2:0] funct3;
    reg [31:0] a;
    reg [31:0] b;

    wire ready;
    wire [31:0] result;

    integer pass_count;
    integer fail_count;

    // DUT
    mulDivUnit DUT (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .funct3(funct3),
        .a(a),
        .b(b),
        .ready(ready),
        .result(result)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test task
    task run_test;
        input [8*40-1:0] test_name;
        input [2:0] operation;
        input [31:0] operand_a;
        input [31:0] operand_b;
        input [31:0] expected;

        integer timeout;

        begin
            // Apply inputs
            @(negedge clk);
            funct3 = operation;
            a = operand_a;
            b = operand_b;
            valid = 1'b1;

            // Send one-cycle valid pulse
            @(negedge clk);
            valid = 1'b0;

            // Wait for MDU to finish
            timeout = 0;

            while (ready !== 1'b1 && timeout < 40) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            // DEBUG OUTPUT
            $display(
                "DEBUG: op=%b a=%h b=%h result=%h ready=%b",
                operation, operand_a, operand_b, result, ready
            );

            // Check result
            if (timeout >= 40) begin
                $display("FAIL: %0s - TIMEOUT", test_name);
                fail_count = fail_count + 1;
            end
            else if (result !== expected) begin
                $display(
                    "FAIL: %0s | A=%h B=%h | Expected=%h Got=%h",
                    test_name, operand_a, operand_b, expected, result
                );
                fail_count = fail_count + 1;
            end
            else begin
                $display("PASS: %0s | Result=%h", test_name, result);
                pass_count = pass_count + 1;
            end

            @(negedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        rst = 1'b1;
        valid = 1'b0;
        funct3 = 3'b000;
        a = 32'd0;
        b = 32'd0;

        pass_count = 0;
        fail_count = 0;

        repeat (3) @(negedge clk);
        rst = 1'b0;

        repeat (2) @(negedge clk);

        $display("\n======================================");
        $display("       MUL/DIV UNIT TESTBENCH");
        $display("======================================\n");

        // Multiplication tests
        run_test("MUL",          3'b000, 32'd6, 32'd7, 32'd42);
        run_test("MULH",         3'b001, -32'd7, 32'd2, 32'hFFFFFFFF);
        run_test("MULHSU",       3'b010, -32'd7, 32'd2, 32'hFFFFFFFF);
        run_test("MULHU",        3'b011, 32'hFFFFFFFF, 32'd2, 32'h00000001);
        run_test("MUL negative", 3'b000, -32'd7, 32'd2, 32'hFFFFFFF2);

        // Division and remainder tests
        run_test("DIV",  3'b100, -32'd7, 32'd2, 32'hFFFFFFFD);
        run_test("DIVU", 3'b101, -32'd7, 32'd2, 32'h7FFFFFFC);
        run_test("REM",  3'b110, -32'd7, 32'd2, 32'hFFFFFFFF);
        run_test("REMU", 3'b111, -32'd7, 32'd2, 32'h00000001);

        // Division by zero
        run_test("DIV by zero",  3'b100, 32'd25, 32'd0, 32'hFFFFFFFF);
        run_test("DIVU by zero", 3'b101, 32'd25, 32'd0, 32'hFFFFFFFF);
        run_test("REM by zero",  3'b110, 32'd25, 32'd0, 32'd25);
        run_test("REMU by zero", 3'b111, 32'd25, 32'd0, 32'd25);

        // Signed overflow
        run_test("DIV signed overflow",
                 3'b100, 32'h80000000, 32'hFFFFFFFF, 32'h80000000);

        run_test("REM signed overflow",
                 3'b110, 32'h80000000, 32'hFFFFFFFF, 32'h00000000);

        // Signed division and remainder
        run_test("DIV positive result",
                 3'b100, -32'd12, -32'd3, 32'd4);

        run_test("DIV negative divisor",
                 3'b100, 32'd12, -32'd5, 32'hFFFFFFFE);

        run_test("REM negative dividend",
                 3'b110, -32'd13, 32'd5, 32'hFFFFFFFE);

        run_test("REM negative divisor",
                 3'b110, 32'd13, -32'd5, 32'd3);

        // Back-to-back operations
        run_test("Back-to-back MUL",
                 3'b000, 32'd10, 32'd12, 32'd120);

        run_test("Back-to-back DIV",
                 3'b100, 32'd10, 32'd3, 32'd3);

        run_test("Back-to-back REM",
                 3'b110, 32'd10, 32'd3, 32'd1);

        // Summary
        $display("\n======================================");
        $display("             TEST SUMMARY");
        $display("======================================");

        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);

        if (fail_count == 0)
            $display("\nALL TESTS PASSED!");
        else
            $display("\nSOME TESTS FAILED!");

        $display("======================================\n");

        $finish;
    end

endmodule
