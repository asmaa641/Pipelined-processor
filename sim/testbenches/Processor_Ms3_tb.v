
/*******************************************************************
*
* Module: Processor_Ms3_tb
* Project: RISCV Processor
* Author: Asmaa Elshabshiri, Janna Alfiky
* Emails: asmaaelshabshiri@aucegypt.edu , jannabassem@aucegypt.edu
* Description: Processor testbench for milestone 3
*
* Change history: 11/18/2026 = Started
*
**********************************************************************/
`timescale 1ns/1ps

module Processor_Ms3_tb;

  reg clk = 0, rst = 1;
  integer pass_count = 0, fail_count = 0;

  Processor DUT(.clk(clk), .rst(rst));

  always #5 clk = ~clk;

  task reset_cpu;
    begin
      rst = 1;
      #12;
      rst = 0;
      #1;
    end
  endtask

  task wait_neg_edges(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1)
        @(negedge clk);
      #1;
    end
  endtask

  task check_reg(input [31:0] ins, input [31:0] exp, input [8*16-1:0] nm);
    begin
      DUT.SharedMem.mem[0] = ins;
      reset_cpu();

      force DUT.register.q[1] = 32'd10;
      force DUT.register.q[2] = 32'd3;

      wait_neg_edges(5);

      if (DUT.register.q[3] === exp) begin
        $display("PASS %0s x3=%h", nm, DUT.register.q[3]);
        pass_count = pass_count + 1;
      end
      else begin
        $display("FAIL %0s expected=%h actual=%h", nm, exp, DUT.register.q[3]);
        fail_count = fail_count + 1;
      end

      release DUT.register.q[1];
      release DUT.register.q[2];
      #1;
    end
  endtask

  task check_load(input [31:0] ins, input [31:0] exp, input [8*16-1:0] nm);
    begin
      DUT.SharedMem.mem[0] = ins;
      DUT.SharedMem.mem[16] = 32'h80000003;
      reset_cpu();

      force DUT.register.q[1] = 32'd64;

      wait_neg_edges(5);

      if (DUT.register.q[3] === exp) begin
        $display("PASS %0s x3=%h", nm, DUT.register.q[3]);
        pass_count = pass_count + 1;
      end
      else begin
        $display("FAIL %0s expected=%h actual=%h", nm, exp, DUT.register.q[3]);
        fail_count = fail_count + 1;
      end

      release DUT.register.q[1];
      #1;
    end
  endtask

  task check_store(input [31:0] ins, input [31:0] exp_mem, input [8*16-1:0] nm);
    begin
      DUT.SharedMem.mem[0] = ins;
      DUT.SharedMem.mem[16] = 32'hAABBCCDD;
      reset_cpu();

      force DUT.register.q[1] = 32'd64;
      force DUT.register.q[2] = 32'd3;

      wait_neg_edges(5);

      if (DUT.SharedMem.mem[16] === exp_mem) begin
        $display("PASS %0s mem=%h", nm, DUT.SharedMem.mem[16]);
        pass_count = pass_count + 1;
      end
      else begin
        $display("FAIL %0s expected mem=%h actual=%h", nm, exp_mem, DUT.SharedMem.mem[16]);
        fail_count = fail_count + 1;
      end

      release DUT.register.q[1];
      release DUT.register.q[2];
      #1;
    end
  endtask

  task check_branch(input [31:0] ins, input [31:0] exp_pc, input [8*16-1:0] nm);
    begin
      DUT.SharedMem.mem[0] = ins;
      reset_cpu();

      force DUT.register.q[1] = 32'd10;
      force DUT.register.q[2] = 32'd3;

      // Branch resolves in the EX stage
      wait_neg_edges(3);

      if (DUT.pcout === exp_pc) begin
        $display("PASS %0s PC=%h", nm, DUT.pcout);
        pass_count = pass_count + 1;
      end
      else begin
        $display("FAIL %0s expected PC=%h actual=%h", nm, exp_pc, DUT.pcout);
        fail_count = fail_count + 1;
      end

      release DUT.register.q[1];
      release DUT.register.q[2];
      #1;
    end
  endtask

  initial begin

    // R-type
    check_reg(32'h002081B3, 13, "ADD");
    check_reg(32'h402081B3, 7, "SUB");
    check_reg(32'h002091B3, 80, "SLL");
    check_reg(32'h0020A1B3, 0, "SLT");
    check_reg(32'h0020B1B3, 0, "SLTU");
    check_reg(32'h0020C1B3, 9, "XOR");
    check_reg(32'h0020D1B3, 1, "SRL");
    check_reg(32'h4020D1B3, 1, "SRA");
    check_reg(32'h0020E1B3, 11, "OR");
    check_reg(32'h0020F1B3, 2, "AND");

    // I-type
    check_reg(32'h00508193, 15, "ADDI");
    check_reg(32'h0050A193, 0, "SLTI");
    check_reg(32'h0050B193, 0, "SLTIU");
    check_reg(32'h0050C193, 15, "XORI");
    check_reg(32'h0050E193, 15, "ORI");
    check_reg(32'h0050F193, 0, "ANDI");
    check_reg(32'h00209193, 40, "SLLI");
    check_reg(32'h0020D193, 2, "SRLI");
    check_reg(32'h4020D193, 2, "SRAI");

    // Loads
    check_load(32'h00008183, 3, "LB");
    check_load(32'h00009183, 3, "LH");
    check_load(32'h0000A183, 32'h80000003, "LW");
    check_load(32'h0000C183, 3, "LBU");
    check_load(32'h0000D183, 3, "LHU");

    // Stores
    check_store(32'h00208023, 32'hAABBCC03, "SB");
    check_store(32'h00209023, 32'hAABB0003, "SH");
    check_store(32'h0020A023, 32'h00000003, "SW");

    // Branches
    // Branch offset = 16 bytes
    // x1 = 10, x2 = 3

    check_branch(32'h00208863, 8, "BEQ");
    check_branch(32'h00209863, 16, "BNE");
    check_branch(32'h0020C863, 8, "BLT");
    check_branch(32'h0020D863, 16, "BGE");
    check_branch(32'h0020E863, 8, "BLTU");
    check_branch(32'h0020F863, 16, "BGEU");

    // JAL
    DUT.SharedMem.mem[0] = 32'h010001EF;
    reset_cpu();

    wait_neg_edges(3);

    if (DUT.pcout === 16) begin
      $display("PASS JAL PC=%h", DUT.pcout);
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL JAL expected PC=00000010 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    wait_neg_edges(2);

    if (DUT.register.q[3] === 4) begin
      $display("PASS JAL link x3=%h", DUT.register.q[3]);
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL JAL link expected=00000004 actual=%h", DUT.register.q[3]);
      fail_count = fail_count + 1;
    end

    // JALR
    DUT.SharedMem.mem[0] = 32'h000081E7;
    reset_cpu();

    force DUT.register.q[1] = 32'd8;

    wait_neg_edges(3);

    if (DUT.pcout === 8) begin
      $display("PASS JALR PC=%h", DUT.pcout);
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL JALR expected PC=00000008 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    wait_neg_edges(2);

    if (DUT.register.q[3] === 4) begin
      $display("PASS JALR link x3=%h", DUT.register.q[3]);
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL JALR link expected=00000004 actual=%h", DUT.register.q[3]);
      fail_count = fail_count + 1;
    end

    release DUT.register.q[1];

    // U-type
    check_reg(32'h123451B7, 32'h12345000, "LUI");

    // AUIPC
    check_reg(32'h12345197, 32'h12345000, "AUIPC");

    // ECALL (NOP)
    DUT.SharedMem.mem[0] = 32'h00000073;
    reset_cpu();
    wait_neg_edges(3);

    if (DUT.pcout === 8) begin
      $display("PASS ECALL");
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL ECALL expected PC=00000008 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    // EBREAK (halt)
    DUT.SharedMem.mem[0] = 32'h00100073;
    reset_cpu();
    wait_neg_edges(3);

    if (DUT.pcout === 4) begin
      $display("PASS EBREAK");
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL EBREAK expected PC=00000004 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    // FENCE (NOP)
    DUT.SharedMem.mem[0] = 32'h0330000F;
    reset_cpu();
    wait_neg_edges(3);

    if (DUT.pcout === 8) begin
      $display("PASS FENCE");
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL FENCE expected PC=00000008 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    // FENCE.TSO (NOP)
    DUT.SharedMem.mem[0] = 32'h8330000F;
    reset_cpu();
    wait_neg_edges(3);

    if (DUT.pcout === 8) begin
      $display("PASS FENCE.TSO");
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL FENCE.TSO expected PC=00000008 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    // PAUSE (NOP)
    DUT.SharedMem.mem[0] = 32'h0100000F;
    reset_cpu();
    wait_neg_edges(3);

    if (DUT.pcout === 8) begin
      $display("PASS PAUSE");
      pass_count = pass_count + 1;
    end
    else begin
      $display("FAIL PAUSE expected PC=00000008 actual=%h", DUT.pcout);
      fail_count = fail_count + 1;
    end

    // Summary
    $display("--------------------------------");
    $display("MS3 SUMMARY: %0d PASS, %0d FAIL", pass_count, fail_count);

    if (fail_count == 0)
      $display("ALL TESTS PASSED");

    $finish;
  end

endmodule
