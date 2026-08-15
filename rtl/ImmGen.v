`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/29 11:07:45
// Design Name: 
// Module Name: ImmGen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`include "macro.vh"

module ImmGen(
    input  wire [31:0] instr,      // The 32-bit instruction word
    output reg  [31:0] imm_out     // The sign-extended 32-bit immediate value
);

    // Instruction fields for immediate extraction
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            // I-type: ADDI, SLTI, LW, JALR etc.
            `OPCODE_I, `OPCODE_L, `OPCODE_JALR: begin
                // imm[11:0] = instr[31:20]
                // Sign-extend from the 12th bit (instr[31])
                imm_out = {{20{instr[31]}}, instr[31:20]};
            end

            // S-type: SW, SH, SB etc.
            `OPCODE_S: begin
                // imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
                // Sign-extend from the 12th bit (instr[31])
                imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            // B-type: BEQ, BNE, BLT etc.
            `OPCODE_B: begin
                // imm[12|10:5] = instr[31|30:25], imm[4:1|11] = instr[11:8|7]
                // The immediate is multiplied by 2, so the LSB is always 0.
                // Sign-extend from the 13th bit (instr[31])
                imm_out = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            // U-type: LUI, AUIPC
            `OPCODE_LUI, `OPCODE_AUIPC: begin
                // imm[31:12] = instr[31:12], imm[11:0] = 0
                imm_out = {instr[31:12], 12'b0};
            end

            // J-type: JAL
            `OPCODE_JAL: begin
                // imm[20|10:1|11|19:12] = instr[31|30:21|20|19:12]
                // The immediate is multiplied by 2, so the LSB is always 0.
                // Sign-extend from the 21st bit (instr[31])
                imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default: begin
                // For instructions without an immediate (like R-type), output 0.
                imm_out = 32'h00000000;
            end
        endcase
    end

endmodule
