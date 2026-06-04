---
module: M02
type: verification
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_ctrl 验证计划

## 1. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | 启动流程 (START->BUSY->DONE) | P1 |
| FC-002 | 全部 18 个状态覆盖 | P1 |
| FC-003 | 行循环 0..255 | P1 |
| FC-004 | tile 循环 0..15 | P1 |
| FC-005 | DMA 握手 (Q/K/V/O) | P1 |
| FC-006 | MAC 握手 (QK/SV) | P1 |
| FC-007 | Softmax 握手 | P1 |
| FC-008 | 除法握手 | P1 |
| FC-009 | 双缓冲切换 | P1 |
| FC-010 | 软复位 | P1 |
| FC-011 | 周期计数 | P2 |
| FC-012 | 错误处理 | P2 |

## 2. 断言

| ID | 描述 |
|----|------|
| A-001 | IDLE 时 busy=0 |
| A-002 | DONE 时 done=1 |
| A-003 | row_cnt 在 0..255 范围 |
| A-004 | tile_cnt 在 0..15 范围 |

## 3. 仿真场景

| ID | 名称 | 描述 | 预期 |
|----|------|------|------|
| N-001 | 完整计算 | 256 行 x 16 tiles | done=1, cycle_cnt 正确 |
| N-002 | 单行计算 | 1 行 x 16 tiles | 状态正确流转 |
| N-003 | 软复位 | 计算中 soft_reset | 回到 IDLE |
| B-001 | 第一行第一 tile | 边界条件 | 正确处理 |
| B-002 | 最后一行最后 tile | 边界条件 | 正确触发 DONE |
