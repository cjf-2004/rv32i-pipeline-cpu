`timescale 1ns / 1ps

module mux3 (
    input wire [31:0] imm,
    input wire [31:0] pc_plus_4,
    input wire [31:0] alu_result,
    input wire [31:0] dmem_data,
    input wire [1:0] sel,
    output wire [31:0] c3_se
);

    assign c3_se = 
        (sel == 2'b00) ? imm :
        (sel == 2'b01) ? pc_plus_4:
        (sel == 2'b10) ? alu_result:
        dmem_data;
endmodule