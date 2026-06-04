# FlashAttention 高性能硬件加速器 IP

## 赛题背景

研究生创"芯"大赛 Cadence 企业命题——基于大模型推理的 FlashAttention 高性能硬件加速器 IP 设计。

## 设计目标

设计一个可综合的 FlashAttention-style 注意力算子硬件 IP，在给定张量规模与接口规范下完成端到端 Scaled Dot-Product Attention (SDPA) 计算。

## 核心算法

$$O_i = \sum_{j=0}^{S-1} \text{softmax}\left(\frac{Q_i \cdot K_j}{\sqrt{d}} + M_{i,j}\right) V_j$$

### FlashAttention 三大约束（验收要点）

1. **禁止显式存储注意力矩阵** — 不存储 S×S 的 score/p 矩阵
2. **必须使用在线 (online) softmax** — 边计算边归一化
3. **必须分块 (tiling) 处理 K/V** — 将 K/V 切成小块逐块处理

## 固定输入规模（Baseline）

| 参数 | 值 |
|------|-----|
| 序列长度 S | 256 |
| head 维度 d | 64 |
| Q/K/V/O 形状 | [S, d] = [256, 64] |
| batch | 1 |
| head | 1 |
| Causal mask | 必须支持 |

## 数据格式

| 数据 | 格式 | 位宽 |
|------|------|------|
| 输入 Q/K/V | Q8.8 定点 | 16-bit 有符号 |
| Dot-product 累加 | 定点 | ≥32-bit（建议 40-bit） |
| Softmax 路径 | 定点/查表 | 可用更高位宽或分段缩放 |
| 输出 O | Q8.8 定点 | 16-bit 有符号 |

## 接口要求

### AXI4-Lite（控制）

- 主机写寄存器（基地址/参数）
- CTRL.START 启动
- STATUS 查询完成

### AXI4 Master + DMA（数据）

- 加速器启动后 DMA 从内存读入 Q, K, V
- 计算完成后 DMA 把 O 写回内存

### 寄存器映射

| Offset | 名称 | 访问 | 说明 |
|--------|------|------|------|
| 0x00 | CTRL | R/W | bit0: START, bit1: SOFT_RESET, bit2: IRQ_EN |
| 0x04 | STATUS | R | bit0: BUSY, bit1: DONE(w1c), bit2: ERROR |
| 0x08 | CFG | R/W | bit0: CAUSAL_EN |
| 0x14 | Q_BASE_L | R/W | Q 基地址低 32 位 |
| 0x18 | Q_BASE_H | R/W | Q 基地址高 32 位 |
| 0x1C | K_BASE_L | R/W | K 基地址低 32 位 |
| 0x20 | K_BASE_H | R/W | K 基地址高 32 位 |
| 0x24 | V_BASE_L | R/W | V 基地址低 32 位 |
| 0x28 | V_BASE_H | R/W | V 基地址高 32 位 |
| 0x2C | O_BASE_L | R/W | O 基地址低 32 位 |
| 0x30 | O_BASE_H | R/W | O 基地址高 32 位 |
| 0x34 | STRIDE_BYTES | R/W | 行 stride (bytes), 默认 d*2=128 |
| 0x38 | NEG_LARGE | R/W | -inf 近似值 (Q8.8) |
| 0x3C | SCALE | R/W | 缩放常数 1/sqrt(d) |
| 0x40 | CYCLES | R | 本次执行周期数 |

## 存储与资源约束

- **禁止存储 score/p 全矩阵**
- 片上中间 buffer 限额（不含输入/输出缓存）：
  - 允许缓存一小块 K, V tile
  - 允许每行维护 m/l/acc（以及必要流水寄存器）
- 若缓存全量 K,V 需在报告中量化带宽收益与 SRAM 代价

## 性能要求

| 指标 | 要求 |
|------|------|
| 主频 | 越高越好（Genus 物理综合） |
| 面积 | ≤200 万等效逻辑门（含存储器） |
| 延迟 | 单次 attention < 300K cycles |
| 带宽 | 需给出 RD_BYTES/WR_BYTES 统计 |

## 正确性验收

