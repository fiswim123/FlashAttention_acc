# FlashAttention 加速器 IP — 模块概述

## 1. 设计定位

FlashAttention-style 注意力算子硬件加速器 IP，面向大模型推理场景中 Scaled Dot-Product Attention (SDPA) 的高效计算。

### 1.1 关键特性

| 特性 | 规格 |
|------|------|
| 算法 | FlashAttention (online softmax + tiling) |
| 精度 | Q8.8 定点 I/O (16-bit), 40-bit 累加 |
| 序列长度 | S=256 (固定) |
| 头维度 | d=64 (固定) |
| 头数 | 1 (单 head) |
| Causal mask | 支持 |
| 接口 | AXI4-Lite 控制 + AXI4 Master DMA |
| PDK | ASAP7 7nm |
| 目标频率 | 50 MHz |
| 面积预算 | <= 1.8M 等效门 (2M 上限) |
| 功耗预算 | <= 50 mW 动态 |
| 延迟目标 | < 300K cycles (目标 ~150K) |

### 1.2 设计决策 (已确认)

| 决策 | 选择 | 理由 |
|------|------|------|
| Tiling Bc | 16 | 片上 buffer ~4KB K/V, 面积友好 |
| Exp 实现 | 256-entry LUT + 分段线性插值 | 精度高, 面积 ~1KB ROM, 延迟 2 cycles |
| 除法器 | 迭代除法器 | 固定 16 cycles/次, 面积小, 每行 64 元素共享 |
| 范围 | Baseline only | 专注 S=256, d=64, 单 head, Q8.8 |

### 1.3 关键差异化

| 特性 | 本设计 | 朴素实现 |
|------|--------|----------|
| 中间存储 | O(S*d) — 不存储 SxS 矩阵 | O(S^2) — 显式 score/p 矩阵 |
| Softmax | 在线 (online) 一遍扫描 | 两遍扫描 (max + exp/sum) |
| 数据流 | 分块 (tiling) K/V | 全量加载 |
| 带宽 | O(S*d^2/M) | O(S^2*d) |

---

## 2. 模块组成

| 编号 | 模块名 | 功能 | 复用 |
|------|--------|------|------|
| M01 | fa_top | 顶层封装, 寄存器接口, 子模块例化 | none |
| M02 | fa_ctrl | 主控制器 FSM, 管理整体计算流程 | none |
| M03 | fa_dma | AXI4 Master DMA 引擎, 负责 Q/K/V/O 数据搬运 | none |
| M04 | fa_systolic | 脉动阵列/向量 MAC 阵列, 计算 Q*K^T 和 score*V | none |
| M05 | fa_softmax | 在线 softmax 单元: max比较, exp查表, 累加 | none |
| M06 | fa_divider | 迭代除法器, 计算 acc/l 归一化 | none |
| M07 | fa_buffer_mgr | 片上 buffer 管理: Q/K/V/O tile 缓存 | none |
| M08 | fa_regfile | AXI4-Lite 从接口 + 寄存器文件 | none |

---

## 3. 顶层接口概览

| 接口 | 类型 | 协议 | 说明 |
|------|------|------|------|
| axil_s | Slave | AXI4-Lite | 寄存器配置 |
| axi_m | Master | AXI4 | DMA 数据搬运 |
| clk | Input | — | 系统时钟 (50 MHz) |
| rst_n | Input | — | 异步复位, 低有效 |

---

## 4. 面积估算

| 组件 | 等效门数 | 说明 |
|------|----------|------|
| fa_ctrl (FSM) | ~5K | 状态机 + 计数器 |
| fa_dma (AXI4 M) | ~15K | AXI4 master + 地址生成 |
| fa_systolic (MAC) | ~200K | 16-wide MAC 阵列 |
| fa_softmax | ~30K | 比较器 + LUT + 累加 |
| fa_divider | ~10K | 迭代除法器 |
| fa_buffer_mgr | ~20K | buffer 控制逻辑 |
| fa_regfile (AXI4-L S) | ~10K | 寄存器 + AXI-L 从接口 |
| SRAM (K/V tile) | ~4KB | Bc*d*2B*2 = 16*64*2*2 |
| SRAM (exp LUT) | ~512B | 256 entries * 2B |
| **总计 (逻辑)** | **~290K gates** | |
| **总计 (含 SRAM)** | **~500K gates** | 远低于 1.8M 上限 |

---

## 5. 时序预算

| 阶段 | 延迟 (cycles) | 说明 |
|------|---------------|------|
| DMA 加载 Q[256,64] | ~4096 | 256*64*2B / bus_width |
| 每行计算 (16 tiles) | ~600 | 含 MAC + softmax + div |
| 256 行总计 | ~153,600 | |
| DMA 写回 O | ~4096 | |
| **总计** | **~160K** | < 300K 目标 |
