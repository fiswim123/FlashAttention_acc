# FlashAttention 加速器 IP — 工作原理

## 1. 算法背景

FlashAttention 是一种通过在线 (online) softmax 和分块 (tiling) 处理来高效计算 Scaled Dot-Product Attention 的算法。核心思想: 避免显式存储 S*S 的注意力矩阵, 而是在分块处理 K/V 的过程中逐步更新输出累加器。

### 1.1 标准 SDPA 公式

```
Attention(Q, K, V) = softmax(Q * K^T / sqrt(d)) * V
```

其中 Q, K, V 均为 [S, d] 矩阵。

### 1.2 FlashAttention 核心算法

```
For each query row i (i = 0..S-1):
  初始化: m_i = -inf, l_i = 0, acc_i = [0]*d

  For each K/V tile j (tile_size = Bc = 16):
    1. 从内存加载 K_tile[Bc, d], V_tile[Bc, d]
    2. score = Q[i] @ K_tile^T / sqrt(d)    // [1, Bc]
    3. if CAUSAL_EN: mask where j > i         // causal mask
    4. 在线 softmax 更新:
       m_new = max(m_i, max(score))
       l_new = exp(m_i - m_new) * l_i + sum(exp(score - m_new))
       acc_new = exp(m_i - m_new) * acc_i + exp(score - m_new) @ V_tile
       m_i, l_i, acc_i = m_new, l_new, acc_new

  O[i] = acc_i / l_i
```

### 1.3 在线 Softmax 原理

传统 softmax 需要两遍扫描:
1. 第一遍: 计算 max, 然后计算 exp(x - max) 和 sum
2. 第二遍: 除以 sum 得到归一化结果

在线 softmax 将两遍合并为一遍: 维护运行最大值 m 和运行和 l, 每次新数据到来时用缩放因子 `exp(m_old - m_new)` 修正之前的累加结果。

**数值稳定性**: 通过减去当前最大值, exp 的输入始终 <= 0, 避免溢出。

---

## 2. 硬件映射

### 2.1 计算原语

| 原语 | 实现 | 延迟 | 吞吐量 |
|------|------|------|--------|
| MAC (16x16->40) | 脉动/向量阵列 | 1 cycle | 16 ops/cycle |
| Exp 查表 | 256-entry ROM + 线性插值 | 2 cycles | 1 result/cycle |
| 比较器 (max) | 树形比较器 | 1 cycle | 16 values/cycle |
| 除法器 | 迭代 SRT | 16 cycles | 1 result/16 cycles |
| 加法器 (40-bit) | carry-lookahead | 1 cycle | 1 op/cycle |

### 2.2 流水线结构

```
Stage 1: DMA 加载 (K/V tile 从外部内存)
Stage 2: Q*K^T MAC 计算 (16 元素并行)
Stage 3: Causal mask 应用
Stage 4: Softmax 更新 (max + exp + sum)
Stage 5: score*V MAC 计算 (16 元素并行)
Stage 6: 累加器更新
Stage 7: 除法归一化 (每行结束时)
```

### 2.3 并行度分析

| 维度 | 并行度 | 说明 |
|------|--------|------|
| Q*K^T | 16-wide MAC | 每 cycle 处理 16 个 K 元素 |
| score*V | 16-wide MAC | 每 cycle 处理 16 个 V 元素 |
| 行间 | 1 (串行) | 逐行处理, 降低面积 |
| tile 间 | 1 (串行) | 逐 tile 处理 |

---

## 3. 数据格式

### 3.1 Q8.8 定点格式

```
Q8.8: [sign(1)] [integer(7)] [fraction(8)]
范围: [-128, +127.99609375]
精度: 1/256 ≈ 0.00390625
```

### 3.2 累加器格式

```
40-bit 定点: [sign(1)] [integer(7)] [fraction(32)]
范围: [-128, +127.99999999767]
精度: 2^-32 ≈ 2.3e-10
```

### 3.3 溢出保护

| 场景 | 保护机制 |
|------|----------|
| MAC 累加 | 40-bit 饱和 |
| Exp 查表 | 输入 clamp 到 [-8, 0] 范围 |
| 除法 | 检测 l=0, 输出 0 |
| m 更新 | 初始值 -inf (Q8.8 最小值) |

---

## 4. Causal Mask 实现

### 4.1 Mask 规则

对于 self-attention, 位置 i 只能看到位置 j <= i 的 token:

```
mask[i][j] = (j <= i) ? 1 : 0
```

### 4.2 硬件实现

在 tile 级别: 对于 tile 起始位置 `j_start`, 若 `j_start > i`, 则整个 tile 被 mask (跳过计算)。否则对 tile 内的元素逐一检查 `j <= i`。

优化: 当 `j_start + Bc - 1 <= i` 时, 整个 tile 无需 mask, 直接计算。

---

## 5. 时序分析

### 5.1 单行计算流程

```
For row i:
  For tile j = 0 to 15:   // S/Bc = 256/16 = 16 tiles
    DMA load K/V tile:     ~128 cycles (假设 256B/cycle)
    Q*K^T MAC:             ~64 cycles (16-wide, 64 elements)
    Softmax update:        ~64 cycles (16 exp + accumulate)
    score*V MAC:           ~64 cycles (16-wide, 64 elements)
    Total per tile:        ~320 cycles
  Division (acc/l):        ~16 cycles
  Total per row:           ~5136 cycles
Total all rows:            ~5136 * 256 = ~1,314,816 cycles (worst case)
```

实际优化 (流水线重叠 DMA 和计算):
```
Effective per tile:        ~200 cycles (DMA hidden)
Total per row:             ~3216 cycles
Total all rows:            ~3216 * 256 = ~823,296 cycles
```

进一步优化 (MAC 流水线满载):
```
Target: ~150,000 cycles (需要更高并行度或更深流水线)
```

### 5.2 关键路径

```
Q*K^T MAC → max → exp LUT → 累加 → score*V MAC → 累加器更新
```

关键路径延迟决定最大时钟频率。ASAP7 7nm 下 50 MHz 目标可行。
