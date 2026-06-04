---
module: M01
type: DFT
status: complete
parent: none
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_top 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%
- Transition Coverage: >= 90%
- Memory BIST: 100% SRAM 覆盖

## 2. Scan Chain 配置

| Chain | 覆盖模块 | 长度 |
|-------|----------|------|
| chain_0 | fa_ctrl | ~500 |
| chain_1 | fa_ctrl | ~500 |
| chain_2 | fa_dma | ~1500 |
| chain_3 | fa_dma | ~1500 |
| chain_4 | fa_systolic | ~2000 |
| chain_5 | fa_systolic | ~2000 |
| chain_6 | fa_softmax + fa_divider | ~1500 |
| chain_7 | fa_buffer_mgr + fa_regfile | ~1000 |

## 3. MBIST 配置

| BIST | 目标 | 算法 |
|------|------|------|
| MBIST-001 | q_buf | March C- |
| MBIST-002 | k_buf_a/b | March C- |
| MBIST-003 | v_buf_a/b | March C- |
| MBIST-004 | o_buf | March C- |
| MBIST-005 | exp_lut | Signature |

## 4. 测试引脚

| 引脚 | 方向 | 说明 |
|------|------|------|
| test_mode[1:0] | Input | 测试模式选择 |
| test_se | Input | Scan Enable |
| test_si[7:0] | Input | Scan Input |
| test_so[7:0] | Output | Scan Output |

## 5. 测试模式

| 模式 | test_mode | 说明 |
|------|-----------|------|
| Functional | 00 | 正常功能 |
| Scan | 01 | Scan 测试 |
| MBIST | 10 | Memory BIST |

## 6. ATPG 向量估算

| 类型 | 数量 |
|------|------|
| Stuck-at | ~10,000 |
| Transition | ~5,000 |
| **总计** | **~15,000** |

## 7. 测试时间估算

```
Scan chains: 8
Chain length: ~1000
Clock period: 20ns (50MHz)
Vectors: 15,000

Test time = 15000 * (1000 + 10) * 20ns / 8 chains
         ≈ 37.8 ms
```
