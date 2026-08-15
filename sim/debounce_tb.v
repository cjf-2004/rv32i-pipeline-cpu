// Testbench for the debounce module
// It simulates various button press scenarios, including a clean press and a noisy,
// bouncing input, to verify the module's functionality.
`timescale 1ns / 1ps

module debounce_tb;

    // --- DUT (Device Under Test) Signals ---
    reg clk;
    reg rst_n;
    reg btn_in;
    wire posedge_out;

    // --- Clock generation (25MHz) ---
    // Clock period is 40ns (1 / 25e6 = 40ns)
    localparam CLK_PERIOD = 40;
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end

    // --- DUT Instantiation ---
    debounce #(.CLOCK_FREQUENCY_HZ(25_000_000), .DEBOUNCE_DELAY_MS(20)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .btn_in(btn_in),
        .posedge_out(posedge_out)
    );

    // --- Test Scenarios ---
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        btn_in = 1'b0;

        // Apply reset
        #100;
        rst_n = 1'b1;
        $display("Simulation started. Applying reset...");

        // --- Scenario 1: Normal button press ---
        $display("--- Test 1: Normal button press ---");
        // Wait for a few clock cycles
        #100;
        
        // Press the button cleanly
        btn_in = 1'b1;
        
        // Wait for a period longer than the debounce time (e.g., 25ms)
        #25_000_000;
        
        // Release the button
        btn_in = 1'b0;
        $display("Normal button released.");
        #100;


        // --- Scenario 2: Button with noise/bouncing ---
        $display("--- Test 2: Bouncing button input ---");
        // Wait for a few clock cycles
        #100;

        // Simulate a bouncing button press
        btn_in = 1'b1; // Press
        #1_000_000;
        btn_in = 1'b0; // Bounce down
        #1_000_000;
        btn_in = 1'b1; // Bounce up
        #1_000_000;
        btn_in = 1'b0; // Bounce down
        #1_000_000;
        
        // Now, a stable press for a long period
        btn_in = 1'b1;
        #25_000_000; // Wait long enough for debounce to pass
        
        // Release the button
        btn_in = 1'b0;
        $display("Bouncing button released.");

        // --- Finish Simulation ---
        #100;
        $display("Simulation finished.");
        $finish;
    end
endmodule
