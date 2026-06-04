---
module: M08
type: DFT
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_regfile 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%

## 2. 扫描链配置

| 链 ID | 长度 | 时钟域 | 用途 |
|--------|------|--------|------|
| `chain_7` | ~1000 | clk_domain | regfile + buffer_mgr |

### 扫描寄存器映射

| 寄存器 | 位置 | 功能 |
|--------|------|------|
| `reg_array[0..15]` | chain_7[0:511] | 16x32-bit 寄存器 |
| `axil_wr_state` | chain_7[512:513] | 写 FSM |
| `axil_rd_state` | chain_7[514:515] | 读 FSM |

## 3. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常 AXI 访问 |
| Scan | test_mode=1 | Scan 测试 |

## 4. 故障覆盖率

| 模型 | 目标 |
|------|------|
| Stuck-at | >= 95% |
| Transition | >= 90% |
