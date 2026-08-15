`timescale 1ns / 1ps

// 建议将宏定义放在一个单独的文件中，例如 "macro.vh" 或 "defines.v"
`include "macro.vh"

module control(
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    output wire [3:0] alu_op,   // 注意：根据之前的ALU设计，alu_op应为4位
    output wire       alu_cA,        // ALU操作数A选择: 1 for PC, 0 for rs1
    output wire       alu_cB,       // ALU操作数B选择: 0 for Imm, 1 for rs2
    output wire [1:0] cWB,       // 写回数据选择
    output wire [3:0] branch,   // 分支/跳转类型
    output wire       dmem_we,  // 数据存储器写使能
    output wire       reg_we    // 寄存器写使能
);

// ALU 操作选择信号 (已在之前完善)
assign alu_op =
    // R-Type
    (opcode == `OPCODE_R) ?
        ((funct3 == `FUNCT3_ADD_SUB && funct7 == `FUNCT7_ADD) ? `ALU_ADD :
         (funct3 == `FUNCT3_ADD_SUB && funct7 == `FUNCT7_SUB) ? `ALU_SUB :
         (funct3 == `FUNCT3_SLL)                             ? `ALU_SLL :
         (funct3 == `FUNCT3_SLT)                             ? `ALU_SLT :
         (funct3 == `FUNCT3_SLTU)                            ? `ALU_SLTU :
         (funct3 == `FUNCT3_XOR)                             ? `ALU_XOR :
         (funct3 == `FUNCT3_SR && funct7 == `FUNCT7_SRL)      ? `ALU_SRL :
         (funct3 == `FUNCT3_SR && funct7 == `FUNCT7_SRA)      ? `ALU_SRA :
         (funct3 == `FUNCT3_OR)                              ? `ALU_OR  :
         (funct3 == `FUNCT3_AND)                             ? `ALU_AND : `ALU_NULL) :
    // I-Type (ALU immediate)
    (opcode == `OPCODE_I) ?
        ((funct3 == `FUNCT3_ADD_SUB)                         ? `ALU_ADD :
         (funct3 == `FUNCT3_SLL)                             ? `ALU_SLL :
         (funct3 == `FUNCT3_SLT)                             ? `ALU_SLT :
         (funct3 == `FUNCT3_SLTU)                            ? `ALU_SLTU :
         (funct3 == `FUNCT3_XOR)                             ? `ALU_XOR :
         (funct3 == `FUNCT3_SR && funct7 == `FUNCT7_SRL)      ? `ALU_SRL :
         (funct3 == `FUNCT3_SR && funct7 == `FUNCT7_SRA)      ? `ALU_SRA :
         (funct3 == `FUNCT3_OR)                              ? `ALU_OR  :
         (funct3 == `FUNCT3_AND)                             ? `ALU_AND : `ALU_NULL) :
    // Load/Store (Address calculation)
    (opcode == `OPCODE_L || opcode == `OPCODE_S)             ? `ALU_ADD :
    // Branch (Comparison)
    (opcode == `OPCODE_B) ?
        ((funct3 == `FUNCT3_BEQ || funct3 == `FUNCT3_BNE)    ? `ALU_SUB :
         (funct3 == `FUNCT3_BLT || funct3 == `FUNCT3_BGE)    ? `ALU_SLT :
         (funct3 == `FUNCT3_BLTU || funct3 == `FUNCT3_BGEU)  ? `ALU_SLTU : `ALU_NULL) :
    // U-Type
    (opcode == `OPCODE_LUI)                                  ? `ALU_PASS_B :
    (opcode == `OPCODE_AUIPC)                                ? `ALU_ADD :
    // J-Type
    (opcode == `OPCODE_JALR)                                 ? `ALU_ADD :
    (opcode == `OPCODE_JAL)                                  ? `ALU_ADD :
    // Default
    `ALU_NULL;


assign alu_cA = (opcode == `OPCODE_AUIPC || opcode == `OPCODE_JAL);
// c2: ALU第二个操作数选择 (1 表示来自 rs2)
assign alu_cB = (opcode == `OPCODE_R || opcode == `OPCODE_B);

// c3: 写回数据选择
// 2'b00: Imm (LUI)
// 2'b01: PC+4 (JAL, JALR)
// 2'b10: ALU Result (R-type, I-type, AUIPC)
// 2'b11: Memory Data (Load)
assign cWB =
    (opcode == `OPCODE_LUI)   ? 2'b00 :
    (opcode == `OPCODE_JAL || opcode == `OPCODE_JALR) ? 2'b01 :
    (opcode == `OPCODE_L)     ? 2'b11 :
    /* R, I, AUIPC */          2'b10;

// *** MODIFIED: Branch signal decoding logic ***
assign branch =
    (opcode == `OPCODE_JAL)  ? `BR_JAL :
    (opcode == `OPCODE_JALR) ? `BR_JALR :
    (opcode == `OPCODE_B)    ?
        (funct3 == `FUNCT3_BEQ)  ? `BR_BEQ :
        (funct3 == `FUNCT3_BNE)  ? `BR_BNE :
        (funct3 == `FUNCT3_BLT)  ? `BR_BLT :
        (funct3 == `FUNCT3_BGE)  ? `BR_BGE :
        (funct3 == `FUNCT3_BLTU) ? `BR_BLTU :
        (funct3 == `FUNCT3_BGEU) ? `BR_BGEU :
                                  `BR_NONE :
    `BR_NONE;

// dmem_we: 数据存储器写使能
assign dmem_we = (opcode == `OPCODE_S);

// reg_we: 寄存器堆写使能
assign reg_we = (opcode == `OPCODE_R || opcode == `OPCODE_I || opcode == `OPCODE_L ||
                 opcode == `OPCODE_LUI || opcode == `OPCODE_AUIPC ||
                 opcode == `OPCODE_JAL || opcode == `OPCODE_JALR);

endmodule
