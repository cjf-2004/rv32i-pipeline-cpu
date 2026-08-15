`timescale 1ns / 1ps
`include "macro.vh"
//////////////////////////////////////////////////////////////////////////////////
// 统一内存模块 (Unified Memory)
// 功能: 模拟一个单一的内存块，同时处理指令读取和数据读写。
// 修改: 在一个模块内，将内存划分为text、data和stack三个逻辑部分。
//////////////////////////////////////////////////////////////////////////////////
module unified_mem (
    input clk,
    
    // 指令总线端口
    input [31:0] imem_addr,
    output [31:0] imem_data,

    // 数据总线端口
    input we,           // 写使能
    input [31:0] dmem_addr,    // 地址
    input [31:0] wdata,    // 写入数据
    output [31:0] rdata    // 读出数据
);

    // 物理内存：将一个大内存逻辑上分为三个部分
    reg [31:0] text_mem [0:`TEXT_SIZE/4 - 1];
    reg [31:0] data_mem [0:`DATA_SIZE/4 - 1];
    reg [31:0] stack_mem [0:`STACK_SIZE/4 - 1];
    reg [31:0] interrupt_mem [0:`INTERRUPT_SIZE/4 - 1];
    
    // 地址映射逻辑
    function [31:0] get_mem_index;
        input [31:0] v_addr;
        begin
            if (v_addr >= `TEXT_VADDR_START && v_addr < `DATA_VADDR_START) begin
                // 虚拟地址在 .text 段
                get_mem_index = (v_addr - `TEXT_VADDR_START) >> 2;
            end else if (v_addr >= `DATA_VADDR_START && v_addr < `STACK_VADDR_LIMIT) begin
                // 虚拟地址在 .data 段
                get_mem_index = (v_addr - `DATA_VADDR_START) >> 2;
            end else if (v_addr >= `STACK_VADDR_LIMIT && v_addr <= `STACK_VADDR_TOP) begin
                // 虚拟地址在堆栈区域
                get_mem_index = (`STACK_VADDR_TOP - v_addr) >> 2;
            end else if (v_addr >= `INTERRUPT_VADDR_START && v_addr <= `TEXT_VADDR_START) begin
                // 虚拟地址在堆栈区域
                get_mem_index = (v_addr - `INTERRUPT_VADDR_START) >> 2;    
            end else begin
                // 其他未定义的虚拟地址
                get_mem_index = 32'hFFFFFFFF;
            end
        end
    endfunction

    // 初始化内存内容
    // 使用 $readmemh 在综合时加载内存数据
    initial begin
        // 使用相对路径，确保 Vivado 可以在项目目录中找到这些文件
        $readmemh("E:/Local/streamlineCPU/seven_lv3.txt", text_mem);
        $readmemh("E:/Local/streamlineCPU/interrupt_handle_data.txt", data_mem);
        $readmemh("E:/Local/streamlineCPU/interrupt_handle.txt", interrupt_mem);
        
        // stack_mem 在这里不需要初始化，因为通常是动态分配的
    end

    // 指令端口读操作 (组合逻辑)
    assign imem_data = imem_addr >= `TEXT_VADDR_START ? text_mem[get_mem_index(imem_addr)] :
                       interrupt_mem[get_mem_index(imem_addr)] ;
    
    // 数据端口读操作 (组合逻辑, 零延迟)
    // 根据地址选择正确的内存段并输出数据
    assign rdata = (dmem_addr >= `DATA_VADDR_START && dmem_addr < `STACK_VADDR_LIMIT) ? 
                    data_mem[get_mem_index(dmem_addr)] : 
                    (dmem_addr >= `STACK_VADDR_LIMIT && dmem_addr <= `STACK_VADDR_TOP) ? 
                    stack_mem[get_mem_index(dmem_addr)] : 
                    32'hFFFFFFFF; // 无效地址

    // 数据端口写操作 (时序逻辑)
    always @(posedge clk) begin
        if (we) begin
            if (dmem_addr >= `DATA_VADDR_START && dmem_addr < `STACK_VADDR_LIMIT) begin
                // 写入data段
                data_mem[get_mem_index(dmem_addr)] <= wdata;
            end else if (dmem_addr >= `STACK_VADDR_LIMIT && dmem_addr <= `STACK_VADDR_TOP) begin
                // 写入stack段
                stack_mem[get_mem_index(dmem_addr)] <= wdata;
            end
        end
    end
endmodule