- 随机种子生成 Q,K,V (Q8.8) 与 golden 输出对比
- 与 FP32 golden 对比：
  - mean_abs_error(O) ≤ 0.03
  - max_abs_error(O) ≤ 0.10

## 验证要求

- SystemVerilog + UVM 或 Python + cocotb
- 必须覆盖：
  - AXI4-Lite 寄存器读写与启动/完成流程
  - 随机 Q,K,V 端到端验证
  - Causal mask corner case（如 i=0 行只能看 j=0）

## 可选加分项

| Item | 加分项 | 说明 |
|------|--------|------|
| 1 | BF16/FP16 | 低精度 attention 实现 |
| 2 | 多 head 支持 | head=4/8 |
| 3 | 更长序列 | S=512 或可配置 S |
| 4 | Padding mask | 有效长度 L≤S |
| 5 | 其他定点格式 | Q6.10/Q4.12 |
| 6 | Dropout | 训练模式 |
| 7 | INT8/FP8 | 块量化/分块缩放 |
| 8 | AXI4-Stream | 数据接口级联 |
| 9 | DMA/任务队列 | 连续多次执行 |

## FlashAttention 算法原理

### 在线 Softmax

传统 softmax 需要两遍扫描：第一遍求 max，第二遍求 exp 和 sum。
在线 softmax 在一遍扫描中同时维护：
- **m**: 当前最大值
- **l**: exp(x_i - m) 的累加和
- **acc**: 加权累加器

### 分块计算流程

```
For each query row i:
  初始化: m_i = -inf, l_i = 0, acc_i = 0

  For each K/V tile j (tile_size = Br 或 Bc):
    1. 从内存加载 K_tile, V_tile 到片上 buffer
    2. 计算 score_tile = Q[i] @ K_tile^T / sqrt(d)
    3. 应用 causal mask (if i < j: score = -inf)
    4. 更新在线 softmax:
       m_new = max(m_i, max(score_tile))
       l_new = exp(m_i - m_new) * l_i + sum(exp(score_tile - m_new))
       acc_new = exp(m_i - m_new) * acc_i + exp(score_tile - m_new) @ V_tile
       m_i = m_new, l_i = l_new, acc_i = acc_new

  O[i] = acc_i / l_i
```

### 带宽分析

- 朴素实现: O(S² × d) 带宽（存储 S×S 矩阵）
- FlashAttention: O(S² × d² / M) 带宽（M = 片上 SRAM 大小）
- 当 M ≥ d² 时，带宽降低为 O(S × d)

## 硬件架构思路

### 计算核心

1. **Systolic Array / MAC 阵列**: 用于 Q·K^T 和 attn·V 的矩阵乘法
2. **Online Softmax 单元**: 维护 m/l 状态，含 exp 查表 + 除法器
3. **Causal Mask 逻辑**: 根据行列索引生成 mask

### 数据通路

```
           ┌─────────────────────────────────────────────┐
           │                  FlashAttention Core        │
           │                                             │
  Q tile ──┤──► [MAC Array] ──► score ──► [Mask] ──►     │
           │                      │                      │
           │              [Online Softmax]               │
           │               m, l 更新                     │
           │                      │                      │
  V tile ──┤──► [exp×V MAC] ──► acc 更新                │
           │                      │                      │
           │              [Final: acc/l] ──► O tile      │
           └─────────────────────────────────────────────┘
```

### 存储层次

1. **寄存器**: m, l, acc (每行 64 元素 × 多行)
2. **Tile Buffer**: K_tile, V_tile (Br × d 或 Bc × d)
3. **Q Buffer**: 当前 Q 行 (1 × d)
4. **O Buffer**: 输出暂存

### DMA 控制器

- AXI4 Master 接口
- 支持 2D 传输（行 stride）
- 双缓冲：一个 tile 在计算时预取下一个

## 技术约束

- PDK: ASAP7 7nm
- 标准单元库: asap7sc7p5t_27 / asap7sc6t_26
- EDA 工具: 开源 Yosys + OpenSTA + Magic（Babel 流程）
- 时钟: 50MHz 目标（可调整）
