`timescale 1ns / 1ps

module seven_segment_controller_tb;

    // Parameters
    localparam CLK_PERIOD = 20; // 50 MHz clock

    // Testbench signals
    reg clk;
    reg rst_n;
    reg we;
    reg [31:0] addr;
    reg [31:0] wdata;
    
    reg btn_left, btn_right, btn_up, btn_down, btn_commit;
    
    wire [31:0] rdata;
    wire [7:0] seg_out;
    wire [7:0] digit_out;

    // Instantiate the Device Under Test (DUT)
    seven_segment_controller DUT (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .addr(addr),
        .wdata(wdata),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_commit(btn_commit),
        .rdata(rdata),
        .seg_out(seg_out),
        .digit_out(digit_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // 1. Initial Reset
        $display("Initial Reset");
        rst_n = 0;
        we = 0;
        addr = 0;
        wdata = 0;
        btn_left = 0; btn_right = 0; btn_up = 0; btn_down = 0; btn_commit = 0;
        #(2 * CLK_PERIOD);
        rst_n = 1;
        #(2 * CLK_PERIOD);

        // 2. CPU writes initial hex data 0x12345678
        $display("Writing initial hex data 0x12345678");
        we = 1;
        addr = 32'h80000004;
        wdata = 32'h12345678;
        #(CLK_PERIOD);
        we = 0;
        #(10 * CLK_PERIOD); // Wait for a few cycles
        $display("rdata = %h", rdata); // Should be 0 since no read operation

        // 3. CPU reads back the written data to verify
        $display("Reading back data from 0x80000004");
        we = 0;
        addr = 32'h80000004;
        #(CLK_PERIOD);
        $display("Data read: 0x%h. Expected: 0x12345678", rdata);
        #(CLK_PERIOD);

        // 4. CPU switches to edit mode
        $display("Switching to edit mode (0x80000000 with wdata=2'b10)");
        we = 1;
        addr = 32'h80000000;
        wdata = 2'b10;
        #(CLK_PERIOD);
        we = 0;
        #(10 * CLK_PERIOD);
        $display("Display mode is now in Edit Mode");

        // 5. Simulate a button press (up) with debounce
        $display("Simulating 'btn_up' button press with debounce");
        btn_up = 1;
        #(3 * CLK_PERIOD); // Simulate button bounce
        btn_up = 0;
        #(2 * CLK_PERIOD);
        btn_up = 1;
        #(2 * CLK_PERIOD);
        btn_up = 0;
        #(3 * CLK_PERIOD);
        $display("Edit data after btn_up: 0x%h. Expected: 0x12345679", DUT.edit_data_reg);

        // 6. Simulate a button press (left) to change digit selection
        $display("Simulating 'btn_left' button press with debounce");
        btn_left = 1;
        #(3 * CLK_PERIOD); // Simulate button bounce
        btn_left = 0;
        #(2 * CLK_PERIOD);
        btn_left = 1;
        #(2 * CLK_PERIOD);
        btn_left = 0;
        #(3 * CLK_PERIOD);
        $display("Edit digit selected: %d. Expected: 0", DUT.edit_digit_sel_reg);

        // 7. Simulate another button press (up) to change the new digit
        $display("Simulating another 'btn_up' on the new digit");
        btn_up = 1;
        #(3 * CLK_PERIOD);
        btn_up = 0;
        #(3 * CLK_PERIOD);
        $display("Edit data after second btn_up: 0x%h. Expected: 0x12345679", DUT.edit_data_reg);

        // 8. Simulate a commit button press to exit edit mode and save
        $display("Simulating 'btn_commit' to save data");
        btn_commit = 1;
        #(3 * CLK_PERIOD);
        btn_commit = 0;
        #(3 * CLK_PERIOD);
        $display("Display mode should be Hex mode. Read back display_mode_reg: %b", DUT.display_mode_reg);

        // 9. CPU reads back the new hex data to verify
        $display("Reading back hex data from 0x80000004");
        we = 0;
        addr = 32'h80000004;
        #(CLK_PERIOD);
        $display("Data read: 0x%h. Expected: 0x12345679", rdata);

        // 10. Finish simulation
        $display("Simulation finished.");
    end
endmodule
