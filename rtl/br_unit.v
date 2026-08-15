`timescale 1ns / 1ps
`include "macro.vh"


module br_unit(
    input wire [3:0] branch_type,   // The new 4-bit branch signal from control unit
    input wire       zero_flag,     // From ALU (is 1 if A-B is zero)
    input wire       lt_flag,       // From ALU (is 1 if A < B for SLT/SLTU)
    output reg[1:0]       branch_taken   // Output signal, high if branch/jump occurs
);

    always @(*) begin
        case (branch_type)
            // Unconditional Jumps
            `BR_JAL, `BR_JALR:
                branch_taken = 2'b10;

            // Conditional Branches based on Zero Flag
            `BR_BEQ: // Branch if Equal (A-B == 0)
                branch_taken = {1'b0,zero_flag};
            `BR_BNE: // Branch if Not Equal (A-B != 0)
                branch_taken = {1'b0,~zero_flag};

            // Conditional Branches based on Less-Than Flag
            `BR_BLT, `BR_BLTU: // Branch if Less Than (A < B)
                branch_taken = {1'b0,lt_flag};
            `BR_BGE, `BR_BGEU: // Branch if Greater Than or Equal (A >= B)
                branch_taken = {1'b0,~lt_flag};

            default: // Not a branch or jump
                branch_taken = 2'b00;
        endcase
    end

endmodule
