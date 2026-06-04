---
module: M06
type: verification
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_divider 验证计划

## 1. 验证概述
- 精度目标: 商误差 <= 1 LSB (Q8.8)

## 2. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | 基本除法 | P1 |
| FC-002 | 被除数=0 | P1 |
| FC-003 | 除数=0 | P1 |
| FC-004 | 最大值/最小值 | P1 |
| FC-005 | 连续启动 | P2 |

## 3. 断言

| ID | 类型 | 描述 |
|----|------|------|
| A-001 | Concurrent | div_done 在 iter_cnt==15 后 1 cycle |
| A-002 | Concurrent | divisor==0 时 quotient=0 |

## 4. 仿真场景

| ID | 名称 | 输入 | 预期 |
|----|------|------|------|
| N-001 | 64.0/8.0 | dividend=0x4000000000, divisor=0x0800000000 | quotient=0x0800 (8.0) |
| N-002 | 1.0/3.0 | dividend=0x0100000000, divisor=0x0300000000 | quotient~0x0055 (0.332) |
| B-001 | 0/x | dividend=0 | quotient=0 |
| B-002 | x/0 | divisor=0 | quotient=0, div_done 立即 |

## 5. 精度指标

| 指标 | 目标 |
|------|------|
| 绝对误差 | <= 1 LSB (0.00390625) |
| 相对误差 | <= 0.5% |
