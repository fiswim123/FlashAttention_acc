---
module: M03
type: DFT
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_dma 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%

## 2. 扫描链配置

| 链 ID | 长度 | 时钟域 | 用途 |
|--------|------|--------|------|
| `chain_2` | ~1500 | clk_domain | fa_dma |
| `chain_3` | ~1500 | clk_domain | fa_dma (续) |

### 扫描寄存器映射

| 寄存器 | 位置 | 功能 |
|--------|------|------|
| `state` | chain_2[0:2] | FSM |
| `addr_reg` | chain_2[3:66] | 64-bit 地址 |
| `burst_cnt` | chain_2[67:74] | burst 计数 |
| `data_buf` | chain_3 | 128-bit 数据缓冲 |

## 3. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常 DMA |
| Scan | test_mode=1 | Scan 测试 |

## 4. 故障覆盖率

| 模型 | 目标 |
|------|------|
| Stuck-at | >= 95% |
| Transition | >= 90% |
