`timescale 1ns / 1ps

//----------------------------------------------------------------------------------
// Module Name: clk_divider
// Description:
// This module divides the input clock frequency by 4 with a 50% duty cycle.
// It uses two cascaded D-type flip-flops to ensure stability.
//----------------------------------------------------------------------------------

module clk_divider_1_4(
    input clk_in,   // Input clock from system
    input rst_n,    // Asynchronous active-low reset
    output clk_out  // Output clock, clk_in / 4
);

// Internal registers for two stages of division
reg clk_div2_reg;
reg clk_div4_reg;

// First stage: Divide by 2
// Flips on the positive edge of clk_in
always @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
        clk_div2_reg <= 1'b0;
    end
    else begin
        clk_div2_reg <= ~clk_div2_reg;
    end
end

// Second stage: Divide by 2
// Flips on the positive edge of the divided clock from the first stage
always @(posedge clk_div2_reg or negedge rst_n) begin
    if (!rst_n) begin
        clk_div4_reg <= 1'b0;
    end
    else begin
        clk_div4_reg <= ~clk_div4_reg;
    end
end

// Assign the final divided clock to the output
assign clk_out = clk_div4_reg;

endmodule
