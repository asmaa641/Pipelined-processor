
`timescale 1ns/1ps

module ProcessorBonusFeatures_tb;

    reg clk;
    reg rst;

    integer pass_count = 0;
    integer fail_count = 0;

    ProcessorBonusFeatures DUT (
        .clk(clk),
        .rst(rst)
    );

    // =================================================
    // CLOCK
    // =================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================
    // INSTRUCTION ENCODING
    // =================================================

    function [31:0] R;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            R = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction

    function [31:0] I;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            I = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] S;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            S = {imm[11:5], rs2, rs1, funct3,
                 imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] B;
        input [12:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            B = {imm[12], imm[10:5], rs2, rs1,
                 funct3, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] U;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            U = {imm, rd, opcode};
        end
    endfunction

    function [31:0] J;
        input [20:0] imm;
        input [4:0] rd;
        begin
            J = {imm[20], imm[10:1], imm[11],
                 imm[19:12], rd, 7'b1101111};
        end
    endfunction

    // =================================================
    // LOAD A FULL 32-BIT VALUE INTO A REGISTER
    // Uses LUI + ADDI, with NOPs to avoid dependencies.
    // =================================================

    task put_register_value;
        input integer base_index;
        input [4:0] rd;
        input [31:0] value;

        reg signed [63:0] wide_value;
        integer upper;
        integer lower;

        begin
            wide_value = $signed(value);

            upper = (wide_value + 64'sd2048) >>> 12;
            lower = wide_value - (upper <<< 12);

            DUT.SharedMem.mem[base_index] =
                U(upper[19:0], rd, 7'b0110111);

            DUT.SharedMem.mem[base_index+1] = 32'h00000013;
            DUT.SharedMem.mem[base_index+2] = 32'h00000013;

            DUT.SharedMem.mem[base_index+3] =
                I(lower[11:0], rd, 3'b000, rd, 7'b0010011);

            DUT.SharedMem.mem[base_index+4] = 32'h00000013;
            DUT.SharedMem.mem[base_index+5] = 32'h00000013;
        end
    endtask

    // =================================================
    // START A TEST
    //
    // Program layout:
    // 0-5   : Initialize x1
    // 6-11  : Initialize x2
    // 12    : Instruction under test
    // 13    : Fall-through instruction
    // 14    : Branch/jump target
    //
    // Test instruction PC = 48 (0x30).
    // =================================================

    task start_test;
        input [31:0] a;
        input [31:0] b;
        input [31:0] instruction;
        input [31:0] data_word;
        input [31:0] fallthrough;
        input [31:0] target;

        integer k;

        begin
            rst = 1'b1;

            repeat (3) @(negedge clk);

            // Initialize instruction/data memory
            for (k = 0; k < 64; k = k + 1)
                DUT.SharedMem.mem[k] = 32'h00000013;

            // Data word at address 0x40
            DUT.SharedMem.mem[16] = data_word;

            // Initialize source registers
            put_register_value(0, 5'd1, a);
            put_register_value(6, 5'd2, b);

            // Instruction under test
           // Give both register initializations enough time to finish.
for (k = 12; k < 20; k = k + 1)
    DUT.SharedMem.mem[k] = 32'h00000013;

// Execute the test after register initialization.
DUT.SharedMem.mem[20] = instruction;

DUT.SharedMem.mem[21] = fallthrough;
DUT.SharedMem.mem[22] = target;
            // Release reset
            rst = 1'b0;
        end
    endtask

    // =================================================
    // WAIT UNTIL EBREAK
    // =================================================

    
task wait_for_halt;
    integer t;

    begin
        t = 0;

        // Wait until EBREAK is fetched AND any MDU operation finishes.
        while (
            !((DUT.halt === 1'b1) && (DUT.mdStall === 1'b0))
            && t < 500
        ) begin
            @(negedge clk);
            t = t + 1;
        end

        if (!((DUT.halt === 1'b1) && (DUT.mdStall === 1'b0))) begin
            $display("WARNING: TIMEOUT waiting for processor completion");
        end

        // Allow the completed result to reach the register file.
        repeat (10) @(negedge clk);
    end
endtask


    // =================================================
    // REGISTER CHECK
    // =================================================

    task check_register;
        input [8*32-1:0] name;
        input [31:0] expected;

        begin
            if (DUT.register.q[31] === expected) begin
                $display("PASS: %-12s expected=%h actual=%h",
                         name, expected, DUT.register.q[31]);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %-12s expected=%h actual=%h",
                         name, expected, DUT.register.q[31]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================
    // MEMORY CHECK
    // =================================================

    task check_memory;
        input [8*32-1:0] name;
        input [31:0] expected;

        begin
            if (DUT.SharedMem.mem[16] === expected) begin
                $display("PASS: %-12s memory=%h",
                         name, DUT.SharedMem.mem[16]);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %-12s expected=%h actual=%h",
                         name, expected, DUT.SharedMem.mem[16]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================
    // REGISTER INSTRUCTION TEST
    // =================================================

    task run_reg_test;
        input [8*32-1:0] name;
        input [31:0] instruction;
        input [31:0] a;
        input [31:0] b;
        input [31:0] expected;

        begin
            start_test(
                a,
                b,
                instruction,
                32'h80FF7F01,
                32'h00100073,
                32'h00100073
            );

            wait_for_halt;
            check_register(name, expected);
        end
    endtask

    // =================================================
    // LOAD TEST
    // =================================================

    task run_load_test;
        input [8*32-1:0] name;
        input [31:0] instruction;
        input [31:0] expected;

        begin
            start_test(
                32'd64,
                32'd0,
                instruction,
                32'h80FF7F01,
                32'h00100073,
                32'h00100073
            );

            wait_for_halt;
            check_register(name, expected);
        end
    endtask

    // =================================================
    // STORE TEST
    // =================================================

    task run_store_test;
        input [8*32-1:0] name;
        input [31:0] instruction;
        input [31:0] store_value;
        input [31:0] expected;

        begin
            start_test(
                32'd64,
                store_value,
                instruction,
                32'h80FF7F01,
                32'h00100073,
                32'h00100073
            );

            wait_for_halt;
            check_memory(name, expected);
        end
    endtask

    // =================================================
    // BRANCH TEST
    //
    // Branch at PC=48.
    // Offset=8 means target PC=56 (mem[14]).
    // mem[13] changes x30 if branch is NOT taken.
    // =================================================

    task run_branch_test;
        input [8*32-1:0] name;
        input [31:0] instruction;
        input [31:0] a;
        input [31:0] b;

        begin
            start_test(
                a,
                b,
                instruction,
                32'h80FF7F01,
                I(12'd1, 5'd0, 3'b000, 5'd30, 7'b0010011),
                32'h00100073
            );

            wait_for_halt;

            if (DUT.register.q[30] === 32'd0) begin
                $display("PASS: %-12s branch taken", name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %-12s branch not taken", name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================
    // JUMP TEST
    //
    // Jump at PC=48.
    // Target PC=56.
    // Link address=52.
    // =================================================

    task run_jump_test;
        input [8*32-1:0] name;
        input [31:0] instruction;
        input [31:0] a;
        input [31:0] expected_link;

        begin
            start_test(
                a,
                32'd0,
                instruction,
                32'h80FF7F01,
                I(12'd1, 5'd0, 3'b000, 5'd30, 7'b0010011),
                32'h00100073
            );

            wait_for_halt;

            if ((DUT.register.q[31] === expected_link) &&
                (DUT.register.q[30] === 32'd0)) begin

                $display("PASS: %-12s link=%h",
                         name, DUT.register.q[31]);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %-12s expected link=%h actual=%h x30=%h",
                         name, expected_link,
                         DUT.register.q[31], DUT.register.q[30]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================
    // MISCELLANEOUS TEST
    // ECALL/FENCE/FENCE.TSO/PAUSE should progress to
    // the EBREAK instruction at the next address.
    // =================================================

    task run_misc_test;
        input [8*32-1:0] name;
        input [31:0] instruction;

        begin
            start_test(
                32'd0,
                32'd0,
                instruction,
                32'h80FF7F01,
                32'h00100073,
                32'h00100073
            );

            wait_for_halt;

            if (DUT.halt === 1'b1) begin
                $display("PASS: %-12s reached following EBREAK", name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %-12s", name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================
    // MAIN TEST SEQUENCE
    // =================================================

    initial begin

        rst = 1'b1;

        $display("");
        $display("==============================================");
        $display("       PROCESSOR BONUS FEATURES TESTS");
        $display("==============================================");

        // ---------------------------------------------
        // R-TYPE (10)
        // ---------------------------------------------

        $display("\n--- R-TYPE ---");

        run_reg_test("ADD",
            R(7'b0000000, 2, 1, 3'b000, 31),
            20, 3, 23);

        run_reg_test("SUB",
            R(7'b0100000, 2, 1, 3'b000, 31),
            20, 3, 17);

        run_reg_test("SLL",
            R(7'b0000000, 2, 1, 3'b001, 31),
            20, 3, 160);

        run_reg_test("SLT",
            R(7'b0000000, 2, 1, 3'b010, 31),
            3, 20, 1);

        run_reg_test("SLTU",
            R(7'b0000000, 2, 1, 3'b011, 31),
            3, 20, 1);

        run_reg_test("XOR",
            R(7'b0000000, 2, 1, 3'b100, 31),
            32'h55, 32'h0F, 32'h5A);

        run_reg_test("SRL",
            R(7'b0000000, 2, 1, 3'b101, 31),
            128, 2, 32);

        run_reg_test("SRA",
            R(7'b0100000, 2, 1, 3'b101, 31),
            -16, 2, -4);

        run_reg_test("OR",
            R(7'b0000000, 2, 1, 3'b110, 31),
            32'h50, 32'h0F, 32'h5F);

        run_reg_test("AND",
            R(7'b0000000, 2, 1, 3'b111, 31),
            32'h5A, 32'h0F, 32'h0A);


        // ---------------------------------------------
        // I-TYPE (9)
        // ---------------------------------------------

        $display("\n--- I-TYPE ---");

        run_reg_test("ADDI",
            I(12'hFFD, 1, 3'b000, 31, 7'b0010011),
            10, 0, 7);

        run_reg_test("SLTI",
            I(12'd5, 1, 3'b010, 31, 7'b0010011),
            3, 0, 1);

        run_reg_test("SLTIU",
            I(12'hFFF, 1, 3'b011, 31, 7'b0010011),
            5, 0, 1);

        run_reg_test("XORI",
            I(12'h00F, 1, 3'b100, 31, 7'b0010011),
            32'h55, 0, 32'h5A);

        run_reg_test("ORI",
            I(12'h00F, 1, 3'b110, 31, 7'b0010011),
            32'h50, 0, 32'h5F);

        run_reg_test("ANDI",
            I(12'h00F, 1, 3'b111, 31, 7'b0010011),
            32'h5A, 0, 32'h0A);

        run_reg_test("SLLI",
            I(12'h002, 1, 3'b001, 31, 7'b0010011),
            3, 0, 12);

        run_reg_test("SRLI",
            I(12'h002, 1, 3'b101, 31, 7'b0010011),
            128, 0, 32);

        run_reg_test("SRAI",
            I(12'h402, 1, 3'b101, 31, 7'b0010011),
            -16, 0, -4);


        // ---------------------------------------------
        // LOADS (5)
        // Memory word: 0x80FF7F01
        // Bytes:       01 7F FF 80
        // ---------------------------------------------

        $display("\n--- LOADS ---");

        run_load_test("LB",
            I(12'd3, 1, 3'b000, 31, 7'b0000011),
            32'hFFFFFF80);

        run_load_test("LH",
            I(12'd2, 1, 3'b001, 31, 7'b0000011),
            32'hFFFF80FF);

        run_load_test("LW",
            I(12'd0, 1, 3'b010, 31, 7'b0000011),
            32'h80FF7F01);

        run_load_test("LBU",
            I(12'd3, 1, 3'b100, 31, 7'b0000011),
            32'h00000080);

        run_load_test("LHU",
            I(12'd2, 1, 3'b101, 31, 7'b0000011),
            32'h000080FF);


        // ---------------------------------------------
        // STORES (3)
        // ---------------------------------------------

        $display("\n--- STORES ---");

        run_store_test("SB",
            S(12'd1, 2, 1, 3'b000),
            32'h000000AA,
            32'h80FFAA01);

        run_store_test("SH",
            S(12'd2, 2, 1, 3'b001),
            32'h0000BEEF,
            32'hBEEF7F01);

        run_store_test("SW",
            S(12'd0, 2, 1, 3'b010),
            32'h12345678,
            32'h12345678);


        // ---------------------------------------------
        // BRANCHES (6)
        // All conditions are TRUE.
        // ---------------------------------------------

        $display("\n--- BRANCHES ---");

        run_branch_test("BEQ",
            B(13'd8, 2, 1, 3'b000),
            5, 5);

        run_branch_test("BNE",
            B(13'd8, 2, 1, 3'b001),
            5, 6);

        run_branch_test("BLT",
            B(13'd8, 2, 1, 3'b100),
            -1, 1);

        run_branch_test("BGE",
            B(13'd8, 2, 1, 3'b101),
            1, -1);

        run_branch_test("BLTU",
            B(13'd8, 2, 1, 3'b110),
            1, 2);

        run_branch_test("BGEU",
            B(13'd8, 2, 1, 3'b111),
            2, 1);


        // ---------------------------------------------
        // JUMPS (2)
        // ---------------------------------------------

        $display("\n--- JUMPS ---");

        // JAL target = PC 48 + 8 = 56
        // Link = PC 48 + 4 = 52

        run_jump_test("JAL",
            J(21'd8, 31),
            0,
            32'd52);

        // JALR target = x1 = 56
        // Link = 52

        run_jump_test("JALR",
            I(12'd0, 1, 3'b000, 31, 7'b1100111),
            32'd56,
            32'd52);


        // ---------------------------------------------
        // UPPER IMMEDIATE (2)
        // ---------------------------------------------

        $display("\n--- UPPER IMMEDIATE ---");

        run_reg_test("LUI",
            U(20'h12345, 31, 7'b0110111),
            0, 0, 32'h12345000);

        // AUIPC uses PC = 48
        // 0x12345000 + 48 = 0x12345030

        run_reg_test("AUIPC",
            U(20'h12345, 31, 7'b0010111),
            0, 0, 32'h12345030);


        // ---------------------------------------------
        // SYSTEM / MISC (5)
        // ---------------------------------------------

        $display("\n--- SYSTEM / MISC ---");

        run_misc_test("ECALL",
            32'h00000073);

        // EBREAK tested separately because it is the
        // instruction that stops fetching.

        start_test(
            32'd0,
            32'd0,
            32'h00100073,
            32'h80FF7F01,
            32'h00000013,
            32'h00000013
        );

        wait_for_halt;

        if (DUT.halt === 1'b1) begin
            $display("PASS: EBREAK");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: EBREAK");
            fail_count = fail_count + 1;
        end

        run_misc_test("FENCE",
            32'h0000000F);

        run_misc_test("FENCE.TSO",
            32'h8330000F);

        run_misc_test("PAUSE",
            32'h0100000F);


        // ---------------------------------------------
        // RV32M: MUL (1)
        // ---------------------------------------------

        $display("\n--- RV32M ---");

        // -7 * 2 = -14 = 0xFFFFFFF2

        run_reg_test("MUL",
            R(7'b0000001, 2, 1, 3'b000, 31),
            -7, 2, 32'hFFFFFFF2);


        // ---------------------------------------------
        // SUMMARY
        // ---------------------------------------------

        $display("");
        $display("==============================================");
        $display("                 TEST SUMMARY");
        $display("==============================================");

        $display("PASSED: %0d", pass_count);
        $display("FAILED: %0d", fail_count);
        $display("TOTAL : %0d", pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $display("==============================================");

        $finish;

    end

endmodule
