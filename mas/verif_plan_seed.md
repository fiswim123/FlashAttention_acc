# FlashAttention 加速器 — 验证计划种子

## 1. 验证策略

### 1.1 验证层次

| 层次 | 范围 | 方法 | 优先级 |
|------|------|------|--------|
| Unit | 单模块 | cocotb + Verilator | P1 |
| Integration | 模块间交互 | cocotb | P1 |
| System | 端到端 | cocotb + NumPy golden | P1 |
| DFT | 测试结构 | Simulation | P2 |

### 1.2 验证工具

| 工具 | 用途 |
|------|------|
| Verilator 5.012 | RTL 仿真 |
| cocotb | Python 测试框架 |
| NumPy | Golden Model (FP32) |

---

## 2. 模块验证汇总

| 模块 | 测试用例数 | 覆盖率目标 | 关键场景 |
|------|-----------|-----------|----------|
| M01 fa_top | 5 | 100% 端到端 | 端到端计算 |
| M02 fa_ctrl | 5 | 100% FSM | 启动/复位/全状态 |
| M03 fa_dma | 5 | 100% 协议 | AXI4 burst |
| M04 fa_systolic | 5 | 100% 功能 | MAC 精度 |
| M05 fa_softmax | 5 | 100% 功能 | exp 精度 |
| M06 fa_divider | 4 | 100% 功能 | 除法精度 |
| M07 fa_buffer_mgr | 4 | 100% 仲裁 | 双缓冲 |
| M08 fa_regfile | 5 | 100% 协议 | AXI4-Lite |

---

## 3. 精度指标

| 指标 | 目标 | 说明 |
|------|------|------|
| mean_abs_error | <= 0.03 | vs FP32 golden |
| max_abs_error | <= 0.10 | 极端输入 |
| 相对误差 | <= 5% | 典型值 |

---

## 4. 覆盖率目标

| 类型 | 目标 |
|------|------|
| Line Coverage | 100% |
| Branch Coverage | 100% |
| FSM Coverage | 100% |
| Condition Coverage | 95% |

---

## 5. 回归测试

### 5.1 CI (每次 commit)
- 寄存器读写 (< 1s)
- 控制流 (< 5s)
- 小规模计算 (S=16, d=16, < 10s)

### 5.2 Nightly
- 完整功能 (S=256, d=64, < 60s)
- 随机测试 x100 (< 300s)
- 覆盖率收集 (< 120s)

### 5.3 Gate (交付前)
- 全量回归通过
- 覆盖率达标
- 性能 < 300K cycles
