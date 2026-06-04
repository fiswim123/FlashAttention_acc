---
module: M03
type: verification
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_dma 验证计划

## 1. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | Q 行加载 | P1 |
| FC-002 | K tile 加载 | P1 |
| FC-003 | V tile 加载 | P1 |
| FC-004 | O 行写回 | P1 |
| FC-005 | AXI4 读突发协议 | P1 |
| FC-006 | AXI4 写突发协议 | P1 |
| FC-007 | 地址计算正确 | P1 |
| FC-008 | back-pressure 处理 | P2 |

## 2. 断言

| ID | 描述 |
|----|------|
| A-001 | AR 通道握手: arvalid && arready 后 arvalid 拉低 |
| A-002 | R 通道: rlast 后 dma_done |
| A-003 | AW 通道握手正确 |
| A-004 | W 通道: wlast 在最后一拍 |
| A-005 | B 通道: bresp==OKAY |

## 3. 仿真场景

| ID | 名称 | 描述 | 预期 |
|----|------|------|------|
| N-001 | Q 加载 | 8 beat burst | 数据正确 |
| N-002 | K 加载 | 16 beat burst | 数据正确 |
| N-003 | O 写回 | 8 beat burst | 数据正确 |
| B-001 | back-pressure | arready 延迟 | 正确等待 |
| B-002 | 地址边界 | 大地址 | 不溢出 |
