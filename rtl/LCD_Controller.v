`timescale 1ns / 1ps

// LCD控制器模块
// 功能: 实现一个内存映射的SPI接口，将CPU的并行数据转换为串行信号发送给LCD
//       本模块使用外部分频时钟 clk_spi
// ---------------------------------------------------------------------------------
module lcd_controller (
    // CPU总线接口
    input wire clk_sys,                 // 系统时钟，例如100MHz
    input wire clk_spi,                 // SPI工作时钟，例如2MHz
    input wire rst_n,                   // 同步复位，低电平有效
    input wire [31:0] cpu_address,          // CPU总线地址
    input wire [31:0] cpu_write_data,     // CPU写入的数据
    input wire cpu_write_en,            // CPU写使能
    output wire [31:0] cpu_read_data,     // 读回给CPU的数据
    
    // LCD物理引脚
    output wire LCD_SCK,                // 串行时钟
    output reg LCD_SDA,                // 串行数据
    output reg LCD_A0,                 // 命令/数据选择 (0=命令, 1=数据)
    output reg LCD_RST,                // 复位信号 (低电平有效)
    output reg LCD_CS                  // 片选信号 (低电平有效)
);

    // --- 内存映射地址和参数 ---
    localparam ADDR_CONTROL = 32'h80000000;
    localparam ADDR_DATA    = 32'h80000004;
    localparam ADDR_STATUS  = 32'h80000008;

    // 复位延迟计数器的最大值，例如等待1000个系统时钟周期
    localparam RESET_DELAY_MAX = 20_000_000;
    localparam DONE_DELAY_MAX = 600;
    localparam RESET_SIGNAL_DELAY_MAX = 1000;
    // --- 状态机定义 ---
    localparam [2:0]
        S_IDLE         = 3'b000, // 空闲状态，等待CPU写入
        S_START_RESET = 3'b001, // 启动复位脉冲
        S_WAIT_RESET  = 3'b010, // 等待复位结束
        S_TRANSMIT    = 3'b011, // 传输数据
        S_DONE        = 3'b100; // 传输完成
    
    // --- 内部寄存器和信号 ---
    reg [2:0] state, next_state;

    // CPU写入的寄存器，由CPU直接控制
    reg [2:0] reg_control;
    reg [7:0] reg_data;
    
    // 修正: 复位延迟计数器，由系统时钟驱动 复位时间需要120ms
    reg [30:0] reset_counter;
    //状态done的延迟计数器
    reg [10:0] done_delay_counter ;
    //LCD_RST需要维持至少2us
    reg [10:0] reset_signal_counter ;
    // 传输完成标志位，可被CPU读写
    reg tx_complete; 
    
    // SPI传输相关信号
    reg [7:0] shift_reg;       // 8位移位寄存器，用于串行发送数据
    reg [3:0] bit_counter;     // 位计数器
    reg data_is_command;       // 1=数据，0=命令
    reg start_tx;              // 启动传输信号，由CPU写入控制寄存器触发
    reg data_prepared;         //准备数据
    // --- 组合逻辑：Next State和输出信号的计算 ---
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (!rst_n) begin
                    next_state = S_START_RESET;
                end else if (start_tx) begin
                    next_state = S_TRANSMIT;
                end
            end
            
            S_START_RESET: begin
                // 等待复位信号计数器完成
                if (reset_signal_counter == RESET_SIGNAL_DELAY_MAX) begin
                    next_state = S_WAIT_RESET;
                end
            end
            
            S_WAIT_RESET: begin
                // 等待复位计数器完成
                if (reset_counter == RESET_DELAY_MAX) begin
                    next_state = S_IDLE;
                end
            end
            
            S_TRANSMIT: begin
                // 当计数器在数据准备好的时候会spi下降的时候加1
                //达到 9 但其实只迎来了8个上升沿(即发送完8位)时，转换到S_DONE状态
                if (bit_counter == 4'd9) begin
                    next_state = S_DONE;
                end
            end
            
            S_DONE: begin
                // 传输完成后，保持在DONE状态一个周期，然后回到IDLE
               if (done_delay_counter == DONE_DELAY_MAX) next_state = S_IDLE;
            end
        endcase
    end
    
    // --- 时序逻辑：状态机、计数器和寄存器的更新 ---
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_START_RESET;
            reset_counter <= 0;
            reset_signal_counter <= 0;
            done_delay_counter <= 0;
            LCD_RST <= 1'b0; // 初始复位
            LCD_CS <= 1'b1; // 复位时释放片选
            LCD_A0 <= 1'b0;
            tx_complete <= 1'b0;
            start_tx <= 1'b0;
            
        end else begin
            state <= next_state;
            
            // 复位延迟计数器，由系统时钟驱动
            if (state == S_WAIT_RESET) begin
                reset_counter <= reset_counter + 1;
            end else begin
                reset_counter <= 0;
            end
            // 复位延迟计数器，由系统时钟驱动
            if (state == S_START_RESET) begin
                reset_signal_counter <= reset_signal_counter + 1;
            end else begin
                reset_signal_counter <= 0;
            end
            // 复位脉冲控制
            if (state == S_START_RESET) begin
            
                LCD_RST <= 1'b0;
            end else begin
                LCD_RST <= 1'b1;
            end
            
            // CPU写入接口
            if (cpu_write_en) begin
                case (cpu_address)
                    ADDR_CONTROL: begin
                        reg_control <= cpu_write_data[2:0];
                        data_is_command <= cpu_write_data[1]; // 1=数据模式, 0=命令模式
                        start_tx <= cpu_write_data[0];
                        // 修正：如果CPU启动新传输，则清除完成标志
                        if (cpu_write_data[0]) begin
                            tx_complete <= 1'b0;
                        end
                    end
                    ADDR_DATA: begin
                        reg_data <= cpu_write_data[7:0];
                        
                    end
                endcase
            end
            
            // 传输完成后，设置完成标志位
            // 传输完成延迟计数器
            if (state == S_DONE) begin
                done_delay_counter <= done_delay_counter + 1;
            end else begin
                done_delay_counter <= 0;
            end
            if (state == S_DONE && next_state == S_IDLE) begin // 或者检测 done_delay_counter 溢出
                tx_complete <= 1'b1;
                start_tx <= 1'b0;
            end
            
            // 片选控制
            if (state == S_TRANSMIT && data_prepared == 1'b1) begin
                LCD_CS <= 1'b0; // 传输期间选中
            end else begin
                LCD_CS <= 1'b1; // 其他时间释放
            end
            //控制信号 控制数据类型
            if (state == S_IDLE && start_tx) begin
                LCD_A0 <= data_is_command;
            end

        end
    end

    // 时序逻辑：SPI数据传输，在SPI时钟的下降沿锁存数据
    always @(negedge clk_spi or negedge rst_n) begin
        if(!rst_n) begin
            bit_counter <= 4'd0;
        end else begin
            // 在传输的第一个下降沿，将 reg_data 加载到 shift_reg
            if (bit_counter == 4'd0) begin
                shift_reg <= reg_data; // <<< 从 reg_data 加载
            end
            if (state == S_TRANSMIT) begin
                LCD_SDA <= shift_reg[7]; // MSB first
                shift_reg <= shift_reg << 1;
                bit_counter <= bit_counter + 1;
                data_prepared <= 1'b1;
            end else begin
                bit_counter  <= 0;
                data_prepared <= 1'b0;
            end
        end
    end

    // 组合逻辑：SPI时钟直接输出
    // LCD_SCK 的有效边沿为上升沿，确保数据在下降沿更新后有稳定的建立时间
    assign LCD_SCK = clk_spi;
    // --- 组合逻辑：直接输出到引脚 ---
    // 状态寄存器，提供给CPU读取，指示控制器状态
    // 现在直接由 tx_complete 标志位驱动，实现"粘滞"效果
    assign cpu_read_data = (cpu_address == ADDR_STATUS) ? {29'b0, 2'b0, tx_complete} : 32'b0;

endmodule