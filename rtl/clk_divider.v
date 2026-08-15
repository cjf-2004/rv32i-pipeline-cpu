`timescale 1ns / 1ps

// 时钟分频模块
// 将输入的高频时钟 clk_in 分频为低频时钟 clk_out
// ---------------------------------------------------------------------------------
// 参数说明:
//    DIV_FACTOR: 分频系数
//    100MHz 系统时钟 / 50 = 2MHz SPI时钟
// ---------------------------------------------------------------------------------
module clk_divider_1_50 #(
    parameter DIV_FACTOR = 50
) (
    input wire clk_in,
    input wire rst_n,
    output wire clk_out
);

    reg [5:0] counter;
    reg clk_out_reg;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            clk_out_reg <= 0;
        end else begin
            if (counter == (DIV_FACTOR / 2) - 1) begin
                clk_out_reg <= ~clk_out_reg;
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    assign clk_out = clk_out_reg;

endmodule
