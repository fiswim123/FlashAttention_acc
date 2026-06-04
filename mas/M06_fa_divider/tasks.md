---
module: M06
type: tasks
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_divider 实现任务列表

- 总任务数: 8
- 预估工作量: 16 hours

## Phase 1: RTL 设计 (10 hours)

- [ ] 实现 SRT 迭代除法器核心
- [ ] 实现 40-bit subtractor
- [ ] 实现 quotient_sel 逻辑
- [ ] 实现 div_fsm (三段式)
- [ ] 实现 divisor=0 检测

## Phase 2: 功能验证 (4 hours)

- [ ] TC-001: 基本除法
- [ ] TC-002: 边界 (0/x, x/0, max/min)

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 综合 + 时序分析

## Phase 4: DFT (0.5 hours)

- [ ] 扫描链配置 (chain_6)
