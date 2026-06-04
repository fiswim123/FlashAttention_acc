# FlashAttention 加速器 IP — 寄存器映射

## 1. 寄存器概览

基地址由 SoC 地址映射决定。所有寄存器 32-bit 宽度, 4 字节对齐。

| Offset | 名称 | 访问 | 复位值 | 说明 |
|--------|------|------|--------|------|
| 0x00 | CTRL | R/W | 0x0000_0000 | 控制寄存器 |
| 0x04 | STATUS | R/W1C | 0x0000_0000 | 状态寄存器 |
| 0x08 | CFG | R/W | 0x0000_0000 | 配置寄存器 |
| 0x0C | RESERVED | — | — | 保留 |
| 0x10 | Q_BASE_L | R/W | 0x0000_0000 | Q 基地址低 32 位 |
| 0x14 | Q_BASE_H | R/W | 0x0000_0000 | Q 基地址高 32 位 |
| 0x18 | K_BASE_L | R/W | 0x0000_0000 | K 基地址低 32 位 |
| 0x1C | K_BASE_H | R/W | 0x0000_0000 | K 基地址高 32 位 |
| 0x20 | V_BASE_L | R/W | 0x0000_0000 | V 基地址低 32 位 |
| 0x24 | V_BASE_H | R/W | 0x0000_0000 | V 基地址高 32 位 |
| 0x28 | O_BASE_L | R/W | 0x0000_0000 | O 基地址低 32 位 |
| 0x2C | O_BASE_H | R/W | 0x0000_0000 | O 基地址高 32 位 |
| 0x30 | STRIDE_BYTES | R/W | 0x0000_0080 | 行 stride (bytes), 默认 128 |
| 0x34 | NEG_LARGE | R/W | 0xFF80_0000 | -inf 近似值 (Q8.8) |
| 0x38 | SCALE | R/W | 0x0000_0100 | 缩放常数 1/sqrt(d) |
| 0x3C | CYCLES | R | 0x0000_0000 | 执行周期数 |

---

## 2. 寄存器位域详情

### 2.1 CTRL (0x00) — 控制寄存器

| Bits | 名称 | 访问 | 说明 |
|------|------|------|------|
| [0] | START | R/W | 写 1 启动计算, 自动清零 |
| [1] | SOFT_RESET | R/W | 写 1 软复位, 自动清零 |
| [2] | IRQ_EN | R/W | 中断使能 |
| [31:3] | RESERVED | — | 保留, 读返回 0 |

**写行为**: START 和 SOFT_RESET 是 self-clearing bit, 写 1 后硬件自动清零。

### 2.2 STATUS (0x04) — 状态寄存器

| Bits | 名称 | 访问 | 说明 |
|------|------|------|------|
| [0] | BUSY | R | 计算进行中 |
| [1] | DONE | R/W1C | 计算完成, 写 1 清零 |
| [2] | ERROR | R/W1C | 错误标志, 写 1 清零 |
| [31:3] | RESERVED | — | 保留, 读返回 0 |

**W1C 行程**: DONE 和 ERROR 是 Write-1-to-Clear, 写 1 清零, 写 0 无效。

### 2.3 CFG (0x08) — 配置寄存器

| Bits | 名称 | 访问 | 说明 |
|------|------|------|------|
| [0] | CAUSAL_EN | R/W | 1=启用 causal mask, 0=无 mask |
| [31:1] | RESERVED | — | 保留, 读返回 0 |

### 2.4 Q_BASE_L/H (0x10/0x14) — Q 基地址

| Bits | 名称 | 说明 |
|------|------|------|
| [31:0] | Q_BASE_L | 64 位地址低 32 位 |
| [31:0] | Q_BASE_H | 64 位地址高 32 位 |

### 2.5 K_BASE_L/H (0x18/0x1C) — K 基地址

同 Q_BASE 格式。

### 2.6 V_BASE_L/H (0x20/0x24) — V 基地址

同 Q_BASE 格式。

### 2.7 O_BASE_L/H (0x28/0x2C) — O 基地址

同 Q_BASE 格式。

### 2.8 STRIDE_BYTES (0x30) — 行 Stride

| Bits | 名称 | 说明 |
|------|------|------|
| [31:0] | STRIDE | 行 stride (bytes), 默认 128 (d*2B = 64*2) |

### 2.9 NEG_LARGE (0x34) — 负无穷近似

| Bits | 名称 | 说明 |
|------|------|------|
| [15:0] | NEG_LARGE | Q8.8 格式, 默认 0x8000 (-128.0) |

用于 causal mask 中被 mask 位置的 score 赋值。

### 2.10 SCALE (0x38) — 缩放常数

| Bits | 名称 | 说明 |
|------|------|------|
| [15:0] | SCALE | Q8.8 格式, 1/sqrt(d) = 1/8 = 0.125 = 0x0020 |

### 2.11 CYCLES (0x3C) — 周期计数器

| Bits | 名称 | 说明 |
|------|------|------|
| [31:0] | CYCLES | 从 START 到 DONE 的 cycle 数 |

只读, 计算完成后可读取。

---

## 3. 编程序列

### 3.1 正常操作流程

```
1. 写 CFG: 设置 CAUSAL_EN
2. 写 Q_BASE_L/H: Q 矩阵基地址
3. 写 K_BASE_L/H: K 矩阵基地址
4. 写 V_BASE_L/H: V 矩阵基地址
5. 写 O_BASE_L/H: O 矩阵输出地址
6. 写 STRIDE_BYTES: 行 stride
7. 写 NEG_LARGE: -inf 近似值
8. 写 SCALE: 1/sqrt(d)
9. 写 CTRL.START = 1: 启动计算
10. 轮询 STATUS.BUSY 或等待中断
11. 读 STATUS.DONE: 确认完成
12. 读 CYCLES: 获取执行周期数
13. 写 STATUS.DONE = 1: 清除 DONE 标志
```

### 3.2 软复位流程

```
1. 写 CTRL.SOFT_RESET = 1
2. 等待 STATUS.BUSY = 0
3. 重新配置寄存器
```

### 3.3 错误处理

```
1. 检查 STATUS.ERROR
2. 如果 ERROR = 1:
   a. 读 CYCLES 确认执行位置
   b. 写 STATUS.ERROR = 1 清除错误
   c. 执行软复位
   d. 重新配置并重试
```
