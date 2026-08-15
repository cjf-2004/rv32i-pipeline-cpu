`timescale 1ns / 1ps
`include "macro.vh"
//////////////////////////////////////////////////////////////////////////////////
// 5-stage Pipelined CPU (IF, ID, EX, MEM, WB)
//////////////////////////////////////////////////////////////////////////////////


module CPU (
    input clk,
    input rst_n,
    // 指令总线接口 (Instruction Bus Interface)
    output wire [31:0] imem_addr,
    input wire [31:0] imem_data,
    
     // 数据总线接口 (Data Bus Interface)
    output wire [31:0] dmem_addr,
    output wire dmem_we_out,
    output wire [31:0] dmem_wdata,
    input wire [31:0] dmem_rdata,
    
     // 新增的中断输入
    input wire [31:0] interrupt_req   // 外部中断请求信号
    
);
    //现在代码段中断优先级
    reg [4:0] now_interrupt;
    //中断屏蔽码
    reg [31:0] interrupt_mask [0:31];
    //屏蔽后的中断信号
    reg [31:0] masked_interrupt;
    integer i;
    initial begin
      interrupt_mask[0]= 32'hFFFF_FFFF;
      for (i = 1; i < 32; i = i + 1) begin
        interrupt_mask[i] = 32'h0;
      end
    end
    always @(*) begin
        masked_interrupt = interrupt_mask[now_interrupt] & interrupt_req;
    end
    // ========================
    // IF/ID 流水线寄存器
    // ========================
    reg [31:0] if_id_pc_plus_4_reg;
    reg [31:0] if_id_instr_reg;
    reg [31:0] if_id_pc_reg;
    // ========================
    // ID/EX 流水线寄存器
    // ========================
    reg [31:0] id_ex_rd1_reg;
    reg [31:0] id_ex_rd2_reg;
    
    reg [4:0] id_ex_ra1_reg;
    reg [4:0] id_ex_ra2_reg;
    
    reg id_ex_dmem_we_reg;
    reg [3:0] id_ex_alu_op_reg;
    reg id_ex_alu_cA_reg;
    reg id_ex_alu_cB_reg;
    reg [1:0] id_ex_cWB_reg;
    reg [3:0] id_ex_branch_reg;
    reg id_ex_reg_we_reg;
    reg [4:0] id_ex_wa_reg;
    
    reg [31:0] id_ex_pc_reg;
    reg [31:0] id_ex_pc_plus_4_reg;
    reg [31:0] id_ex_immediate_reg;
    // ========================
    // EX/MEM 流水线寄存器
    // ========================
    reg ex_mem_dmem_we_reg;
    reg [1:0] ex_mem_cWB_reg;
    reg [3:0] ex_mem_branch_reg;
    reg ex_mem_reg_we_reg;
    reg [4:0] ex_mem_wa_reg;
    reg [31:0] ex_mem_rd2_reg;
    reg [31:0] ex_mem_alu_result_reg;
    
    reg ex_mem_zero_flag_reg;
    reg ex_mem_lt_flag_reg;
    
    reg [31:0] ex_mem_immediate_reg;
    reg [31:0] ex_mem_pc_reg;
    reg [31:0] ex_mem_pc_plus_4_reg;
    reg [31:0] ex_mem_branch_addr_reg;
   

    // ========================
    // MEM/WB 流水线寄存器
    // ========================
    reg [31:0] mem_wb_rdata_reg;
    reg [1:0] mem_wb_cWB_reg;
    reg mem_wb_reg_we_reg;
    reg [4:0] mem_wb_wa_reg;
    reg [31:0] mem_wb_alu_result_reg;
    reg [31:0] mem_wb_immediate_reg;
    reg [31:0] mem_wb_pc_reg;
    reg [31:0] mem_wb_pc_plus_4_reg;
    
    // IF 阶段信号
    reg [31:0] instr_addr;
    assign imem_addr = instr_addr;
    wire [31:0] next_instr_addr;
    wire [31:0] instr_data = imem_data;
    wire [31:0] pc_plus_4;
    // ID 阶段信号
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] ra1;
    wire [4:0] ra2;
    wire [4:0] wa;
    wire [31:0] rd1, rd2;
    wire [31:0] immediate;
    
    wire [31:0] mux_rd1, mux_rd2;

    // 控制单元信号 (从 ID/EX 寄存器读取)
    wire alu_cA;
    wire alu_cB;
    wire [1:0] cWB;
    wire [3:0] alu_op;
    wire [3:0] branch;
    wire dmem_we;
    wire reg_we;
   // ALU 操作数
    wire [31:0] ALU_A;
    wire [31:0] ALU_B;
    //EX阶段信号
    wire [31:0] branch_addr;
    
    // IE阶段信号
    wire [31:0] alu_result;
    wire zero_flag;
    wire lt_flag;
    
    //MEM阶段信号
    wire [31:0] rdata = dmem_rdata;
    wire [1:0] branch_taken;
    //用于判断分支是否成功的信号，从EX/MEM寄存器中读取
    wire is_branch = ex_mem_branch_reg != 4'b0; 
    wire branch_success = is_branch && (branch_taken!=2'b00);
    
    //WB阶段信号
    wire [31:0]  cWB_se; 
    
    //停顿信号
    wire stall;
    //旁路选择信号 for RD1 RD2
    wire [1:0] fw1_sel, fw2_sel;
    
   //数据冒险（在ID阶段进行判断，使用停顿或旁路）
   //停顿逻辑：在EX阶段的指令为lw，且目前ID阶段的指令的源寄存器与lw指令的目的寄存器一致，产生stall停顿信号
    wire id_needs_rs1 = (ra1 != 5'b0);
    wire id_needs_rs2 = (ra2 != 5'b0);
    wire rs1_depend_on_load = (id_ex_cWB_reg == 2'b11) && (id_ex_wa_reg == ra1);
    wire rs2_depend_on_load = (id_ex_cWB_reg == 2'b11) && (id_ex_wa_reg == ra2);
    assign stall = (id_needs_rs1 && rs1_depend_on_load) || (id_needs_rs2 && rs2_depend_on_load);
    
    //旁路逻辑：在ID阶段根据后面三个阶段的reg_we与WA信号来与当前的ra1与ra2来判断RD1与RD2是否需要旁路，离当前ID越近的数据优先级越高
    //各个阶段数据源的选择
    //EX阶段的旁路数据源
    wire [31:0] mux_ex_data = (id_ex_cWB_reg == 2'b00) ? id_ex_immediate_reg :
                               (id_ex_cWB_reg == 2'b01) ? id_ex_pc_plus_4_reg :
                               (id_ex_cWB_reg == 2'b10) ? alu_result :
                               32'b0;//无效数据，当作空
    //MEM阶段的旁路数据源
    wire [31:0] mux_mem_data = (ex_mem_cWB_reg == 2'b00) ? ex_mem_immediate_reg :
                               (ex_mem_cWB_reg == 2'b01) ? ex_mem_pc_plus_4_reg :
                               (ex_mem_cWB_reg == 2'b10) ? ex_mem_alu_result_reg :
                                rdata;//lw读到的数据   
    //WB阶段的旁路数据源cWB_se
      
    //旁路数据选择信号
    // 00: 无旁路，使用寄存器文件数据
    // 01: 旁路自 WB 阶段
    // 10: 旁路自 MEM 阶段
    // 11: 旁路自 EX 阶段
    
    // 旁路优先级: EX > MEM > WB
    assign fw1_sel = (id_ex_reg_we_reg && id_ex_wa_reg != 5'b0 && id_ex_wa_reg == ra1) ? 2'b11 :
                     (ex_mem_reg_we_reg && ex_mem_wa_reg != 5'b0 && ex_mem_wa_reg == ra1) ? 2'b10 :
                     (mem_wb_reg_we_reg && mem_wb_wa_reg != 5'b0 && mem_wb_wa_reg == ra1) ? 2'b01 : 2'b00;
    
    assign fw2_sel = (id_ex_reg_we_reg && id_ex_wa_reg != 5'b0 && id_ex_wa_reg == ra2) ? 2'b11 :
                     (ex_mem_reg_we_reg && ex_mem_wa_reg != 5'b0 && ex_mem_wa_reg == ra2) ? 2'b10 :
                     (mem_wb_reg_we_reg && mem_wb_wa_reg != 5'b0 && mem_wb_wa_reg == ra2) ? 2'b01 : 2'b00;

    // ID 阶段的数据选择器，在进入ID/EX寄存器前完成旁路
    assign mux_rd1 = (fw1_sel == 2'b11) ? mux_ex_data :
                     (fw1_sel == 2'b10) ? mux_mem_data :
                     (fw1_sel == 2'b01) ? cWB_se : rd1;
                     
    assign mux_rd2 = (fw2_sel == 2'b11) ? mux_ex_data :
                     (fw2_sel == 2'b10) ? mux_mem_data :
                     (fw2_sel == 2'b01) ? cWB_se : rd2;
                     
    // ALU 输入数据，现在直接来自ID/EX寄存器
    assign ALU_A = (id_ex_alu_cA_reg) ? id_ex_pc_reg : id_ex_rd1_reg;
    assign ALU_B = (id_ex_alu_cB_reg) ? id_ex_rd2_reg : id_ex_immediate_reg;                
    // dmem
    assign dmem_we_out = (masked_interrupt!=32'h0) ? 1'b0 : ex_mem_dmem_we_reg;
    assign dmem_addr = ex_mem_alu_result_reg;
    assign dmem_wdata = ex_mem_rd2_reg;
    
    //WB阶段通过组合逻辑得到寄存器堆的wa与wd数据
    wire interrupt_we_data = (masked_interrupt != 5'b1) ? mem_wb_reg_we_reg : 1'b1;
    wire [4:0] interrupt_wa_data = (masked_interrupt != 5'b1) ? mem_wb_wa_reg : 5'd31; //中断时将wa设置为X31
    wire [31:0] interrupt_wd_data = (masked_interrupt != 5'b1) ? cWB_se : 
                                    (mem_wb_pc_reg!=32'h0) ? mem_wb_pc_reg :
                                    (ex_mem_pc_reg!=32'h0) ? ex_mem_pc_reg :
                                    (id_ex_pc_reg!=32'h0) ? id_ex_pc_reg :
                                    (if_id_pc_reg!=32'h0) ? if_id_pc_reg : 
                                    (instr_addr != 32'h0) ? instr_addr :
                                     32'h0; //中断时将wd设置为当前WB阶段的PC

    // --- 模块实例化 ---
    // Instruction Memory
//    iMem iMem_inst (
//        .clk(clk),
//        ._addr(instr_addr),
//        .idata(instr_data)
//    );
    
    // Control Unit
    control control_inst (
        .opcode(if_id_instr_reg[6:0]),
        .funct3(if_id_instr_reg[14:12]),
        .funct7(if_id_instr_reg[31:25]),
        .alu_cA(alu_cA),
        .alu_cB(alu_cB),
        .cWB(cWB),
        .alu_op(alu_op),
        .branch(branch),
        .dmem_we(dmem_we),
        .reg_we(reg_we)
    );
    
    // Register File
    register_file reg_file_inst (
        .clk(clk),
        .rst_n(rst_n),
        .we(interrupt_we_data),
        .wa(interrupt_wa_data),
        .wd(interrupt_wd_data),
        .ra1(ra1),
        .ra2(ra2),
        .rd1(rd1),
        .rd2(rd2)
    );
    
    // Immediate Generator
    ImmGen imm_gen_unit (
        .instr(if_id_instr_reg),
        .imm_out(immediate)
    );
    
    // ALU
    ALU_32bit u_ALU_32bit (
        .A(ALU_A),
        .B(ALU_B),
        .ALU_Sel(id_ex_alu_op_reg),
        .Result(alu_result),
        .Zero_Flag(zero_flag),
        .Lt_Flag(lt_flag)
    );
    
//     // Data Memory
//    dMem dMem_inst (
//        .clk(clk),
//        .we(ex_mem_dmem_we_reg),
//        ._addr(ex_mem_alu_result_reg),
//        .wdata(ex_mem_rd2_reg),
//        .rdata(rdata)
//    );
    
    // Branch Unit
    br_unit u_br_unit (
        .branch_type(ex_mem_branch_reg),
        .zero_flag(ex_mem_zero_flag_reg),
        .lt_flag(ex_mem_lt_flag_reg),
        .branch_taken(branch_taken)
    );

    // Writeback Data Mux
    mux3 u_mux3 (
        .imm(mem_wb_immediate_reg),
        .pc_plus_4(mem_wb_pc_plus_4_reg),
        .alu_result(mem_wb_alu_result_reg),
        .dmem_data(mem_wb_rdata_reg),
        .sel(mem_wb_cWB_reg),
        .c3_se(cWB_se)
    );
    
    // ========================
    // 流水线阶段实现
    // ========================

    // IF 阶段: PC 更新和指令读取  0  ->  1
    //                             0040 ->  0000  
                                   // 0     ->  0 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_addr <= `TEXT_VADDR_START;
            now_interrupt <= 5'd0;
        end else begin
            if (masked_interrupt == 32'b1) begin //跳转到中断处理程序
                instr_addr <= `INTERRUPT_VADDR_START_INT1;
                now_interrupt <= 5'd1;
            end else begin
                if(instr_addr < `TEXT_VADDR_START && instr_addr >= `INTERRUPT_VADDR_START_INT1) begin
                    now_interrupt <= 5'd1;
                end else if(instr_addr >= `TEXT_VADDR_START  && instr_addr < `DATA_VADDR_START )begin
                    now_interrupt <= 5'd0;
                end
                if (!stall) begin // 只有不停顿才更新PC
                    instr_addr <= next_instr_addr;
                end 
            end
        end
    end
    assign pc_plus_4 = instr_addr + 32'd4;
    
    // IF/ID 寄存器: 存储 IF 阶段的输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc_plus_4_reg <= 32'b0;
            if_id_instr_reg <= 32'b0;
            if_id_pc_reg <= 32'b0;
        end else if (masked_interrupt == 32'b1) begin // 中断时清空流水线
            if_id_pc_plus_4_reg <= 32'b0;
            if_id_instr_reg <= 32'b0; // NOP
            if_id_pc_reg <= 32'b0;
        end else if (branch_success) begin // 分支成功时清空流水线
            if_id_pc_plus_4_reg <= 32'b0;
            if_id_instr_reg <= 32'b0; // NOP
            if_id_pc_reg <= 32'b0;
        end else if (!stall) begin 
            if_id_pc_plus_4_reg <= pc_plus_4;
            if_id_instr_reg <= instr_data;
            if_id_pc_reg <= instr_addr;
        end
    end
    
    // ID 阶段: 译码和寄存器读取
    assign opcode = if_id_instr_reg[6:0];
    assign funct3 = if_id_instr_reg[14:12];
    assign funct7 = if_id_instr_reg[31:25];
    assign ra1 = if_id_instr_reg[19:15];
    assign ra2 = if_id_instr_reg[24:20];
    assign wa = if_id_instr_reg[11:7];
    
    // ID/EX 寄存器: 存储 ID 阶段的输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_dmem_we_reg <= 1'b0;
            id_ex_alu_op_reg <= 4'b0000;
            id_ex_alu_cA_reg <= 1'b0;
            id_ex_alu_cB_reg <= 1'b0;
            id_ex_cWB_reg <= 2'b00;
            id_ex_branch_reg <= 4'b0000;
            id_ex_reg_we_reg <= 1'b0;
            id_ex_wa_reg <= 5'b0;
            id_ex_rd1_reg <= 32'b0;
            id_ex_rd2_reg <= 32'b0;
            id_ex_ra1_reg <= 5'b0; 
            id_ex_ra2_reg <= 5'b0;
            id_ex_pc_plus_4_reg <= 32'b0;
            id_ex_immediate_reg <= 32'b0;
            id_ex_pc_reg <= 32'b0;
        end else begin
            if (masked_interrupt == 32'b1) begin // 中断时清空寄存器
                id_ex_dmem_we_reg <= 1'b0;
                id_ex_alu_op_reg <= 4'b0000;
                id_ex_alu_cA_reg <= 1'b0;
                id_ex_alu_cB_reg <= 1'b0;
                id_ex_cWB_reg <= 2'b00;
                id_ex_branch_reg <= 4'b0000;
                id_ex_reg_we_reg <= 1'b0;
                id_ex_wa_reg <= 5'b0;
                id_ex_rd1_reg <= 32'b0;
                id_ex_rd2_reg <= 32'b0;
                id_ex_ra1_reg <= 5'b0; 
                id_ex_ra2_reg <= 5'b0;
                id_ex_pc_plus_4_reg <= 32'b0;
                id_ex_immediate_reg <= 32'b0;
                id_ex_pc_reg <= 32'b0;
            end else if (branch_success) begin // 分支跳转成功清空寄存器
                id_ex_dmem_we_reg <= 1'b0;
                id_ex_alu_op_reg <= 4'b0000;
                id_ex_alu_cA_reg <= 1'b0;
                id_ex_alu_cB_reg <= 1'b0;
                id_ex_cWB_reg <= 2'b00;
                id_ex_branch_reg <= 4'b0000;
                id_ex_reg_we_reg <= 1'b0;
                id_ex_wa_reg <= 5'b0;
                id_ex_rd1_reg <= 32'b0;
                id_ex_rd2_reg <= 32'b0;
                id_ex_ra1_reg <= 5'b0; 
                id_ex_ra2_reg <= 5'b0;
                id_ex_pc_plus_4_reg <= 32'b0;
                id_ex_immediate_reg <= 32'b0;
                id_ex_pc_reg <= 32'b0;
            end else if (stall) begin // 插入气泡
                id_ex_dmem_we_reg <= 1'b0;
                id_ex_alu_op_reg <= 4'b0000;
                id_ex_alu_cA_reg <= 1'b0;
                id_ex_alu_cB_reg <= 1'b0;
                id_ex_cWB_reg <= 2'b00;
                id_ex_branch_reg <= 4'b0000;
                id_ex_reg_we_reg <= 1'b0;
                id_ex_wa_reg <= 5'b0;
            end else begin // 正常更新
                id_ex_dmem_we_reg <= dmem_we;
                id_ex_alu_op_reg <= alu_op;
                id_ex_alu_cA_reg <= alu_cA;
                id_ex_alu_cB_reg <= alu_cB;
                id_ex_cWB_reg <= cWB;
                id_ex_branch_reg <= branch;
                id_ex_reg_we_reg <= reg_we;
                id_ex_wa_reg <= wa;
                id_ex_ra1_reg <= ra1; 
                id_ex_ra2_reg <= ra2; 
                id_ex_rd1_reg <= mux_rd1;
                id_ex_rd2_reg <= mux_rd2;
                id_ex_pc_plus_4_reg <= if_id_pc_plus_4_reg;
                id_ex_immediate_reg <= immediate;
                id_ex_pc_reg <= if_id_pc_reg ;
            end
        end
    end
     
    assign branch_addr = id_ex_immediate_reg + id_ex_pc_reg;
    // EX/MEM 寄存器: 存储 EX 阶段的输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_dmem_we_reg <= 1'b0;
            ex_mem_cWB_reg <= 2'b00;
            ex_mem_branch_reg <= 4'b0000;
            ex_mem_reg_we_reg <= 1'b0;
            ex_mem_wa_reg <= 5'b0;
            ex_mem_rd2_reg <= 32'b0;
            ex_mem_alu_result_reg <= 32'b0;
            ex_mem_zero_flag_reg <= 1'b0;
            ex_mem_lt_flag_reg <= 1'b0;
            ex_mem_immediate_reg <= 32'b0;
            ex_mem_branch_addr_reg <= 32'b0;
            ex_mem_pc_reg <= 32'b0;
            ex_mem_pc_plus_4_reg <= 32'b0;
        end else if (masked_interrupt == 32'b1) begin
            ex_mem_dmem_we_reg <= 1'b0;
            ex_mem_cWB_reg <= 2'b00;
            ex_mem_branch_reg <= 4'b0000;
            ex_mem_reg_we_reg <= 1'b0;
            ex_mem_wa_reg <= 5'b0;
            ex_mem_rd2_reg <= 32'b0;
            ex_mem_alu_result_reg <= 32'b0;
            ex_mem_zero_flag_reg <= 1'b0;
            ex_mem_lt_flag_reg <= 1'b0;
            ex_mem_immediate_reg <= 32'b0;
            ex_mem_branch_addr_reg <= 32'b0;
            ex_mem_pc_reg <= 32'b0;
            ex_mem_pc_plus_4_reg <= 32'b0;
        end else if (branch_success) begin
            ex_mem_dmem_we_reg <= 1'b0;
            ex_mem_cWB_reg <= 2'b00;
            ex_mem_branch_reg <= 4'b0000;
            ex_mem_reg_we_reg <= 1'b0;
            ex_mem_wa_reg <= 5'b0;
            ex_mem_rd2_reg <= 32'b0;
            ex_mem_alu_result_reg <= 32'b0;
            ex_mem_zero_flag_reg <= 1'b0;
            ex_mem_lt_flag_reg <= 1'b0;
            ex_mem_immediate_reg <= 32'b0;
            ex_mem_branch_addr_reg <= 32'b0;
            ex_mem_pc_reg <= 32'b0;
            ex_mem_pc_plus_4_reg <= 32'b0;
        end else begin
            ex_mem_dmem_we_reg <= id_ex_dmem_we_reg;
            ex_mem_cWB_reg <= id_ex_cWB_reg;
            ex_mem_branch_reg <= id_ex_branch_reg;
            ex_mem_reg_we_reg <= id_ex_reg_we_reg;
            ex_mem_wa_reg <= id_ex_wa_reg;
            ex_mem_rd2_reg <= id_ex_rd2_reg;
            ex_mem_alu_result_reg <= alu_result;
            ex_mem_zero_flag_reg <= zero_flag;
            ex_mem_lt_flag_reg <= lt_flag;
            ex_mem_immediate_reg <= id_ex_immediate_reg;
            ex_mem_branch_addr_reg <= branch_addr;
            ex_mem_pc_reg <= id_ex_pc_reg;
            ex_mem_pc_plus_4_reg <= id_ex_pc_plus_4_reg;
        end
    end

    // MEM 阶段: 内存访问
    // Data Memory
    // 计算分支/跳转目标地址 (PC + 立即数)
    assign next_instr_addr = (branch_taken == 2'b01) ? ex_mem_branch_addr_reg : 
                             (branch_taken == 2'b10) ? ex_mem_alu_result_reg : pc_plus_4;
    
    // MEM/WB 寄存器: 存储 MEM 阶段的输出
    //中断逻辑：在写回阶段直接将将写回地址改成21号寄存器，写回内容改成mem_wb寄存器里的pc值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_rdata_reg <= 32'b0;
            mem_wb_cWB_reg <= 2'b00;
            mem_wb_reg_we_reg <= 1'b0;
            mem_wb_wa_reg <= 5'b0;
            mem_wb_alu_result_reg <= 32'b0;
            mem_wb_immediate_reg <= 32'b0;
            mem_wb_pc_reg <= 32'h0;
            mem_wb_pc_plus_4_reg <= 32'b0;
        end else if (masked_interrupt == 32'b1) begin
            mem_wb_rdata_reg <= 32'b0;
            mem_wb_cWB_reg <= 2'b00;
            mem_wb_reg_we_reg <= 1'b0;
            mem_wb_wa_reg <= 5'b0;
            mem_wb_alu_result_reg <= 32'b0;
            mem_wb_immediate_reg <= 32'b0;
            mem_wb_pc_reg <= 32'b0;
            mem_wb_pc_plus_4_reg <= 32'b0;
        end else begin
            mem_wb_rdata_reg <= rdata;
            mem_wb_cWB_reg <= ex_mem_cWB_reg;
            mem_wb_reg_we_reg <= ex_mem_reg_we_reg;
            mem_wb_wa_reg <= ex_mem_wa_reg;
            mem_wb_alu_result_reg <= ex_mem_alu_result_reg; 
            mem_wb_immediate_reg <= ex_mem_immediate_reg;
            mem_wb_pc_reg <= ex_mem_pc_reg;
            mem_wb_pc_plus_4_reg <= ex_mem_pc_plus_4_reg;
        end
    end

    // WB 阶段: 写入寄存器，连接之前已完成
    

endmodule
