#-------------------------------------------------
# 宏定义：外设寄存器地址与控制位掩码
#-------------------------------------------------
.eqv PERIPHERAL_BASE_ADDR, 0x80000000
.eqv PERIPHERAL_DATA_ADDR, 0x80000004

# 控制模式常量
.eqv EDIT_MODE, 2
.eqv TIMER_MODE, 1
.eqv READ_SHOW, 0x00
.eqv READ_TIMER, 0x10
.eqv READ_EDIT, 0x20
# 状态标志位掩码
.eqv COMMIT_FLAG_MASK, 4
.eqv COUNTDOWN_OVER_MASK, 8

.text
.global _start

_start:
##-------------------------------------------------
## 阶段1: 模式选择
##
## 引导用户进入编辑模式，通过输入0x0或0x1来选择模式。
## 在七段数码管上显示 '0' 或 '1' 提示用户。
##-------------------------------------------------

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 将编辑模式值加载到 t1
li t1, EDIT_MODE
addi t1, t1, READ_EDIT
# 设置外设为编辑模式
sw t1, 0(t0)

# 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
# 写入 0x0 作为初始提示（例如，在数码管上显示 0）
li t1, 0
sw t1, 0(t0)

# 等待用户输入模式选择（0x0 或 0x1）
call wait_commit

# 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
# 读取用户输入的模式选择值
lw t1, 0(t0)

# 根据用户输入跳转到相应的模式
beq t1, x0, run_timer_mode
li t2, 1
beq t1, t2, run_add_mode

# 如果输入无效，则重新开始模式选择
j _start

##-------------------------------------------------
## 模式 1: 计时器模式 (Timer Mode)
##-------------------------------------------------

run_timer_mode:
# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 进入编辑模式
li t1, EDIT_MODE
addi t1, t1, READ_EDIT
sw t1, 0(t0)

# 提示用户在数码管上输入倒计时值
# 写入 0x00000000 作为提示
li t0, PERIPHERAL_DATA_ADDR
li t1, 0
sw t1, 0(t0)

# 轮询等待用户输入数据并提交
call wait_commit


# 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
# 从数据寄存器读取用户输入的计时器值到 t3
lw t3, 0(t0)

# 重新将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 将倒计时模式值加载到 t1
li t1, TIMER_MODE
# 设置外设为倒计时模式
sw t1, 0(t0)

# 将用户输入的计时器值写入数据寄存器，开始倒计时
li t0, PERIPHERAL_DATA_ADDR
sw t3, 0(t0)

# 轮询等待倒计时结束
call wait_countdown

# 倒计时结束，回到模式选择
j _start

##-------------------------------------------------
## 模式 2: 加法模式 (Addition Mode)
##-------------------------------------------------

run_add_mode:

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 进入编辑模式
li t1, EDIT_MODE
addi t1, t1, READ_EDIT
sw t1, 0(t0)

# 提示用户输入第一个数
# 写入 0x00000000 作为提示
li t0, PERIPHERAL_DATA_ADDR
li t1, 0
sw t1, 0(t0)


# 轮询等待用户输入第一个数并提交
call wait_commit

# 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
# 读取第一个数到 t3
lw t3, 0(t0)

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 再次进入编辑模式
li t1, EDIT_MODE
addi t1, t1, READ_EDIT
sw t1, 0(t0)

# 提示用户输入第二个数
# 写入 0x00000000 作为提示
li t0, PERIPHERAL_DATA_ADDR
li t1, 0
sw t1, 0(t0)

# 轮询等待用户输入第二个数并提交
call wait_commit

# 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
# 读取第二个数到 t4
lw t4, 0(t0)

# 执行加法
add t5, t3, t4

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 再次进入编辑模式，这样方便退出
li t1, EDIT_MODE
sw t1, 0(t0)

# 将加法结果显示在数码管上
li t0, PERIPHERAL_DATA_ADDR
sw t5, 0(t0)

# 轮询等待用户输入确认加法结果并提交
call wait_commit

j _start

##-------------------------------------------------
## 子例程：轮询等待
##-------------------------------------------------
wait_commit:
# 轮询等待 commit_flag 为 1
wait_commit_loop:
# 从外设控制寄存器加载状态字到 t2
li t0, PERIPHERAL_BASE_ADDR
lw t2, 0(t0)
# 使用掩码操作，只保留 commit_flag 位
andi t2, t2, COMMIT_FLAG_MASK
# 如果 t2 和 x0 (零寄存器) 相等，说明 commit_flag 为 0，则继续循环
beq t2, x0, wait_commit_loop
ret

wait_countdown:
# 轮询等待 countdown_over 为 1
wait_countdown_loop:
# 从外设控制寄存器加载状态字到 t2
li t0, PERIPHERAL_BASE_ADDR
lw t2, 0(t0)
# 使用掩码操作，只保留 countdown_over 位
andi t2, t2, COUNTDOWN_OVER_MASK
# 如果 t2 和 x0 相等，说明倒计时还没有结束，则继续循环
beq t2, x0, wait_countdown_loop
ret
