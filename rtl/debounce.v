`timescale 1ns / 1ps

module debounce (
    input clk,
    input rst_n,
    input btn_in,
    output reg posedge_out
);

    // --- 可配置参数 ---
    parameter CLOCK_FREQUENCY_HZ = 25_000_000; // 修正为实际频率（如25MHz）
    parameter DEBOUNCE_DELAY_MS  = 20;

    // --- 内部计算 ---
    // 更精确的计数周期计算
    localparam DEBOUNCE_MAX_COUNT = (CLOCK_FREQUENCY_HZ * DEBOUNCE_DELAY_MS) / 1000;
    localparam CNT_WIDTH = $clog2(DEBOUNCE_MAX_COUNT + 1); // +1 防止宽度不够

    // --- 状态定义 ---
    localparam S_IDLE      = 2'b00;
    localparam S_DEBOUNCE  = 2'b01;
    localparam S_STABLE    = 2'b10;

    // --- 信号声明 ---
    reg [CNT_WIDTH-1:0] counter;
    reg btn_sync_1, btn_sync_2;
    reg [1:0] state;

    // --- 两级同步器 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_1 <= 1'b0;
            btn_sync_2 <= 1'b0;
        end else begin
            btn_sync_1 <= btn_in;
            btn_sync_2 <= btn_sync_1;
        end
    end

    // --- 主状态机 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            counter <= 'd0;
            posedge_out <= 1'b0;
        end else begin
            posedge_out <= 1'b0; // 默认不输出脉冲

            case(state)
                S_IDLE: begin
                    if (btn_sync_2 == 1'b1) begin // 检测到上升沿
                        state <= S_DEBOUNCE;
                        counter <= 'd0;
                    end
                end

                S_DEBOUNCE: begin
                    if (btn_sync_2 == 1'b1) begin
                        if (counter == DEBOUNCE_MAX_COUNT - 1) begin
                            state <= S_STABLE;
                            posedge_out <= 1'b1; // 输出单周期脉冲
                        end else begin
                            counter <= counter + 1;
                        end
                    end else begin
                        state <= S_IDLE; // 抖动，返回空闲
                    end
                end

                S_STABLE: begin
                    if (btn_sync_2 == 1'b0) begin
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule