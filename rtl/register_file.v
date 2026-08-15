`timescale 1ns / 1ps

module register_file (
    input wire clk,
    input wire rst_n,
    input wire we,
    input wire [4:0] wa,
    input wire [31:0] wd,
    input wire [4:0] ra1,
    input wire [4:0] ra2,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

reg [31:0] registers [0:31];

integer i;

always @(posedge clk or negedge rst_n)begin
   if(!rst_n) begin 
       for (i = 0; i < 32; i = i + 1) begin
            if(i != 2 || i !=31) registers[i] <= 32'b0;
       end
       registers[2] <= 32'h7fffeffc;
       registers[31] <= 32'h00400000;
   end else begin
        if (we) begin
            if(wa != 0)registers[wa] <= wd;
        end
    end
end
assign rd1 = registers[ra1];
assign rd2 = registers[ra2];
endmodule
