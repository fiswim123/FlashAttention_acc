---
module: M02
type: tasks
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_ctrl 实现任务列表

- 总任务数: 10
- 预估工作量: 24 hours

## Phase 1: RTL 设计 (16 hours)

- [ ] 实现 main_fsm (18 状态, 三段式)
- [ ] 实现行计数器 (8-bit, 0..255)
- [ ] 实现 tile 计数器 (4-bit, 0..15)
- [ ] 实现周期计数器 (32-bit)
- [ ] 实现 DMA 控制信号生成
- [ ] 实现 MAC 控制信号生成
- [ ] 实现 Softmax 控制信号生成
- [ ] 实现除法控制信号生成
- [ ] 实现双缓冲切换逻辑
- [ ] 实现软复位逻辑

## Phase 2: 功能验证 (6 hours)

- [ ] TC-001: 启动流程
- [ ] TC-002: 全状态覆盖
- [ ] TC-003: 软复位

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 综合

## Phase 4: DFT (0.5 hours)

- [ ] 扫描链配置 (chain_0, chain_1)
