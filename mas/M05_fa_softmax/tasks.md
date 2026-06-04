---
module: M05
type: tasks
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_softmax 实现任务列表

## 1. 任务概述

- 总任务数: 10
- 预估工作量: 24 hours

---

## Phase 1: RTL 设计 (14 hours)

- [ ] 实现 4-level 树形比较器 (16->1)
- [ ] 实现 256-entry exp ROM
- [ ] 实现分段线性插值单元
- [ ] 实现 16 输入求和树
- [ ] 实现 correction 乘法器
- [ ] 实现 softmax_fsm (三段式)
- [ ] 实现 causal mask 逻辑

## Phase 2: 功能验证 (6 hours)

- [ ] 创建 NumPy golden model (exp + softmax)
- [ ] TC-001: 单 tile softmax
- [ ] TC-002: causal mask 测试

## Phase 3: 综合 (3 hours)

- [ ] Yosys 综合 + 时序分析

## Phase 4: DFT (1 hour)

- [ ] 扫描链配置 (chain_6)
