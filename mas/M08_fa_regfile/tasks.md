---
module: M08
type: tasks
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_regfile 实现任务列表

- 总任务数: 8
- 预估工作量: 16 hours

## Phase 1: RTL 设计 (10 hours)

- [ ] 实现 AXI4-Lite 从接口 (写通道 FSM)
- [ ] 实现 AXI4-Lite 从接口 (读通道 FSM)
- [ ] 实现 16 个寄存器阵列
- [ ] 实现地址解码逻辑
- [ ] 实现 W1C 逻辑 (STATUS)
- [ ] 实现 self-clearing 逻辑 (CTRL)
- [ ] 实现写保护逻辑

## Phase 2: 功能验证 (4 hours)

- [ ] TC-001: 全寄存器读写
- [ ] TC-002: W1C + self-clear
- [ ] TC-003: 写保护

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 综合

## Phase 4: DFT (0.5 hours)

- [ ] 扫描链配置 (chain_7)
