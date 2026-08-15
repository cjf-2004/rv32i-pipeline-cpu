`timescale 1ns / 1ps
`include "macro.vh"

module ALU_32bit (
    input  [31:0] A,          // Operand A (from rs1 or PC)
    input  [31:0] B,          // Operand B (from rs2 or immediate)
    input  [3:0]  ALU_Sel,    // ALU operation select signal from control unit
    output reg [31:0] Result, // ALU result
    output reg        Zero_Flag, // Zero flag, is 1 if Result is 0
    output reg        Lt_Flag
);

    // Combinational logic for ALU operations
    always @(*) begin
        case(ALU_Sel)
            `ALU_ADD: begin // ADD, ADDI, address calculation for loads/stores/JALR, AUIPC
                Result = A + B;
            end

            `ALU_SUB: begin // SUB, BEQ, BNE
                Result = A - B;
            end

            `ALU_AND: begin // AND, ANDI
                Result = A & B;
            end

            `ALU_OR: begin // OR, ORI
                Result = A | B;
            end

            `ALU_XOR: begin // XOR, XORI
                Result = A ^ B;
            end

            `ALU_SLL: begin // SLL, SLLI (Shift Left Logical)
                // Shift amount is taken from the lower 5 bits of B
                Result = A << B[4:0];
            end

            `ALU_SRL: begin // SRL, SRLI (Shift Right Logical)
                // Shift amount is taken from the lower 5 bits of B
                Result = A >> B[4:0];
            end

            `ALU_SRA: begin // SRA, SRAI (Shift Right Arithmetic)
                // Use signed shift, shift amount from B[4:0]
                Result = $signed(A) >>> B[4:0];
            end

            `ALU_SLT: begin // SLT, SLTI (Set on Less Than, signed)
                Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            end

            `ALU_SLTU: begin // SLTU, SLTIU (Set on Less Than, unsigned)
                Result = (A < B) ? 32'd1 : 32'd0;
            end

            `ALU_PASS_B: begin // Used for LUI, where ALU is not needed but a value must pass through
                Result = B;
            end

            default: begin // Default case to avoid latches
                Result = 32'h00000000;
            end
        endcase
    end

    // Zero flag is set if the result is zero.
    // This is useful for branch instructions like BEQ and BNE.
    always @(*) begin
        if (Result == 32'h00000000) begin
            Zero_Flag = 1'b1;
            Lt_Flag = 1'b0;
        end else begin
            Zero_Flag = 1'b0;
            Lt_Flag = 1'b1;
        end
    end

endmodule
