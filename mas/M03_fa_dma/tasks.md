---
module: M03
type: tasks
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_dma 实现任务列表

- 总任务数: 10
- 预估工作量: 24 hours

## Phase 1: RTL 设计 (16 hours)

- [ ] 实现 AXI4 Master 接口 (AR/R/AW/W/B 通道)
- [ ] 实现 dma_fsm (7 状态)
- [ ] 实现地址生成器 (Q/K/V/O 地址计算)
- [ ] 实现突发控制 (burst 长度, wlast)
- [ ] 实现数据缓冲 (128-bit)
- [ ] 实现 DMA 命令解码

## Phase 2: 功能验证 (6 hours)

- [ ] TC-001: Q 加载 (8 beat)
- [ ] TC-002: K/V 加载 (16 beat)
- [ ] TC-003: O 写回 (8 beat)
- [ ] TC-004: AXI4 协议合规

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 综合

## Phase 4: DFT (0.5 hours)

- [ ] 扫描链配置 (chain_2, chain_3)
