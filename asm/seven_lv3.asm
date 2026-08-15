#-------------------------------------------------
# 宏定义：外设寄存器地址与控制位掩码
#-------------------------------------------------
.eqv PERIPHERAL_BASE_ADDR, 0x80000000
.eqv PERIPHERAL_DATA_ADDR, 0x80000004

# 控制模式常量
.eqv EDIT_MODE, 2
.eqv TIMER_MODE, 1
.eqv SHOW_MODE, 0
.eqv READ_SHOW, 0x00
.eqv READ_TIMER, 0x10
.eqv READ_EDIT, 0x20
# 状态标志位掩码
.eqv COMMIT_FLAG_MASK, 4
.eqv COUNTDOWN_OVER_MASK, 8

.data 
my_data: .word 0x00000000 , 0x00000001

.text
.global _start

_start:
#输入需要计时的时间
j run_timer_mode
j _start

##-------------------------------------------------
## 计时器模式 (Timer Mode)
##-------------------------------------------------

run_timer_mode:

# 重新将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 将倒计时模式值加载到 t1
li t1, TIMER_MODE
# 设置外设为倒计时模式
sw t1, 0(t0)

run_timer:
# 从外设控制寄存器加载状态字到 t2
li t0, PERIPHERAL_BASE_ADDR
lw t2, 0(t0)
# 使用掩码操作，只保留 countdown_over 位
andi t2, t2, COUNTDOWN_OVER_MASK
# 如果 t2 和 x0 相等，说明倒计时还没有结束，则继续循环
beq t2, x0, time_mode_swith

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 进入编辑模式，同时读数据也为编辑模式下的数据
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

	time_mode_swith:
		# 从外设控制寄存器加载状态字到 t2
		li t0, PERIPHERAL_BASE_ADDR
		lw t2, 0(t0)
		# 使用掩码操作，只保留 commit_flag 位
		andi t2, t2, COMMIT_FLAG_MASK
		# 如果 t2 和 x0 (零寄存器) 相等，说明 commit_flag 为 0，则继续循环
		beq t2, x0, run_timer
		
# 如果按下提交，就切换模式
j run_add_mode

##-------------------------------------------------
## 模式 2: 斐波那契数列计算模式 (Addition Mode)
##-------------------------------------------------

run_add_mode:

# 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
# 进入显示模式，但是读取的数据为倒计时的数据
li t1, SHOW_MODE
addi, t1 ,t1, READ_TIMER
sw t1, 0(t0)

run_compute:
#看看是否倒计时已经停止了
li t0, PERIPHERAL_BASE_ADDR
lw t1, 0(t0)
andi t1, t1, COUNTDOWN_OVER_MASK
bne t1, x0, add_mode_swith #如果不相等，代表coundown_over 为1，不用比较时间

la t0, my_data
#取第一个数
lw t1, 0(t0)
#取第二个数
lw t2, 4(t0)
#相加
add  t3, t2 ,t1
#存储新的数据
sw t2, 0(t0)
sw t3, 4(t0)


#写入最新的斐波那契数据
li t0, PERIPHERAL_DATA_ADDR
sw t3, 0(t0)
#读取计时器的数据
lw a1, 0(t0)
#等待一秒
loop_1_sec:
li t0, PERIPHERAL_DATA_ADDR
lw a2, 0(t0)
#看看是否倒计时已经停止了
li t0, PERIPHERAL_BASE_ADDR
lw t1, 0(t0)
andi t1, t1, COUNTDOWN_OVER_MASK
bne t1, x0, add_mode_swith #如果不相等，代表coundown_over 为1，不用比较时间
beq a1, a2 ,loop_1_sec
add_mode_swith:
	# 从外设控制寄存器加载状态字到 t2
	li t0, PERIPHERAL_BASE_ADDR
	lw t2, 0(t0)
	# 使用掩码操作，只保留 commit_flag 位
	andi t2, t2, COMMIT_FLAG_MASK
	# 如果 t2 和 x0 (零寄存器) 相等，说明 commit_flag 为 0，则继续循环
	beq t2, x0, run_compute
	
j run_timer_mode


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

