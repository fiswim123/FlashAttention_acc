---
module: M06
type: DFT
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_divider 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%

## 2. 扫描链配置

| 链 ID | 长度 | 时钟域 | 用途 |
|--------|------|--------|------|
| `chain_6` | ~1500 | clk_domain | divider + softmax |

### 扫描寄存器映射

| 寄存器 | 位置 | 功能 |
|--------|------|------|
| `state` | chain_6 (softmax 后段) | FSM |
| `remainder_reg` | chain_6 | 40-bit 余数 |
| `quotient_reg` | chain_6 | 16-bit 商 |
| `iter_cnt` | chain_6 | 4-bit 迭代计数 |

## 3. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常除法 |
| Scan | test_mode=1 | Scan 测试 |

## 4. 故障覆盖率

| 模型 | 目标 |
|------|------|
| Stuck-at | >= 95% |
| Transition | >= 90% |
