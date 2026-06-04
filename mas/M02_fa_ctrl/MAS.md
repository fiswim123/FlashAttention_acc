---
module: M02
type: MAS
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_ctrl 微架构规范

## 1. 模块概述

### 1.1 功能描述
主控制器 FSM, 管理整个 FlashAttention 计算流程。协调 DMA 加载、MAC 计算、Softmax 更新、除法归一化和 DMA 写回。

### 1.2 模块类型
- 类型: `compute`
- 层级: L1

### 1.3 设计约束
- 面积预算: ~5K gates
- 功耗预算: ~0.5 mW
- 时钟频率: 50 MHz

---

## 2. 接口定义

### 2.1 信号列表

| 信号名 | 方向 | 位宽 | 类型 | 描述 |
|--------|------|------|------|------|
| `clk` | input | 1 | 时钟 | 50 MHz |
| `rst_n` | input | 1 | 控制 | 异步复位, 低有效 |
| `start` | input | 1 | 控制 | 启动计算 (来自 regfile) |
| `busy` | output | 1 | 状态 | 计算进行中 |
| `done` | output | 1 | 状态 | 计算完成 |
| `error` | output | 1 | 状态 | 错误标志 |
| `causal_en` | input | 1 | 配置 | causal mask 使能 |
| `dma_start` | output | 1 | 控制 | DMA 启动 |
| `dma_done` | input | 1 | 控制 | DMA 完成 |
| `dma_cmd` | output | 2 | 控制 | DMA 命令 (Q/K/V/O) |
| `mac_start` | output | 1 | 控制 | MAC 启动 |
| `mac_done` | input | 1 | 控制 | MAC 完成 |
| `mac_mode` | output | 1 | 控制 | MAC 模式 (QK/SV) |
| `sm_start` | output | 1 | 控制 | Softmax 启动 |
| `sm_done` | input | 1 | 控制 | Softmax 完成 |
| `div_start` | output | 1 | 控制 | 除法启动 |
| `div_done` | input | 1 | 控制 | 除法完成 |
| `row_cnt` | output | 8 | 计数 | 当前行索引 (0..255) |
| `tile_cnt` | output | 4 | 计数 | 当前 tile 索引 (0..15) |
| `buf_sel` | output | 1 | 控制 | K/V 双缓冲选择 |
| `acc_clear` | output | 1 | 控制 | 清除累加器 |
| `cycle_cnt` | output | 32 | 计数 | 总周期计数 |
| `soft_reset` | input | 1 | 控制 | 软复位 |

---

## 3. 数据通路

### 3.1 计数器

| 计数器 | 位宽 | 范围 | 说明 |
|--------|------|------|------|
| `row_cnt` | 8 | 0..255 | 当前行索引 |
| `tile_cnt` | 4 | 0..15 | 当前 tile 索引 |
| `div_cnt` | 4 | 0..15 | 除法迭代计数 |
| `cycle_cnt` | 32 | 0..2^32-1 | 总周期计数 |

### 3.2 控制信号时序

| 阶段 | 输出信号 | 持续时间 |
|------|----------|----------|
| LOAD_Q | dma_start, dma_cmd=Q | 直到 dma_done |
| MAC_QK | mac_start, mac_mode=0 | 64 cycles |
| SOFTMAX | sm_start | 4 cycles |
| MAC_SV | mac_start, mac_mode=1 | 64 cycles |
| DIV | div_start | 16*64 cycles |
| STORE_O | dma_start, dma_cmd=O | 直到 dma_done |

---

## 4. 状态机设计

详见 [FSM.md](./FSM.md)

---

## 5. 时序规格

| 参数 | 数值 | 单位 |
|------|------|------|
| 单行延迟 | ~5136 | cycles |
| 256 行总延迟 | ~1.3M | cycles |
| DMA 隐藏优化后 | ~150K | cycles |

---

## 6. 功耗管理
- Clock Gating: IDLE 时门控所有子模块时钟

---

## 7. 验证要点

详见 [verification.md](./verification.md)

---

## 8. DFT 方案

详见 [DFT.md](./DFT.md)

---

## 9. 实现任务

详见 [tasks.md](./tasks.md)

---

## 10. 需求追踪矩阵

| REQ_ID | 需求描述 | 优先级 | 验收标准 | 边界条件 | RTL 组件 | 测试用例 |
|--------|---------|--------|---------|---------|---------|---------|
| REQ-M02-F01 | 启动流程 | P1 | START -> BUSY -> DONE | 复位后 | main_fsm | TC-M02-01 |
| REQ-M02-F02 | 行循环 (256 行) | P1 | row_cnt 0..255 | 行边界 | row_counter | TC-M02-02 |
| REQ-M02-F03 | tile 循环 (16 tiles) | P1 | tile_cnt 0..15 | tile 边界 | tile_counter | TC-M02-03 |
| REQ-M02-F04 | DMA 协调 | P1 | dma_start/done 握手 | DMA 超时 | dma_ctrl | TC-M02-04 |
| REQ-M02-F05 | MAC 协调 | P1 | mac_start -> 64 cycles -> mac_done | MAC 冲突 | mac_ctrl | TC-M02-05 |
| REQ-M02-F06 | Softmax 协调 | P1 | sm_start -> 4 cycles -> sm_done | -- | sm_ctrl | TC-M02-06 |
| REQ-M02-F07 | 除法协调 | P1 | div_start -> 1024 cycles -> div_done | -- | div_ctrl | TC-M02-07 |
| REQ-M02-F08 | 双缓冲切换 | P1 | tile 切换时 buf_sel 翻转 | 快速切换 | buf_ctrl | TC-M02-08 |
| REQ-M02-F09 | 软复位 | P1 | SOFT_RESET 恢复 IDLE | 计算中复位 | main_fsm | TC-M02-09 |
| REQ-M02-F10 | 周期计数 | P2 | CYCLES = START->DONE | -- | cycle_counter | TC-M02-10 |
