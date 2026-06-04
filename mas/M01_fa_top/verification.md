---
module: M01
type: verification
status: complete
parent: none
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_top 验证计划

## 1. 验证概述
- 端到端验证: Q/K/V 输入 -> O 输出
- Golden Model: NumPy FP32

## 2. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | 端到端计算 (S=256, d=64) | P1 |
| FC-002 | Causal mask 开/关 | P1 |
| FC-003 | AXI4-Lite 配置流程 | P1 |
| FC-004 | DMA 全流程 (Q/K/V load, O store) | P1 |
| FC-005 | 软复位 | P1 |
| FC-006 | 中断 | P2 |
| FC-007 | 错误报告 | P2 |

## 3. 仿真场景

| ID | 名称 | 描述 | 预期 |
|----|------|------|------|
| N-001 | 端到端随机 | 随机 Q/K/V | mean_abs_error <= 0.03 |
| N-002 | Causal mask | causal_en=1 | 正确 mask |
| N-003 | 软复位 | 计算中复位 | 恢复 IDLE |
| B-001 | 全零输入 | Q/K/V 全 0 | O 全 0 |
| B-002 | 边界值 | Q/K/V 极值 | 不溢出 |

## 4. 精度指标

| 指标 | 目标 |
|------|------|
| mean_abs_error | <= 0.03 |
| max_abs_error | <= 0.10 |
| 相对误差 | <= 5% |

## 5. 性能指标

| 指标 | 目标 |
|------|------|
| 总延迟 | < 300K cycles |
| 实际延迟 | ~150K cycles (优化后) |
