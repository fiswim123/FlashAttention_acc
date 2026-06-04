---
module: M05
type: verification
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_softmax 验证计划

## 1. 验证概述

### 1.1 验证目标
- 功能覆盖率: 100% 状态/转移覆盖
- 精度: mean_abs_error <= 0.01 (exp LUT)

---

## 2. 功能覆盖点

| 覆盖点 ID | 功能 | 类型 | 优先级 |
|-----------|------|------|--------|
| FC-001 | max 比较正确性 | 功能 | P1 |
| FC-002 | exp 查表精度 | 功能 | P1 |
| FC-003 | 线性插值精度 | 功能 | P1 |
| FC-004 | correction 计算 | 功能 | P1 |
| FC-005 | l_new 累加 | 功能 | P1 |
| FC-006 | causal mask | 功能 | P1 |
| FC-007 | m_old=-inf 初始 | 边界 | P1 |
| FC-008 | score 全 -inf | 边界 | P2 |

---

## 3. 断言定义

| 断言 ID | 类型 | 严重性 | 描述 |
|----------|------|--------|------|
| A-001 | Concurrent | Error | m_new >= m_old (最大值单调递增) |
| A-002 | Concurrent | Error | l_new > 0 (累加和为正) |
| A-003 | Concurrent | Error | correction in [0, 1.0] |
| A-004 | Concurrent | Warning | exp_out 为 0 当 score 被 mask |

---

## 4. 仿真场景

### 4.1 正常场景

| 场景 ID | 名称 | 描述 | 预期 |
|----------|------|------|------|
| N-001 | 单 tile softmax | 16 个 score 值 | 与 NumPy golden 一致 |
| N-002 | 多 tile 更新 | 连续 16 个 tile | m 单调递增, l 正确累加 |
| N-003 | causal mask | j > i 位置 | exp=0, 不影响 sum |

### 4.2 边界场景

| 场景 ID | 名称 | 边界条件 | 预期 |
|----------|------|----------|------|
| B-001 | m_old=-inf | 初始状态 | m_new=max(score), correction=0 |
| B-002 | score 全 -inf | 全 mask | m_new=m_old, l_new=l_old |
| B-003 | score 全 0 | exp(0)=1.0 | l_new = 16.0 + correction*l_old |

### 4.3 异常场景

| 场景 ID | 名称 | 异常类型 | 处理 |
|----------|------|----------|------|
| E-001 | ROM 地址越界 | score-m_new < -8 | clamp 到 0 |
| E-002 | 溢出 | l_new 溢出 | 40-bit 饱和 |

---

## 5. 测试用例

| 用例 ID | 类型 | 场景 | 覆盖点 |
|----------|------|------|--------|
| TC-001 | 功能 | N-001 | FC-001~005 |
| TC-002 | 边界 | B-001 | FC-007 |
| TC-003 | 边界 | B-002 | FC-008 |
| TC-004 | 功能 | N-003 | FC-006 |

---

## 6. 精度指标

| 指标 | 目标 | 说明 |
|------|------|------|
| exp 精度 | <= 1% 相对误差 | 256-entry LUT + 插值 |
| softmax 端到端 | <= 0.03 mean_abs_error | vs FP32 golden |
