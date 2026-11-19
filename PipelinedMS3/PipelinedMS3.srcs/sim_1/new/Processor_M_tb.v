

// RV32M test for ProcessorBonusFeatures (stall-on-conflict top).
// Programs are real instructions (no force), M ops run ~34 clocks each.

module Processor_M_tb;

    reg clk;
    reg rst;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    ProcessorBonusFeatures DUT (.clk(clk), .rst(rst));

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    localparam [31:0] NOP = 32'h00000013;

    // M funct3 codes
    localparam [2:0] F_MUL = 3'b000, F_MULH = 3'b001, F_MULHSU = 3'b010, F_MULHU = 3'b011,
                     F_DIV = 3'b100, F_DIVU = 3'b101, F_REM = 3'b110, F_REMU = 3'b111;

    function [31:0] i_addi(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        i_addi = {imm, rs1, 3'b000, rd, 7'h13};
    endfunction

    function [31:0] i_add(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        i_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'h33};
    endfunction

    function [31:0] i_lui(input [4:0] rd, input [19:0] imm);
        i_lui = {imm, rd, 7'h37};
    endfunction

    // RV32M: opcode OP, funct7 = 0000001
    function [31:0] i_m(input [2:0] f3, input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        i_m = {7'b0000001, rs2, rs1, f3, rd, 7'h33};
    endfunction

    task clear_memory;
    begin
        for (i = 0; i < 64; i = i + 1)
            DUT.SharedMem.mem[i] = NOP;
    end
    endtask

    task run_program;
        input integer clocks;
        integer j;
    begin
        rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;
        for (j = 0; j < clocks; j = j + 1)
            @(negedge clk);
    end
    endtask

    task check_reg;
        input [4:0] r;
        input [31:0] exp;
        input [8*24-1:0] nm;
    begin
        if (DUT.register.q[r] === exp) begin
            $display("PASS %0s  x%0d=%h", nm, r, DUT.register.q[r]);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL %0s  x%0d expected=%h actual=%h", nm, r, exp, DUT.register.q[r]);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // x1 = a, x2 = b, x3 = x1 (op) x2
    task m_test;
        input [11:0] a;
        input [11:0] b;
        input [2:0]  f3;
        input [31:0] exp;
        input [8*24-1:0] nm;
    begin
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, a);
        DUT.SharedMem.mem[1] = i_addi(2, 0, b);
        DUT.SharedMem.mem[2] = i_m(f3, 3, 1, 2);
        run_program(120);
        check_reg(3, exp, nm);
    end
    endtask

    initial begin
        rst = 1;
        clear_memory();

        // ---------------- all 8 ops, x1 = -7, x2 = 2 ----------------
        m_test(-7, 2, F_MUL,    32'hFFFFFFF2, "MUL   -7*2");        // -14
        m_test(-7, 2, F_MULH,   32'hFFFFFFFF, "MULH  -7*2");        // high of -14
        m_test(-7, 2, F_MULHSU, 32'hFFFFFFFF, "MULHSU -7*2u");      // high of -14
        m_test(-7, 2, F_MULHU,  32'h00000001, "MULHU 0xFFFFFFF9*2");
        m_test(-7, 2, F_DIV,    32'hFFFFFFFD, "DIV   -7/2");        // -3
        m_test(-7, 2, F_DIVU,   32'h7FFFFFFC, "DIVU  0xFFFFFFF9/2");
        m_test(-7, 2, F_REM,    32'hFFFFFFFF, "REM   -7%2");        // -1
        m_test(-7, 2, F_REMU,   32'h00000001, "REMU  0xFFFFFFF9%2");

        // ---------------- divide by zero (x2 = 0) ----------------
        m_test(-7, 0, F_DIV,  32'hFFFFFFFF, "DIV  by 0");
        m_test(-7, 0, F_DIVU, 32'hFFFFFFFF, "DIVU by 0");
        m_test(-7, 0, F_REM,  32'hFFFFFFF9, "REM  by 0");
        m_test(-7, 0, F_REMU, 32'hFFFFFFF9, "REMU by 0");

        // ---------------- overflow: 0x80000000 / -1 ----------------
        clear_memory();
        DUT.SharedMem.mem[0] = i_lui (1, 20'h80000);
        DUT.SharedMem.mem[1] = i_addi(2, 0, -1);
        DUT.SharedMem.mem[2] = i_m(F_DIV, 3, 1, 2);
        DUT.SharedMem.mem[3] = i_m(F_REM, 4, 1, 2);
        run_program(200);
        check_reg(3, 32'h80000000, "DIV overflow");
        check_reg(4, 32'h00000000, "REM overflow");

        // ---------------- M result used by the very next instruction ----------------
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 6);
        DUT.SharedMem.mem[1] = i_addi(2, 0, 7);
        DUT.SharedMem.mem[2] = i_m(F_MUL, 3, 1, 2);   // 42
        DUT.SharedMem.mem[3] = i_add(4, 3, 3);        // 84 (forwarded M result)
        run_program(150);
        check_reg(3, 32'd42, "MUL then use");
        check_reg(4, 32'd84, "dependent add");

        // ---------------- back-to-back M instructions ----------------
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 20);
        DUT.SharedMem.mem[1] = i_addi(2, 0, 6);
        DUT.SharedMem.mem[2] = i_m(F_MUL, 3, 1, 2);   // 120
        DUT.SharedMem.mem[3] = i_m(F_DIV, 4, 1, 2);   // 3
        DUT.SharedMem.mem[4] = i_m(F_REM, 5, 1, 2);   // 2
        DUT.SharedMem.mem[5] = i_addi(6, 0, 99);      // runs after all three
        run_program(250);
        check_reg(3, 32'd120, "B2B MUL");
        check_reg(4, 32'd3,   "B2B DIV");
        check_reg(5, 32'd2,   "B2B REM");
        check_reg(6, 32'd99,  "after M ops");

        $display("\n================================");
        $display("RV32M TEST SUMMARY");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("================================");
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $finish;
    end

endmodule

