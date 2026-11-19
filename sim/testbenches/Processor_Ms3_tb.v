
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
        wait_neg_edges(30);

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
        DUT.SharedMem.mem[16] = 32'hAABBCCDD;

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
    input taken;
    input [8*16-1:0] nm;
begin
    clear_memory();
    DUT.SharedMem.mem[0] = ins;
    DUT.SharedMem.mem[1] = 32'h00100193; // addi x3,x0,1 (skipped if taken)
    DUT.SharedMem.mem[2] = 32'h00200213; // addi x4,x0,2 (target)
    reset_cpu();
    force DUT.register.q[1] = 32'd10;
    force DUT.register.q[2] = 32'd3;
    wait_neg_edges(30);
    if (DUT.register.q[4] === 32'd2 &&
        DUT.register.q[3] === (taken ? 32'd0 : 32'd1)) begin
        $display("PASS %0s", nm);
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL %0s x3=%h x4=%h", nm, DUT.register.q[3], DUT.register.q[4]);
        fail_count = fail_count + 1;
    end
    release DUT.register.q[1];
    release DUT.register.q[2];
end
endtask


task check_nop;
    input [31:0] ins;
    input [8*16-1:0] nm;
begin
    clear_memory();
    DUT.SharedMem.mem[0] = ins;
    DUT.SharedMem.mem[1] = 32'h00500193; // addi x3,x0,5 must still run
    reset_cpu();
    wait_neg_edges(20);
    if (DUT.register.q[3] === 32'd5) begin
        $display("PASS %0s", nm); pass_count = pass_count + 1;
    end else begin
        $display("FAIL %0s x3=%h", nm, DUT.register.q[3]); fail_count = fail_count + 1;
    end
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

        check_load(32'h00008183, 32'h80000003,
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

        check_branch(32'h00208463, 0, "BEQ");
check_branch(32'h00209463, 1, "BNE");
check_branch(32'h0020C463, 0, "BLT");
check_branch(32'h0020D463, 1, "BGE");
check_branch(32'h0020E463, 0, "BLTU");
check_branch(32'h0020F463, 1, "BGEU");




        // JAL: jumps from mem[0] to mem[4], skipping mem[1]
clear_memory();
DUT.SharedMem.mem[0] = 32'h010001EF;
DUT.SharedMem.mem[1] = 32'h00100213; // addi x4,x0,1 (must be skipped)
DUT.SharedMem.mem[4] = 32'h00200293; // addi x5,x0,2 (target)
reset_cpu();
wait_neg_edges(30);
if (DUT.register.q[3] === 32'd4 && DUT.register.q[4] === 32'd0 &&
    DUT.register.q[5] === 32'd2) begin
    $display("PASS JAL"); pass_count = pass_count + 1;
end else begin
    $display("FAIL JAL x3=%h x4=%h x5=%h", DUT.register.q[3], DUT.register.q[4], DUT.register.q[5]);
    fail_count = fail_count + 1;
end

// JALR: x1=8 jumps from mem[0] to mem[2], skipping mem[1]
clear_memory();
DUT.SharedMem.mem[0] = 32'h000081E7;
DUT.SharedMem.mem[1] = 32'h00100213; // must be skipped
DUT.SharedMem.mem[2] = 32'h00200293; // target
reset_cpu();
force DUT.register.q[1] = 32'd8;
wait_neg_edges(30);
if (DUT.register.q[3] === 32'd4 && DUT.register.q[4] === 32'd0 &&
    DUT.register.q[5] === 32'd2) begin
    $display("PASS JALR"); pass_count = pass_count + 1;
end else begin
    $display("FAIL JALR x3=%h x4=%h x5=%h", DUT.register.q[3], DUT.register.q[4], DUT.register.q[5]);
    fail_count = fail_count + 1;
end
release DUT.register.q[1];


check_nop(32'h00000073, "ECALL");
check_nop(32'h0330000F, "FENCE");
check_nop(32'h8330000F, "FENCE.TSO");
check_nop(32'h0100000F, "PAUSE");





        // =====================================================
        // U-TYPE (2)
        // =====================================================

        check_reg(32'h123451B7, 32'h12345000, "LUI");
        check_reg(32'h12345197, 32'h12345000, "AUIPC");

          // =====================================================
        // EBREAK (halts: the next instruction must not run)
        // =====================================================

        clear_memory();
        DUT.SharedMem.mem[0] = 32'h00100073;
        DUT.SharedMem.mem[1] = 32'h00500193; // addi x3,x0,5 must NOT run
        reset_cpu();
        wait_neg_edges(20);

        if (DUT.register.q[3] === 32'd0) begin
            $display("PASS EBREAK");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL EBREAK x3=%h", DUT.register.q[3]);
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
