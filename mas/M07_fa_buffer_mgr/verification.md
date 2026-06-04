---
module: M07
type: verification
status: complete
parent: M01
module_type: storage
generated: 2026-06-04T12:00:00+08:00
---

# fa_buffer_mgr 验证计划

## 1. 验证概述
- 覆盖率: 100% 状态覆盖

## 2. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | Q buffer 读写 | P1 |
| FC-002 | K/V 双缓冲切换 | P1 |
| FC-003 | 仲裁 MAC 优先 | P1 |
| FC-004 | exp LUT 读取 | P1 |
| FC-005 | O buffer 写回 | P1 |
| FC-006 | 多源同时访问 | P1 |
| FC-007 | 地址边界 | P2 |

## 3. 断言

| ID | 描述 |
|----|------|
| A-001 | MAC 读不被 DMA 阻塞 |
| A-002 | buf_sel 切换后数据一致 |

## 4. 仿真场景

| ID | 名称 | 描述 | 预期 |
|----|------|------|------|
| N-001 | Q 加载 + 读取 | DMA 写 Q, MAC 读 Q | 数据一致 |
| N-002 | K 双缓冲 | DMA 写 buf_b, MAC 读 buf_a | 无冲突 |
| N-003 | 仲裁 | MAC+DMA 同时访问 | MAC 优先 |
| B-001 | 地址边界 | 最大地址访问 | 不越界 |
