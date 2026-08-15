`timescale 1ns / 1ps

module seven_segment_controller (
    input wire clk,
    input wire rst_n,
    // Unified bus interface
    input wire we,          // Write enable
    input wire [31:0] addr, // Address for memory-mapped registers
    input wire [31:0] wdata, // Write data
    
    // External buttons for editing
    input wire btn_left,
    input wire btn_right,
    input wire btn_up,
    input wire btn_down,
    input wire btn_commit,

    // CPU read data bus
    output reg [31:0] rdata,
    //中断信号输出
    output reg countdown_over,
    // 7-segment display outputs
    output wire [7:0] seg_out,
    output wire [7:0] digit_out,
    output wire [3:0] vga_r, // Red color output (4 bits)
    output wire [3:0] vga_g, // Green color output (4 bits)
    output wire [3:0] vga_b, // Blue color output (4 bits)
    output wire hsync,     // Horizontal sync pulse
    output wire vsync      // Vertical sync pulse
);

// Define parameters
parameter DIGITS = 8;
parameter SEC_DELAY = 25000000;
parameter SCAN_DELAY = 25000;
parameter BLINK_DELAY = 1000000; // Blink every ~40ms (25MHz clk)
parameter BTN_DEBOUNCE = 15;
// Internal registers
reg [31:0] hex_data_reg;         // Register for hex display data
reg [23:0] timer_data_reg;       // Register for timer countdown data
reg [31:0] edit_data_reg;        // Register for data being edited in hex mode
reg [1:0] display_mode_reg;      // 00: hex, 01: timer, 10: hex edit
reg [1:0] read_mode_reg;          // 00: hex, 01: timer, 10: hex edit
reg commit_flag; 
// Counters
reg [31:0] sec_counter_reg;
reg [31:0] scan_counter_reg;
reg [31:0] blink_counter_reg;

// Button logic and cursor
reg [2:0] edit_digit_sel_reg;    // Tracks the selected digit for editing (0-7)

// Seven-segment segment codes (common-cathode)
reg [7:0] seg_code [0:16];

vga_display vga_display_inst(
    .clk_in(clk),    // 25 MHz clock
    .rst_n(rst_n),     // Active-low reset
    .display_data(timer_data_reg), //显示的时分秒
    .vga_r(vga_r), // Red color output (4 bits)
    .vga_g(vga_g), // Green color output (4 bits)
    .vga_b(vga_b), // Blue color output (4 bits)
    .hsync(hsync),     // Horizontal sync pulse
    .vsync(vsync)      // Vertical sync pulse
);
initial begin
    seg_code[0] = 8'b00111111; // 0
    seg_code[1] = 8'b00000110; // 1
    seg_code[2] = 8'b01011011; // 2
    seg_code[3] = 8'b01001111; // 3
    seg_code[4] = 8'b01100110; // 4
    seg_code[5] = 8'b01101101; // 5
    seg_code[6] = 8'b01111101; // 6
    seg_code[7] = 8'b00000111; // 7
    seg_code[8] = 8'b01111111; // 8
    seg_code[9] = 8'b01101111; // 9
    seg_code[10] = 8'b01110111; // A
    seg_code[11] = 8'b01111100; // B
    seg_code[12] = 8'b00111001; // C
    seg_code[13] = 8'b01011110; // D
    seg_code[14] = 8'b01111001; // E
    seg_code[15] = 8'b01110001; // F
    seg_code[16] = 8'b01000000; // Colon (not used in this hex mode, but kept)
end

// FSM for display scanning and blink counter
// 该块负责七段数码管的动态扫描和闪烁效果。
reg [7:0] digit_sel_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scan_counter_reg <= 0;
        blink_counter_reg <= 0;
        digit_sel_reg <= 8'b00000001;
    end else begin
        // Scan counter for multiplexing
        scan_counter_reg <= scan_counter_reg + 1;
        if (scan_counter_reg == SCAN_DELAY) begin
            scan_counter_reg <= 0;
            digit_sel_reg <= {digit_sel_reg[0], digit_sel_reg[7:1]};
        end
        // Blink counter for flashing effect
        blink_counter_reg <= blink_counter_reg + 1;
    end
end

// Sequential logic for data updates and mode control
// 该块处理总线接口、按钮输入和所有寄存器更新。
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hex_data_reg <= 32'h0;
        timer_data_reg <= 24'h0;
        edit_data_reg <= 32'h0;
        display_mode_reg <= 2'b00; // Default to hex mode
        edit_digit_sel_reg <= 0;
        commit_flag <= 0;
        countdown_over <= 1;
        sec_counter_reg <= 32'd0;
    end else begin
        // --- Bus Interface Logic ---
        if (we) begin
            case (addr)
                32'h80000000: begin // Control register
                    // If switching to edit mode, sync the edit data with hex data
                    if (wdata[1:0] == 2'b10) begin
                        edit_data_reg <= hex_data_reg;
                    end else if(wdata[1:0]==2'b01)begin
                        countdown_over <= 1'b0;
                    end
                    commit_flag <= 1'b0;
                    display_mode_reg <= wdata[1:0];
                    read_mode_reg <= wdata[5:4];
                end
                32'h80000004: begin // Data register
                    case(display_mode_reg)
                        2'b00 : hex_data_reg <= wdata;
                        2'b01 : timer_data_reg <= wdata[23:0];
                        2'b10 : edit_data_reg <= wdata;
                    endcase
                end
            endcase
        end
        // Commit logic for button press
        if (btn_commit) begin
            commit_flag <= 1'b1;
        end
        // --- Edit Mode Logic ---
        if (display_mode_reg == 2'b10) begin
            if (btn_left) begin
                edit_digit_sel_reg <= (edit_digit_sel_reg == 3'd0) ? 3'd7 : edit_digit_sel_reg - 1;
            end else if (btn_right) begin
                edit_digit_sel_reg <= (edit_digit_sel_reg == 3'd7) ? 3'd0 : edit_digit_sel_reg + 1;
            end

            if (btn_up) begin
                edit_data_reg[4 * edit_digit_sel_reg +: 4] <= (edit_data_reg[4 * edit_digit_sel_reg +: 4] == 4'hF) ? 4'h0 : edit_data_reg[4 * edit_digit_sel_reg +: 4] + 4'h1;
            end else if (btn_down) begin
                edit_data_reg[4 * edit_digit_sel_reg +: 4] <= (edit_data_reg[4 * edit_digit_sel_reg +: 4] == 4'h0) ? 4'hF : edit_data_reg[4 * edit_digit_sel_reg +: 4] - 4'h1;
            end
        end

        // --- Timer Decrement Logic ---
            sec_counter_reg <= sec_counter_reg + 1;
            if (sec_counter_reg == SEC_DELAY) begin
                sec_counter_reg <= 0;
            // Ten-based decrement logic for HH:MM:SS
                if (timer_data_reg == 24'h000000) begin
                    countdown_over <= 1'b1;
                end else begin
                    if (timer_data_reg[3:0] > 4'h0) begin
                        timer_data_reg[3:0] <= timer_data_reg[3:0] - 4'h1;
                    end else begin
                        timer_data_reg[3:0] <= 4'h9;
                        if (timer_data_reg[7:4] > 4'h0) begin
                            timer_data_reg[7:4] <= timer_data_reg[7:4] - 4'h1;
                        end else begin
                            timer_data_reg[7:4] <= 4'h5;
                            if (timer_data_reg[11:8] > 4'h0) begin
                                timer_data_reg[11:8] <= timer_data_reg[11:8] - 4'h1;
                            end else begin
                                timer_data_reg[11:8] <= 4'h9;
                                if (timer_data_reg[15:12] > 4'h0) begin
                                    timer_data_reg[15:12] <= timer_data_reg[15:12] - 4'h1;
                                end else begin
                                    timer_data_reg[15:12] <= 4'h5;
                                    if (timer_data_reg[19:16] > 4'h0) begin
                                        timer_data_reg[19:16] <= timer_data_reg[19:16] - 4'h1;
                                    end else begin
                                        timer_data_reg[19:16] <= 4'h9;
                                        if (timer_data_reg[23:20] > 4'h0) begin
                                            timer_data_reg[23:20] <= timer_data_reg[23:20] - 4'h1;
                                        end else begin
                                            timer_data_reg[23:20] <= 24'h0;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
       
        end
    end

// Read data logic
always @(*) begin
    case(addr)
        // Read status and control. Bit 2: commit_flag, Bits 1:0: display_mode
        32'h80000000: rdata = {26'b0,read_mode_reg,countdown_over,commit_flag,display_mode_reg};
        32'h80000004: rdata =   read_mode_reg == 2'b00 ? hex_data_reg :
                                read_mode_reg == 2'b01 ? {10'b0, timer_data_reg}:
                                read_mode_reg == 2'b10 ? edit_data_reg:
                              32'b0;
        default: rdata = 0;
    endcase
end

// Combinational logic for display
reg [4:0] seg_data;
wire [2:0] current_digit_idx;

// Determine current digit index based on scanner
assign current_digit_idx = (digit_sel_reg[0] == 1) ? 3'd0 :
                           (digit_sel_reg[1] == 1) ? 3'd1 :
                           (digit_sel_reg[2] == 1) ? 3'd2 :
                           (digit_sel_reg[3] == 1) ? 3'd3 :
                           (digit_sel_reg[4] == 1) ? 3'd4 :
                           (digit_sel_reg[5] == 1) ? 3'd5 :
                           (digit_sel_reg[6] == 1) ? 3'd6 :
                           (digit_sel_reg[7] == 1) ? 3'd7 : 3'd0;

// Select the correct 4-bit data based on display mode
always @(*) begin
    if(display_mode_reg == 2'b00)begin
        seg_data = {1'b0, hex_data_reg[4 * current_digit_idx +: 4]};
    end else if(display_mode_reg == 2'b10) begin
        seg_data = {1'b0, edit_data_reg[4 * current_digit_idx +: 4]};
    end else if(display_mode_reg == 2'b01) begin
        if(current_digit_idx == 0 || current_digit_idx == 1) begin
            seg_data = {1'b0,timer_data_reg[4 * current_digit_idx +: 4]};
        end else if(current_digit_idx == 3 || current_digit_idx == 4) begin
            seg_data = {1'b0,timer_data_reg[4 * (current_digit_idx - 1) +: 4]};
        end else if(current_digit_idx == 6 || current_digit_idx == 7) begin
            seg_data = {1'b0,timer_data_reg[4 * (current_digit_idx - 2) +: 4]};
        end else begin
            seg_data = 5'd16;
        end
    end else begin
        seg_data = 5'h0;
    end
//    seg_data = 
//    (display_mode_reg == 2'b00) ? hex_data_reg[4 * current_digit_idx +: 4] :
//    (display_mode_reg == 2'b01) ? timer_data_reg[4 * current_digit_idx +: 4] :
//    (display_mode_reg == 2'b10) ? edit_data_reg[4 * current_digit_idx +: 4] : 4'h0;
end
// Assign segment output, with flashing effect in edit mode
assign seg_out = (display_mode_reg == 2'b10 && current_digit_idx == edit_digit_sel_reg && blink_counter_reg[24] == 1) ? 8'h00 : seg_code[seg_data];
assign digit_out = digit_sel_reg;
endmodule
