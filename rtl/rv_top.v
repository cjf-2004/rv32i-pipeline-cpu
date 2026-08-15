`timescale 1ns / 1ps
`include "macro.vh"

module rv_top(
    input clk,
    input rst_n,
    // LED_0 for debug
    output LED_0,
    // External buttons for editing
    input wire btn_left,
    input wire btn_right,
    input wire btn_up,
    input wire btn_down,
    input wire btn_commit,
    // 7-segment display Group 1 outputs (A0-G0, DP0, DN0_K1-K4)
    output wire A0, B0, C0, D0, E0, F0, G0, DP0,
    output wire DN0_K1, DN0_K2, DN0_K3, DN0_K4,
    // 7-segment display Group 2 outputs (A1-G1, DP1, DN1_K1-K4)
    output wire A1, B1, C1, D1, E1, F1, G1, DP1,
    output wire DN1_K1, DN1_K2, DN1_K3, DN1_K4,
    output wire [3:0] vga_r, 
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire hsync, vsync
    );

    // Bus routing logic
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire dmem_we;
    wire [31:0] dmem_rdata;

    // Read data signals for memory and peripherals
    wire [31:0] unified_mem_rdata;
    wire [31:0] peripheral_rdata; // Unified read data for all peripherals

    // Write enable signals for memory and peripherals
    wire unified_mem_we;
    wire seven_segment_we;
    
    // Internal wires for 7-segment controller
    wire [7:0] seg_out;
    wire [7:0] digit_out;
    
    // Divided clock signals
    wire cpu_clk;
    assign LED_0 = rst_n;
    
    //ÖÐ¶ÏÐÅºÅ
    wire [31:0] interrupt_req;
    
    // Instantiate a clock divider for the CPU clock
    clk_divider_1_4 clk_divider_cpu (
        .clk_in(clk),
        .rst_n(rst_n),
        .clk_out(cpu_clk)
    );

    // Instantiate RISC-V CPU core
    CPU rv_cpu (
        .clk(cpu_clk), // Use the divided clock
        .rst_n(rst_n),
        // Instruction bus
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        // Data bus
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we_out(dmem_we),
        .dmem_rdata(dmem_rdata),
        .interrupt_req ({31'd0,1'd0})
    );

    // Instantiate memory and peripherals
    unified_mem unified_mem_inst (
        .clk(cpu_clk), // Memory still uses the high-speed system clock for faster access
        // Instruction bus
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        // Data bus
        .we(unified_mem_we),
        .dmem_addr(dmem_addr),
        .wdata(dmem_wdata),
        .rdata(unified_mem_rdata)
    );
    
    // Instantiate 7-segment controller with all necessary ports
    seven_segment_controller_0 seven_segment_controller_inst(
        .clk(cpu_clk),
        .rst_n(rst_n),
        .we(seven_segment_we),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        // Connect the physical button inputs
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_commit(btn_commit),
        .rdata(peripheral_rdata),
        .countdown_over(interrupt_req[0]),
        .seg_out(seg_out),
        .digit_out(digit_out),
        .vga_r(vga_r), // Red color output (4 bits)
        .vga_g(vga_g), // Green color output (4 bits)
        .vga_b(vga_b), // Blue color output (4 bits)
        .hsync(hsync),     // Horizontal sync pulse
        .vsync(vsync)      // Vertical sync pulse
    );
//    ila_0 ila_0_inst(
//        .clk(clk),
//        .probe0(seven_segment_controller_inst.display_mode_reg),
//        .probe1(cpu_clk),
//        .probe2(rv_cpu.instr_addr),
//        .probe3(imem_data),
//        .probe4(seven_segment_controller_inst.commit_flag),
//        .probe5(peripheral_rdata),
//        .probe6(seven_segment_controller_inst.we),
//        .probe7(seven_segment_controller_inst.wdata),
//        .probe8(seven_segment_controller_inst.timer_data_reg),
//        .probe9(rv_cpu.masked_interrupt[0]),
//        .probe10(rv_cpu.now_interrupt),
//        .probe11(rst_n),
//        .probe12(rv_cpu.reg_file_inst.registers[31]),
//        .probe13(rv_cpu.mem_wb_pc_reg)
//    );
//    ila_1 ila_1_inst(
//        .clk(clk),
//        .probe0(seven_segment_controller_inst.vga_display_inst.display_data),
//        .probe1(vga_r),
//        .probe2(vga_b),
//        .probe3(vga_g),
//        .probe4(hsync),
//        .probe5(vsync),
//        .probe6(seven_segment_controller_inst.vga_display_inst.h_cnt),
//        .probe7(seven_segment_controller_inst.vga_display_inst.v_cnt)
//    );
    // Address bus arbitration
    assign unified_mem_we = dmem_we & (dmem_addr >= `DATA_VADDR_START && dmem_addr < `IO_VADDR_START);
    
    // Assign a single write enable signal for the 7-segment controller
    assign seven_segment_we = dmem_we & (dmem_addr >= `IO_VADDR_START && dmem_addr < `IO_VADDR_END);
    
    // Read data signal selection
    assign dmem_rdata = (dmem_addr >= `IO_VADDR_START && dmem_addr < `IO_VADDR_END) ? peripheral_rdata :
                        unified_mem_rdata;
    
    // Connect 7-segment controller outputs to physical pins
    // All segments are shared between the two 4-digit modules
    assign {DP0, G0, F0, E0, D0, C0, B0, A0} = seg_out;
    assign {DP1, G1, F1, E1, D1, C1, B1, A1} = seg_out;

    // Connect digit enables to physical pins
    // Digit 0-3 (rightmost) map to DN0_K1-K4
    assign DN0_K1 = digit_out[0];
    assign DN0_K2 = digit_out[1];
    assign DN0_K3 = digit_out[2];
    assign DN0_K4 = digit_out[3];
    // Digit 4-7 (leftmost) map to DN1_K1-K4
    assign DN1_K1 = digit_out[4];
    assign DN1_K2 = digit_out[5];
    assign DN1_K3 = digit_out[6];
    assign DN1_K4 = digit_out[7];

endmodule
