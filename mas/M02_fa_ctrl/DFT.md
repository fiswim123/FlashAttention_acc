---
module: M02
type: DFT
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_ctrl 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%

## 2. 扫描链配置

| 链 ID | 长度 | 时钟域 | 用途 |
|--------|------|--------|------|
| `chain_0` | ~500 | clk_domain | fa_ctrl |
| `chain_1` | ~500 | clk_domain | fa_ctrl (续) |

### 扫描寄存器映射

| 寄存器 | 位置 | 功能 |
|--------|------|------|
| `state` | chain_0[0:4] | FSM 状态 (5-bit) |
| `row_cnt` | chain_0[5:12] | 行计数器 |
| `tile_cnt` | chain_0[13:16] | tile 计数器 |
| `cycle_cnt` | chain_1 | 周期计数器 32-bit |

## 3. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常控制 |
| Scan | test_mode=1 | Scan 测试 |

## 4. 故障覆盖率

| 模型 | 目标 |
|------|------|
| Stuck-at | >= 95% |
| Transition | >= 90% |
