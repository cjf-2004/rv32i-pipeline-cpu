`timescale 1ns / 1ps

module testbench();

    reg clk;
    reg rst_n;

    // 实例化顶层模块
    rv_top top_inst (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        clk = 0;        // 初始值设为 0
        rst_n = 1;
        #5 rst_n = 0;   // 复位 5ns 后拉低
        #5 rst_n = 1;   // 保持复位低电平 5ns，然后释放
        $display("Simulation running at 100 MHz...");
    end

    // 生成 100MHz 时钟：周期 10ns（5ns 高 + 5ns 低）
    always #5 clk = ~clk;

endmodule