
`timescale 1ns / 1ps

module Processor_tb;

    reg clk;
    reg rst;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    Processor DUT (
        .clk(clk),
        .rst(rst)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------------
    // RESET CPU
    // ---------------------------------------------------------
    task reset_cpu;
    begin
        rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;
        @(negedge clk);
    end
    endtask

    // ---------------------------------------------------------
    // WAIT
    // ---------------------------------------------------------
    task wait_neg_edges;
        input integer n;
        integer j;
    begin
        for (j = 0; j < n; j = j + 1)
            @(negedge clk);
    end
    endtask

    // ---------------------------------------------------------
    // CLEAR MEMORY
    // ---------------------------------------------------------
    task clear_memory;
    begin
        for (i = 0; i < 64; i = i + 1)
            DUT.SharedMem.mem[i] = 32'h00000013;
    end
    endtask

    // ---------------------------------------------------------
    // CHECK REGISTER RESULT
    // x1 = 10, x2 = 3
    // ---------------------------------------------------------
    task check_reg;
        input [31:0] ins;
        input [31:0] exp;
        input [8*16-1:0] nm;
    begin
        clear_memory();
        DUT.SharedMem.mem[0] = ins;

        reset_cpu();

        force DUT.register.q[1] = 32'd10;
        force DUT.register.q[2] = 32'd3;

        wait_neg_edges(6);

        if (DUT.register.q[3] === exp) begin
            $display("PASS %0s x3=%h", nm, DUT.register.q[3]);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL %0s Expected=%h Actual=%h",
                     nm, exp, DUT.register.q[3]);
            fail_count = fail_count + 1;
        end

        release DUT.register.q[1];
        release DUT.register.q[2];
    end
    endtask

    // ---------------------------------------------------------
    // CHECK SRA / SRAI USING REAL INSTRUCTIONS
    //
    // x1 = -16
    // x2 = 2
    // x3 = x1 >>> 2
    //
    // No force statements are used.
    // ---------------------------------------------------------
    task check_sra_program;
        input [31:0] shift_ins;
        input [31:0] expected;
        input [8*16-1:0] nm;
    begin
        clear_memory();

        // x1 = -16
        DUT.SharedMem.mem[0] = 32'hFF000093;

        // NOP
        DUT.SharedMem.mem[1] = 32'h00000013;
        DUT.SharedMem.mem[2] = 32'h00000013;

        // x2 = 2
        DUT.SharedMem.mem[3] = 32'h00200113;

        // NOPs
        DUT.SharedMem.mem[4] = 32'h00000013;
        DUT.SharedMem.mem[5] = 32'h00000013;

        // Shift instruction
        DUT.SharedMem.mem[6] = shift_ins;

        reset_cpu();

        // Allow the program to execute.
        wait_neg_edges(16);

        $display("\n========== %0s DEBUG ==========", nm);
        $display("x1 = %h", DUT.register.q[1]);
        $display("x2 = %h", DUT.register.q[2]);
        $display("x3 = %h", DUT.register.q[3]);
        $display("================================");

        if (DUT.register.q[1] !== 32'hFFFFFFF0) begin
            $display("FAIL %0s: x1 initialization failed", nm);
            fail_count = fail_count + 1;
        end
        else if (DUT.register.q[2] !== 32'd2) begin
            $display("FAIL %0s: x2 initialization failed", nm);
            fail_count = fail_count + 1;
        end
        else if (DUT.register.q[3] === expected) begin
            $display("PASS %0s x3=%h", nm, DUT.register.q[3]);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL %0s Expected=%h Actual=%h",
                     nm, expected, DUT.register.q[3]);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // ---------------------------------------------------------
    // CHECK LOAD
    // ---------------------------------------------------------
    task check_load;
        input [31:0] ins;
        input [31:0] data;
        input [31:0] exp;
        input [8*16-1:0] nm;
    begin
        clear_memory();

        DUT.SharedMem.mem[0] = ins;
        DUT.SharedMem.mem[16] = data;

        reset_cpu();

        force DUT.register.q[1] = 32'd64;

        wait_neg_edges(6);

        if (DUT.register.q[3] === exp) begin
            $display("PASS %0s x3=%h", nm, DUT.register.q[3]);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL %0s Expected=%h Actual=%h",
                     nm, exp, DUT.register.q[3]);
            fail_count = fail_count + 1;
        end

        release DUT.register.q[1];
    end
    endtask

    // ---------------------------------------------------------
    // CHECK STORE
    // ---------------------------------------------------------
    task check_store;
        input [31:0] ins;
        input [31:0] exp;
        input [8*16-1:0] nm;
    begin
        clear_memory();

        DUT.SharedMem.mem[0] = ins;

        reset_cpu();

        force DUT.register.q[1] = 32'd64;
        force DUT.register.q[2] = 32'd3;

        wait_neg_edges(6);

        if (DUT.SharedMem.mem[16] === exp) begin
            $display("PASS %0s mem=%h", nm,
                     DUT.SharedMem.mem[16]);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL %0s Expected=%h Actual=%h",
                     nm, exp, DUT.SharedMem.mem[16]);
            fail_count = fail_count + 1;
        end

        release DUT.register.q[1];
        release DUT.register.q[2];
    end
    endtask

    // ---------------------------------------------------------
    // CHECK BRANCH
    // ---------------------------------------------------------
    task check_branch;
        input [31:0] ins;
        input [31:0] expected_pc;
        input [8*16-1:0] nm;
    begin
        clear_memory();

        DUT.SharedMem.mem[0] = ins;
        DUT.SharedMem.mem[1] = 32'h00000013;
        DUT.SharedMem.mem[2] = 32'h00000013;
        DUT.SharedMem.mem[3] = 32'h00000013;
        DUT.SharedMem.mem[4] = 32'h00000013;

        reset_cpu();

        force DUT.register.q[1] = 32'd10;
        force DUT.register.q[2] = 32'd3;

        wait_neg_edges(8);

        if (DUT.pcout === expected_pc) begin
            $display("PASS %0s PC=%h", nm, DUT.pcout);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL %0s Expected PC=%h Actual PC=%h",
                     nm, expected_pc, DUT.pcout);
            fail_count = fail_count + 1;
        end

        release DUT.register.q[1];
        release DUT.register.q[2];
    end
    endtask

    // ---------------------------------------------------------
    // MAIN TEST SEQUENCE
    // ---------------------------------------------------------
    initial begin

        rst = 1;
        clear_memory();

        // =====================================================
        // R-TYPE (10)
        // =====================================================

        check_reg(32'h002081B3, 32'd13, "ADD");
        check_reg(32'h402081B3, 32'd7,  "SUB");
        check_reg(32'h002091B3, 32'd80, "SLL");
        check_reg(32'h0020A1B3, 32'd0,  "SLT");
        check_reg(32'h0020B1B3, 32'd0,  "SLTU");
        check_reg(32'h0020C1B3, 32'd9,  "XOR");
        check_reg(32'h0020D1B3, 32'd1,  "SRL");

        check_sra_program(
            32'h4020D1B3,
            32'hFFFFFFFC,
            "SRA"
        );

        check_reg(32'h0020E1B3, 32'd11, "OR");
        check_reg(32'h0020F1B3, 32'd2,  "AND");

        // =====================================================
        // I-TYPE (9)
        // =====================================================

        check_reg(32'h00308193, 32'd13, "ADDI");
        check_reg(32'h0030A193, 32'd0,  "SLTI");
        check_reg(32'h0030B193, 32'd0,  "SLTIU");
        check_reg(32'h0030C193, 32'd9,  "XORI");
        check_reg(32'h0030E193, 32'd11, "ORI");
        check_reg(32'h0030F193, 32'd2,  "ANDI");
        check_reg(32'h00209193, 32'd40, "SLLI");
        check_reg(32'h0020D193, 32'd2,  "SRLI");

        check_sra_program(
            32'h4020D193,
            32'hFFFFFFFC,
            "SRAI"
        );

        // =====================================================
        // LOAD (5)
        // =====================================================

        check_load(32'h0000A183, 32'h80000003,
                   32'h00000003, "LB");

        check_load(32'h00009183, 32'h80000003,
                   32'h00000003, "LH");

        check_load(32'h0000A183, 32'h80000003,
                   32'h80000003, "LW");

        check_load(32'h0000C183, 32'h80000003,
                   32'h00000003, "LBU");

        check_load(32'h0000D183, 32'h80000003,
                   32'h00000003, "LHU");

        // =====================================================
        // STORE (3)
        // =====================================================

        check_store(32'h00208023, 32'hAABBCC03, "SB");
        check_store(32'h00209023, 32'hAABB0003, "SH");
        check_store(32'h0020A023, 32'h00000003, "SW");

        // =====================================================
        // BRANCH (6)
        // =====================================================

        check_branch(32'h00208463, 32'd8,  "BEQ");
        check_branch(32'h00209463, 32'd16, "BNE");
        check_branch(32'h0020C463, 32'd8,  "BLT");
        check_branch(32'h0020D463, 32'd16, "BGE");
        check_branch(32'h0020E463, 32'd8,  "BLTU");
        check_branch(32'h0020F463, 32'd16, "BGEU");

        // =====================================================
        // JAL
        // =====================================================

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h010001EF;

        reset_cpu();
        wait_neg_edges(8);

        if (DUT.pcout === 32'd16 &&
            DUT.register.q[3] === 32'd4) begin
            $display("PASS JAL");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL JAL PC=%h x3=%h",
                     DUT.pcout, DUT.register.q[3]);
            fail_count = fail_count + 1;
        end

        // =====================================================
        // JALR
        // =====================================================

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h000081E7;

        reset_cpu();
        force DUT.register.q[1] = 32'd8;

        wait_neg_edges(8);

        if (DUT.pcout === 32'd8 &&
            DUT.register.q[3] === 32'd4) begin
            $display("PASS JALR");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL JALR PC=%h x3=%h",
                     DUT.pcout, DUT.register.q[3]);
            fail_count = fail_count + 1;
        end

        release DUT.register.q[1];

        // =====================================================
        // U-TYPE (2)
        // =====================================================

        check_reg(32'h123451B7, 32'h12345000, "LUI");
        check_reg(32'h12345197, 32'h12345000, "AUIPC");

        // =====================================================
        // SYSTEM / FENCE (5)
        // =====================================================

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h00000073;
        reset_cpu();
        wait_neg_edges(5);

        if (DUT.pcout === 32'd8) begin
            $display("PASS ECALL");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL ECALL PC=%h", DUT.pcout);
            fail_count = fail_count + 1;
        end

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h00100073;
        reset_cpu();
        wait_neg_edges(5);

        if (DUT.pcout === 32'd4) begin
            $display("PASS EBREAK");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL EBREAK PC=%h", DUT.pcout);
            fail_count = fail_count + 1;
        end

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h0330000F;
        reset_cpu();
        wait_neg_edges(5);

        if (DUT.pcout === 32'd8) begin
            $display("PASS FENCE");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL FENCE PC=%h", DUT.pcout);
            fail_count = fail_count + 1;
        end

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h8330000F;
        reset_cpu();
        wait_neg_edges(5);

        if (DUT.pcout === 32'd8) begin
            $display("PASS FENCE.TSO");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL FENCE.TSO PC=%h", DUT.pcout);
            fail_count = fail_count + 1;
        end

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h0100000F;
        reset_cpu();
        wait_neg_edges(5);

        if (DUT.pcout === 32'd8) begin
            $display("PASS PAUSE");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL PAUSE PC=%h", DUT.pcout);
            fail_count = fail_count + 1;
        end

        // =====================================================
        // SUMMARY
        // =====================================================

        $display("\n================================");
        $display("PROCESSOR INSTRUCTION TEST SUMMARY");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
