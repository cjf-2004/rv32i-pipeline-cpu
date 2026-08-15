# 定义外设寄存器地址
.eqv PERIPHERAL_BASE_ADDR, 0x80000000
.eqv PERIPHERAL_DATA_ADDR, 0x80000004

# 定义控制模式常量
.eqv EDIT_MODE, 2         # 编辑模式，对应 display_mode_reg = 0b10
.eqv TIMER_MODE, 1        # 倒计时模式，对应 display_mode_reg = 0b01

# 定义状态标志位掩码
.eqv COMMIT_FLAG_MASK, 4  # commit_flag 在第2位 (0x1 << 2)
.eqv COUNTDOWN_OVER_MASK, 8 # countdown_over 在第3位 (0x1 << 3)

.text
.global _start

_start:
##-------------------------------------------------
## 阶段1: 控制外设进入编辑模式
## 将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
## 将编辑模式值加载到 t1
li t1, EDIT_MODE
## 将 t1 中的值写入 t0 指向的地址，设置外设为编辑模式
sw t1, 0(t0)

##-------------------------------------------------
## 阶段2: 轮询等待 commit_flag 为 1

wait_commit_loop:
## 从 t0 指向的地址（外设控制寄存器）加载状态字到 t2
lw t2, 0(t0)
## 使用掩码操作，只保留 commit_flag 位
andi t2, t2, COMMIT_FLAG_MASK
## 如果 t2 和 x0 (零寄存器) 相等，说明 commit_flag 为 0，则继续循环
beq t2, x0, wait_commit_loop

##-------------------------------------------------
## 阶段3: 读取编辑好的数据

## 将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
## 从 t0 指向的地址加载数据到 t3
lw t3, 0(t0)
## 现在 t3 中保存着用户在编辑模式下输入的数据

##-------------------------------------------------
## 阶段4: 控制外设进入倒计时模式，并写入数据

## 重新将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
## 将倒计时模式值加载到 t1
li t1, TIMER_MODE
## 将 t1 中的值写入 t0 指向的地址，设置外设为倒计时模式
sw t1, 0(t0)

## 重新将外设数据寄存器地址加载到 t0
li t0, PERIPHERAL_DATA_ADDR
## 将之前读取的数据（t3）写入 t0 指向的地址，开始倒计时
sw t3, 0(t0)

##-------------------------------------------------
## 阶段5: 轮询等待 countdown_over 为 1

wait_countdown_loop:
## 重新将外设控制寄存器地址加载到 t0
li t0, PERIPHERAL_BASE_ADDR
## 从 t0 指向的地址加载状态字到 t2
lw t2, 0(t0)
## 使用掩码操作，只保留 countdown_over 位
andi t2, t2, COUNTDOWN_OVER_MASK
## 如果 t2 和 x0 相等，说明倒计时还没有结束，则继续循环
beq t2, x0, wait_countdown_loop

##-------------------------------------------------
## 阶段6: 倒计时结束，回到编辑模式

## 无条件跳转回 _start，重新开始整个流程
j _start
