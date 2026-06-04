---
module: M01
type: tasks
status: complete
parent: none
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_top 实现任务列表

- 总任务数: 8
- 预估工作量: 8 hours

## Phase 1: RTL 设计 (4 hours)

- [ ] 创建 fa_top.sv 顶层文件
- [ ] 例化 fa_regfile
- [ ] 例化 fa_ctrl
- [ ] 例化 fa_dma
- [ ] 例化 fa_systolic
- [ ] 例化 fa_softmax
- [ ] 例化 fa_divider
- [ ] 例化 fa_buffer_mgr
- [ ] 连接内部信号
- [ ] 实现复位同步器

## Phase 2: 集成验证 (2 hours)

- [ ] 端到端测试 (S=256, d=64)
- [ ] Causal mask 测试

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 顶层综合
- [ ] 面积报告

## Phase 4: DFT (0.5 hours)

- [ ] Scan chain 连接验证
- [ ] MBIST 连接验证
