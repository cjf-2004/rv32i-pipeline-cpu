module vga_display (
    input wire clk_in,    // 25 MHz clock
    input wire rst_n,     // Active-low reset
    input wire [23:0] display_data, //显示的时分秒
    output reg [3:0] vga_r, // Red color output (4 bits)
    output reg [3:0] vga_g, // Green color output (4 bits)
    output reg [3:0] vga_b, // Blue color output (4 bits)
    output reg hsync,     // Horizontal sync pulse
    output reg vsync      // Vertical sync pulse
);

    // VGA Timing parameters for 640x480 @ 60Hz (标准VGA时序参数)
    localparam H_DISPLAY = 640;  // 可见区域宽度
    localparam H_FP      = 16;   // 水平前沿
    localparam H_SYNC    = 96;   // 水平同步脉冲宽度
    localparam H_BP      = 48;   // 水平后沿
    localparam H_TOTAL   = H_DISPLAY + H_FP + H_SYNC + H_BP; // 800

    localparam V_DISPLAY = 480;  // 可见区域高度
    localparam V_FP      = 10;   // 垂直前沿
    localparam V_SYNC    = 2;    // 垂直同步脉冲宽度
    localparam V_BP      = 33;   // 垂直后沿
    localparam V_TOTAL   = V_DISPLAY + V_FP + V_SYNC + V_BP; // 525

    // 行场计数器
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // 字体数据声明 (8x16 字体)
    reg [127:0] font_data [0:11]; // 0-9数字 和 冒号

    // 初始化8x16字体数据
    initial begin
        // 每个字符16行, 每行8位 (1 byte), 共16 bytes = 128 bits
        // 使用下划线 '_' 提高可读性
        font_data[0] = 128'h00_00_3E_7F_C3_C3_C3_C3_C3_C3_C3_C3_7F_3E_00_00; // '0'
        font_data[1] = 128'h00_00_08_18_38_08_08_08_08_08_08_08_08_3C_00_00; // '1'
        font_data[2] = 128'h00_00_7E_C3_03_06_0C_18_30_60_C0_FF_FF_00_00_00; // '2'
        font_data[3] = 128'h00_00_3E_7F_03_03_06_3C_06_03_03_7F_3E_00_00_00; // '3'
        font_data[4] = 128'h00_00_0C_1C_3C_6C_CC_FF_FF_0C_0C_0C_1E_00_00_00; // '4'
        font_data[5] = 128'h00_00_FF_FF_C0_C0_C0_FE_03_03_03_C3_7E_00_00_00; // '5'
        font_data[6] = 128'h00_00_3E_7F_C3_C0_C0_FE_C3_C3_C3_7F_3E_00_00_00; // '6'
        font_data[7] = 128'h00_00_FF_FF_03_06_0C_18_30_60_60_60_60_60_00_00; // '7'
        font_data[8] = 128'h00_00_3E_7F_C3_C3_C3_7E_C3_C3_C3_7F_3E_00_00_00; // '8'
        font_data[9] = 128'h00_00_3E_7F_C3_C3_C3_7F_3E_03_03_C3_7F_3E_00_00; // '9'
        font_data[10]= 128'h00_00_00_00_00_36_36_00_00_36_36_00_00_00_00_00; // ':'
    end

    // 像素坐标
    wire [9:0] x_coord = h_cnt - (H_SYNC + H_BP);
    wire [9:0] y_coord = v_cnt - (V_SYNC + V_BP);

    // 有效显示区域判断
    wire h_valid = (h_cnt >= (H_SYNC + H_BP)) && (h_cnt < H_TOTAL-H_FP);
    wire v_valid = (v_cnt >= (V_SYNC + V_BP)) && (v_cnt < V_TOTAL-V_FP);
    wire display_area = h_valid && v_valid;

    // 字符像素生成函数
    function  [3:0] char_pattern;
        input [3:0] digit;      // 要显示的数字 (0-11)
        input [3:0] x_pos;      // 字符内的x坐标 (0-7)
        input [4:0] y_pos;      // 字符内的y坐标 (0-15)
        reg [7:0] char_row_data;
        begin
            // 从128位数据中提取对应行的8位像素数据
            // y_pos=0是顶行, font_data最高位对应的是顶行
            char_row_data = font_data[digit] >> ((15 - y_pos) * 8);

            // 检查特定像素位置是否为1
            if ((char_row_data >> (7 - x_pos)) & 1'b1) begin
                char_pattern = 4'hF; // 白色像素
            end else begin
                char_pattern = 4'h0; // 黑色像素
            end
        end
    endfunction

    // 时序逻辑: 时间更新, 同步信号生成
    always @(posedge clk_in, negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0;
            v_cnt <= 0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            // 水平计数器
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                // 垂直计数器
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 0;
                end else begin
                    v_cnt <= v_cnt + 1;
                end
            end else begin
                h_cnt <= h_cnt + 1;
            end            
            // 生成同步信号 (标准为负脉冲)
            hsync <= h_cnt < H_SYNC;
            vsync <= v_cnt < V_SYNC;
        end
    end

    // 组合逻辑: 像素颜色生成
    reg [3:0] sec_lsb, sec_msb;
    reg [3:0] min_lsb, min_msb;
    reg [3:0] hour_lsb, hour_msb;
    // --- 在此定义数字时钟的显示位置和大小 ---
    localparam START_X = 280; // 时钟左下角X坐标
    localparam START_Y = 232; // 时钟左下角Y坐标
    localparam CHAR_WIDTH = 8;   // 字符宽度
    localparam CHAR_HEIGHT = 16; // 字符高度
    localparam CHAR_SPACING = 2; // 字符间距

    // 定义每个字符的水平起始位置
    localparam H1_X = START_X;
    localparam H0_X = H1_X + CHAR_WIDTH + CHAR_SPACING;
    localparam C1_X = H0_X + CHAR_WIDTH + CHAR_SPACING;
    localparam M1_X = C1_X + CHAR_WIDTH + CHAR_SPACING;
    localparam M0_X = M1_X + CHAR_WIDTH + CHAR_SPACING;
    localparam C2_X = M0_X + CHAR_WIDTH + CHAR_SPACING;
    localparam S1_X = C2_X + CHAR_WIDTH + CHAR_SPACING;
    localparam S0_X = S1_X + CHAR_WIDTH + CHAR_SPACING;
    always @(*) begin
        if (display_area) begin
            // 计算时间数字
            sec_lsb = display_data[3:0];
            sec_msb = display_data[7:4];
            min_lsb =  display_data[11:8];
            min_msb =display_data[15:12];
            hour_lsb =display_data[19:16];
            hour_msb = display_data[23:20];
            // 默认背景为黑色
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
            // 检查当前像素是否在某个字符的显示区域内
            if (y_coord >= START_Y && y_coord < START_Y + CHAR_HEIGHT) begin
                if (x_coord >= H1_X && x_coord < H1_X + CHAR_WIDTH) begin // 小时十位
                    vga_r = char_pattern(hour_msb, x_coord - H1_X, y_coord - START_Y);
                end else if (x_coord >= H0_X && x_coord < H0_X + CHAR_WIDTH) begin // 小时个位
                    vga_r = char_pattern(hour_lsb, x_coord - H0_X, y_coord - START_Y);
                end else if (x_coord >= C1_X && x_coord < C1_X + CHAR_WIDTH) begin // 第一个冒号
                    vga_r = char_pattern(10, x_coord - C1_X, y_coord - START_Y);
                end else if (x_coord >= M1_X && x_coord < M1_X + CHAR_WIDTH) begin // 分钟十位
                    vga_r = char_pattern(min_msb, x_coord - M1_X, y_coord - START_Y);
                end else if (x_coord >= M0_X && x_coord < M0_X + CHAR_WIDTH) begin // 分钟个位
                    vga_r = char_pattern(min_lsb, x_coord - M0_X, y_coord - START_Y);
                end else if (x_coord >= C2_X && x_coord < C2_X + CHAR_WIDTH) begin // 第二个冒号
                    vga_r = char_pattern(10, x_coord - C2_X, y_coord - START_Y);
                end else if (x_coord >= S1_X && x_coord < S1_X + CHAR_WIDTH) begin // 秒十位
                    vga_r = char_pattern(sec_msb, x_coord - S1_X, y_coord - START_Y);
                end else if (x_coord >= S0_X && x_coord < S0_X + CHAR_WIDTH) begin // 秒个位
                    vga_r = char_pattern(sec_lsb, x_coord - S0_X, y_coord - START_Y);
                end
                
                // 将R通道的颜色赋给G和B, 产生白色字体
                vga_g = vga_r;
                vga_b = vga_r;
            end
            
        end else begin
            // 非显示区域输出黑色
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end

endmodule
