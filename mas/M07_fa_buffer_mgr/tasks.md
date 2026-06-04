---
module: M07
type: tasks
status: complete
parent: M01
module_type: storage
generated: 2026-06-04T12:00:00+08:00
---

# fa_buffer_mgr 实现任务列表

- 总任务数: 10
- 预估工作量: 16 hours

## Phase 1: RTL 设计 (10 hours)

- [ ] 实现 q_buf SRAM 接口
- [ ] 实现 k/v_buf 双缓冲逻辑
- [ ] 实现 o_buf 读写
- [ ] 实现 exp_lut ROM
- [ ] 实现访问仲裁器
- [ ] 实现 buf_sel 双缓冲切换

## Phase 2: 功能验证 (4 hours)

- [ ] TC-001: Q buffer 读写
- [ ] TC-002: K/V 双缓冲切换
- [ ] TC-003: 仲裁优先级

## Phase 3: 综合 (1.5 hours)

- [ ] Yosys 综合

## Phase 4: DFT (0.5 hours)

- [ ] MBIST 配置
