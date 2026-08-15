// Testbench for the vga_display module
// It generates a 25MHz clock and a simple time counter to drive the display data.
`timescale 1ns / 1ps

module vga_display_tb;

    // --- Signals to connect to the DUT (Device Under Test) ---
    reg  clk_in;
    reg  rst_n;
    reg  [23:0] display_data;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire hsync;
    wire vsync;

    // --- Clock generation (25MHz) ---
    // Clock period is 40ns (1 / 25e6 = 40ns)
    localparam CLK_PERIOD = 40;
    always begin
        clk_in = 1'b0;
        #(CLK_PERIOD / 2);
        clk_in = 1'b1;
        #(CLK_PERIOD / 2);
    end

    // --- DUT Instantiation ---
    vga_display DUT (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .display_data(display_data),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync(hsync),
        .vsync(vsync)
    );

    // --- Test stimulus and time counter ---
    // This part simulates an external clock source that sends BCD time data
    reg [24:0] s_cnt;
    reg [5:0]  seconds_reg, minutes_reg, hours_reg;

    initial begin
        // Initialize signals
        rst_n = 1'b1;
        s_cnt = 0;
        seconds_reg = 0;
        minutes_reg = 0;
        hours_reg = 0;
        display_data = 24'h000000;

        // Apply reset
        #100;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        // Display a message at the start of the simulation
        $display("Starting simulation...");
        $display("----------------------------------------");
    end

    // --- One second tick generator ---
    // A 25MHz clock means 25,000,000 cycles per second
    always @(posedge clk_in) begin
        if (s_cnt == 25000000 - 1) begin
            s_cnt <= 0;
        end else begin
            s_cnt <= s_cnt + 1;
        end
    end

    // --- Time counter logic ---
    // Update time registers every one second
    always @(posedge clk_in) begin
        if (s_cnt == 25000000 - 1) begin
            if (seconds_reg == 59) begin
                seconds_reg <= 0;
                if (minutes_reg == 59) begin
                    minutes_reg <= 0;
                    if (hours_reg == 23) begin
                        hours_reg <= 0;
                    end else begin
                        hours_reg <= hours_reg + 1;
                    end
                end else begin
                    minutes_reg <= minutes_reg + 1;
                end
            end else begin
                seconds_reg <= seconds_reg + 1;
            end
        end
    end

    // --- Update display_data in BCD format ---
    // This is the data that will be fed into the vga_display module
    always @(*) begin
        display_data = {
            (hours_reg / 10), (hours_reg % 10),
            (minutes_reg / 10), (minutes_reg % 10),
            (seconds_reg / 10), (seconds_reg % 10)
        };
    end
    
    // --- Monitoring (optional) ---
    // Use this to display the time in the simulation console
    always @(posedge clk_in) begin
        if (s_cnt == 25000000 - 1) begin
            $display("Time: %d:%d:%d", hours_reg, minutes_reg, seconds_reg);
        end
    end

    // End simulation after 2 minutes (120 seconds)
    initial begin
        # (120 * CLK_PERIOD * 25000000);
        $display("----------------------------------------");
        $display("Simulation finished.");
        $finish;
    end
endmodule
