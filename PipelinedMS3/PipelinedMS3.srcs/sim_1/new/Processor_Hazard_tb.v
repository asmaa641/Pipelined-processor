`timescale 1ns / 1ps

// Hazard / pipeline test for Processor (phase-based shared memory version).
// Programs are written with small encoder functions so no hex is hand-typed.
// Every program ends in NOPs (memory is filled with NOPs first).

module Processor_Hazard_tb;

    reg clk;
    reg rst;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    Processor DUT (.clk(clk), .rst(rst));

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------------
    // Instruction encoders
    // ---------------------------------------------------------
    localparam [31:0] NOP = 32'h00000013;

    function [31:0] i_addi(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        i_addi = {imm, rs1, 3'b000, rd, 7'h13};
    endfunction

    function [31:0] i_add(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        i_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'h33};
    endfunction

    function [31:0] i_lw(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        i_lw = {imm, rs1, 3'b010, rd, 7'h03};
    endfunction

    function [31:0] i_sw(input [4:0] rs2, input [4:0] rs1, input [11:0] imm);
        i_sw = {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'h23};
    endfunction

    function [31:0] i_beq(input [4:0] rs1, input [4:0] rs2, input [12:0] off);
        i_beq = {off[12], off[10:5], rs2, rs1, 3'b000, off[4:1], off[11], 7'h63};
    endfunction

    function [31:0] i_bne(input [4:0] rs1, input [4:0] rs2, input [12:0] off);
        i_bne = {off[12], off[10:5], rs2, rs1, 3'b001, off[4:1], off[11], 7'h63};
    endfunction

    function [31:0] i_jal(input [4:0] rd, input [20:0] off);
        i_jal = {off[20], off[10:1], off[11], off[19:12], rd, 7'h6F};
    endfunction

    function [31:0] i_jalr(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        i_jalr = {imm, rs1, 3'b000, rd, 7'h67};
    endfunction

    // ---------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------
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
        input [8*28-1:0] nm;
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

    task check_mem;
        input integer idx;
        input [31:0] exp;
        input [8*28-1:0] nm;
    begin
        if (DUT.SharedMem.mem[idx] === exp) begin
            $display("PASS %0s  mem[%0d]=%h", nm, idx, DUT.SharedMem.mem[idx]);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL %0s  mem[%0d] expected=%h actual=%h", nm, idx, exp, DUT.SharedMem.mem[idx]);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // ---------------------------------------------------------
    // MAIN
    // ---------------------------------------------------------
    initial begin
        rst = 1;
        clear_memory();

        // =====================================================
        // FORWARDING
        // =====================================================

        // F1: EX/MEM and MEM/WB forwarding, both operands
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 5);
        DUT.SharedMem.mem[1] = i_add (2, 1, 1);   // 10  (x1 from EX/MEM, both operands)
        DUT.SharedMem.mem[2] = i_add (3, 2, 1);   // 15  (x2 EX/MEM, x1 MEM/WB)
        DUT.SharedMem.mem[3] = i_add (4, 3, 2);   // 25
        run_program(60);
        check_reg(1, 32'd5,  "F1 fwd chain");
        check_reg(2, 32'd10, "F1 fwd chain");
        check_reg(3, 32'd15, "F1 fwd chain");
        check_reg(4, 32'd25, "F1 fwd chain");

        // F2: MEM/WB forwarding (one instruction gap)
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 7);
        DUT.SharedMem.mem[1] = NOP;
        DUT.SharedMem.mem[2] = i_add (2, 1, 1);   // 14
        run_program(60);
        check_reg(2, 32'd14, "F2 MEM/WB fwd");

        // F3: EX/MEM has priority over MEM/WB (newest value wins)
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 1);
        DUT.SharedMem.mem[1] = i_addi(1, 0, 2);
        DUT.SharedMem.mem[2] = i_add (2, 1, 0);   // must be 2
        run_program(60);
        check_reg(2, 32'd2, "F3 priority");

        // F4: x0 is never forwarded
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(0, 0, 5);   // write to x0 is ignored
        DUT.SharedMem.mem[1] = i_add (2, 0, 0);   // 0
        DUT.SharedMem.mem[2] = i_addi(3, 0, 9);
        DUT.SharedMem.mem[3] = i_add (4, 0, 3);   // 9
        run_program(60);
        check_reg(0, 32'd0, "F4 x0 stays 0");
        check_reg(2, 32'd0, "F4 x0 not forwarded");
        check_reg(4, 32'd9, "F4 x0 + x3");

        // F5: store data and address forwarded
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(10, 0, 192);   // address 192 = word 48
        DUT.SharedMem.mem[1] = i_addi(5, 0, 85);     // 0x55
        DUT.SharedMem.mem[2] = i_sw  (5, 10, 0);
        DUT.SharedMem.mem[3] = i_lw  (6, 10, 0);
        run_program(60);
        check_mem(48, 32'h00000055, "F5 store fwd");
        check_reg(6,  32'h00000055, "F5 load back");

        // =====================================================
        // LOAD-USE
        // =====================================================

        // L1: consumer right after load (rs1 and rs2 uses)
        clear_memory();
        DUT.SharedMem.mem[48] = 32'd42;
        DUT.SharedMem.mem[0] = i_addi(10, 0, 192);
        DUT.SharedMem.mem[1] = i_lw  (3, 10, 0);
        DUT.SharedMem.mem[2] = i_add (4, 3, 3);   // 84 (stall needed)
        DUT.SharedMem.mem[3] = i_add (5, 4, 3);   // 126
        DUT.SharedMem.mem[4] = i_lw  (6, 10, 0);
        DUT.SharedMem.mem[5] = i_add (7, 0, 6);   // 42 (load result in rs2)
        run_program(80);
        check_reg(3, 32'd42,  "L1 load");
        check_reg(4, 32'd84,  "L1 load-use");
        check_reg(5, 32'd126, "L1 after stall");
        check_reg(7, 32'd42,  "L1 load-use rs2");

        // L2: store data comes straight from a load
        clear_memory();
        DUT.SharedMem.mem[48] = 32'd42;
        DUT.SharedMem.mem[0] = i_addi(10, 0, 192);
        DUT.SharedMem.mem[1] = i_lw  (3, 10, 0);
        DUT.SharedMem.mem[2] = i_sw  (3, 10, 4);  // mem[49] = 42
        run_program(80);
        check_mem(49, 32'd42, "L2 load then store");

        // =====================================================
        // CONTROL HAZARDS (FLUSH)
        // =====================================================

        // C1: taken branch, operand forwarded, wrong path flushed
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 1);
        DUT.SharedMem.mem[1] = i_beq (1, 1, 12);  // to word 4
        DUT.SharedMem.mem[2] = i_addi(2, 0, 17);  // wrong path
        DUT.SharedMem.mem[3] = i_addi(3, 0, 34);  // wrong path
        DUT.SharedMem.mem[4] = i_addi(4, 0, 51);  // target
        run_program(60);
        check_reg(2, 32'd0,  "C1 taken: flush 1");
        check_reg(3, 32'd0,  "C1 taken: flush 2");
        check_reg(4, 32'd51, "C1 taken: target");

        // C2: not-taken branch, following instructions must run
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 1);
        DUT.SharedMem.mem[1] = i_addi(2, 0, 2);
        DUT.SharedMem.mem[2] = i_beq (1, 2, 12);
        DUT.SharedMem.mem[3] = i_addi(3, 0, 34);
        DUT.SharedMem.mem[4] = i_addi(4, 0, 51);
        run_program(60);
        check_reg(3, 32'd34, "C2 not taken");
        check_reg(4, 32'd51, "C2 not taken");

        // C3: JAL flushes the wrong path and links PC+4
        clear_memory();
        DUT.SharedMem.mem[0] = i_jal (1, 12);     // to word 3
        DUT.SharedMem.mem[1] = i_addi(2, 0, 17);  // wrong path
        DUT.SharedMem.mem[2] = i_addi(3, 0, 34);  // wrong path
        DUT.SharedMem.mem[3] = i_addi(4, 0, 51);
        run_program(60);
        check_reg(1, 32'd4,  "C3 JAL link");
        check_reg(2, 32'd0,  "C3 JAL flush 1");
        check_reg(3, 32'd0,  "C3 JAL flush 2");
        check_reg(4, 32'd51, "C3 JAL target");

        // C4: JALR with a just-computed base register
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(5, 0, 16);
        DUT.SharedMem.mem[1] = i_jalr(1, 5, 0);   // to word 4, link = 8
        DUT.SharedMem.mem[2] = i_addi(2, 0, 17);  // wrong path
        DUT.SharedMem.mem[3] = i_addi(3, 0, 34);  // wrong path
        DUT.SharedMem.mem[4] = i_addi(4, 0, 51);
        run_program(60);
        check_reg(1, 32'd8,  "C4 JALR link");
        check_reg(2, 32'd0,  "C4 JALR flush 1");
        check_reg(3, 32'd0,  "C4 JALR flush 2");
        check_reg(4, 32'd51, "C4 JALR target");

        // C5: branch whose operand is a load result (stall, then flush)
        clear_memory();
        DUT.SharedMem.mem[48] = 32'd42;
        DUT.SharedMem.mem[0] = i_addi(10, 0, 192);
        DUT.SharedMem.mem[1] = i_lw  (3, 10, 0);
        DUT.SharedMem.mem[2] = i_beq (3, 3, 12);  // to word 5
        DUT.SharedMem.mem[3] = i_addi(2, 0, 17);  // wrong path
        DUT.SharedMem.mem[4] = i_addi(6, 0, 34);  // wrong path
        DUT.SharedMem.mem[5] = i_addi(4, 0, 51);
        run_program(80);
        check_reg(3, 32'd42, "C5 load before branch");
        check_reg(2, 32'd0,  "C5 flush 1");
        check_reg(6, 32'd0,  "C5 flush 2");
        check_reg(4, 32'd51, "C5 target");

        // C6: loop (repeated taken branches)
        clear_memory();
        DUT.SharedMem.mem[0] = i_addi(1, 0, 0);
        DUT.SharedMem.mem[1] = i_addi(2, 0, 5);
        DUT.SharedMem.mem[2] = i_addi(1, 1, 1);
        DUT.SharedMem.mem[3] = i_bne (1, 2, -4);  // back to word 2
        DUT.SharedMem.mem[4] = i_addi(3, 0, 119);
        run_program(90);
        check_reg(1, 32'd5,   "C6 loop count");
        check_reg(3, 32'd119, "C6 after loop");

        // =====================================================
        // SUMMARY
        // =====================================================
        $display("\n================================");
        $display("HAZARD TEST SUMMARY");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("================================");
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $finish;
    end

endmodule

