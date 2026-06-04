---
module: M05
type: DFT
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_softmax 可测性设计方案

## 1. DFT 概述

### 1.1 DFT 目标
- Stuck-at Coverage: >= 95%
- ROM Signature: 100%

### 1.2 DFT 策略
- 结构测试: Scan Insertion
- ROM 测试: Signature Analysis (与 fa_divider 共享 chain_6)

---

## 2. 扫描链设计

### 2.1 扫描链配置

| 链 ID | 长度 | 触发器数 | 时钟域 | 用途 |
|--------|------|---------|--------|------|
| `chain_6` | ~1500 | ~1500 | clk_domain | softmax + divider |

### 2.2 扫描寄存器映射

| 寄存器 | 扫描链位置 | 功能 | 测试访问 |
|--------|-----------|------|----------|
| `state` | chain_6[0:2] | FSM 状态 | scan shift |
| `m_reg` | chain_6[3:42] | max 状态 40-bit | scan shift |
| `l_reg` | chain_6[43:82] | sum 状态 40-bit | scan shift |

---

## 3. 内建自测试 (BIST)

### 3.1 ROM 测试

| 存储器 | 类型 | 测试方法 | 覆盖率 |
|--------|------|----------|--------|
| `exp_lut` | ROM | Signature Analysis | 100% |

---

## 4. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常 softmax |
| Scan | test_mode=1, test_se=1 | Scan 测试 |

---

## 5. 故障模型

| 故障模型 | 目标覆盖率 |
|----------|-----------|
| Stuck-at | >= 95% |
| Transition | >= 90% |

---

## 6. 测试向量估算

| 类型 | 数量 | 说明 |
|------|------|------|
| Stuck-at | ~2000 | 比较器 + LUT + 累加 |
| Transition | ~1000 | 速度相关 |
| **总计** | **~3000** | |
