# FlashAttention 加速器 IP — 验证清单

## 1. 验证策略概述

### 1.1 验证层次

| 层次 | 范围 | 方法 | 优先级 |
|------|------|------|--------|
| Unit | 单模块 | cocotb/UVM | P1 |
| Integration | 模块间交互 | cocotb/UVM | P1 |
| System | 端到端 | cocotb + golden model | P1 |
| DFT | 测试结构 | Simulation | P2 |

### 1.2 验证工具

| 工具 | 用途 |
|------|------|
| Verilator | RTL 仿真 |
| cocotb | Python 测试框架 |
| NumPy | Golden Model |
| Yosys | 综合验证 |

---

## 2. 功能验证清单

### 2.1 AXI4-Lite 寄存器验证

| ID | 测试项 | 方法 | 优先级 | 验收标准 |
|----|--------|------|--------|----------|
| V-REG-01 | CTRL 寄存器读写 | Directed | P1 | START/SOFT_RESET/IRQ_EN 正确读写 |
| V-REG-02 | STATUS 寄存器 W1C | Directed | P1 | DONE/ERROR 写 1 清零 |
| V-REG-03 | CFG 寄存器读写 | Directed | P1 | CAUSAL_EN 正确读写 |
| V-REG-04 | 基地址寄存器 | Directed | P1 | Q/K/V/O_BASE 正确读写 |
| V-REG-05 | STRIDE 寄存器 | Directed | P1 | 正确读写, 默认 128 |
| V-REG-06 | NEG_LARGE 寄存器 | Directed | P1 | 正确读写 |
| V-REG-07 | SCALE 寄存器 | Directed | P1 | 正确读写 |
| V-REG-08 | CYCLES 寄存器 | Directed | P1 | 只读, 计数值正确 |
| V-REG-09 | 写保护 | Directed | P1 | BUSY 时写被忽略 |
| V-REG-10 | 保留地址 | Directed | P2 | 读返回 0, 写忽略 |

### 2.2 控制流验证

| ID | 测试项 | 方法 | 优先级 | 验收标准 |
|----|--------|------|--------|----------|
| V-CTRL-01 | 启动流程 | Directed | P1 | START → BUSY → DONE |
| V-CTRL-02 | 软复位 | Directed | P1 | SOFT_RESET 恢复 IDLE |
| V-CTRL-03 | 中断 | Directed | P2 | IRQ_EN + DONE 触发中断 |
| V-CTRL-04 | 错误报告 | Directed | P2 | ERROR 标志正确 |

### 2.3 计算正确性验证

| ID | 测试项 | 方法 | 优先级 | 验收标准 |
|----|--------|------|--------|----------|
| V-CALC-01 | Q*K^T MAC | Directed | P1 | 与 golden 对比 |
| V-CALC-02 | Softmax | Directed | P1 | 与 golden 对比 |
| V-CALC-03 | score*V MAC | Directed | P1 | 与 golden 对比 |
| V-CALC-04 | 除法归一化 | Directed | P1 | 与 golden 对比 |
| V-CALC-05 | Causal mask | Directed | P1 | i=0 行只看到 j=0 |
| V-CALC-06 | 端到端随机 | Random | P1 | mean_abs_error <= 0.03 |
| V-CALC-07 | 端到端边界 | Corner | P2 | max_abs_error <= 0.10 |

### 2.4 DMA 验证

| ID | 测试项 | 方法 | 优先级 | 验收标准 |
|----|--------|------|--------|----------|
| V-DMA-01 | Q 加载 | Directed | P1 | 数据正确读入 |
| V-DMA-02 | K/V tile 加载 | Directed | P1 | 数据正确读入 |
| V-DMA-03 | O 写回 | Directed | P1 | 数据正确写出 |
| V-DMA-04 | 突发传输 | Directed | P1 | AXI4 协议正确 |
| V-DMA-05 | 地址计算 | Directed | P1 | stride 正确应用 |

---

## 3. Golden Model

### 3.1 实现

```python
# Python + NumPy FP32 参考实现
def flash_attention_golden(Q, K, V, causal=False):
    S, d = Q.shape
    scale = 1.0 / math.sqrt(d)
    
    O = np.zeros((S, d), dtype=np.float32)
    
    for i in range(S):
        m_i = -np.inf
        l_i = 0.0
        acc_i = np.zeros(d, dtype=np.float32)
        
        for j in range(S):
            if causal and j > i:
                continue
            
            score = np.dot(Q[i], K[j]) * scale
            
            m_new = max(m_i, score)
            l_new = math.exp(m_i - m_new) * l_i + math.exp(score - m_new)
            acc_new = math.exp(m_i - m_new) * acc_i + math.exp(score - m_new) * V[j]
            
            m_i, l_i, acc_i = m_new, l_new, acc_new
        
        O[i] = acc_i / l_i
    
    return O
```

### 3.2 精度指标

| 指标 | 目标 | 说明 |
|------|------|------|
| mean_abs_error | <= 0.03 | 平均绝对误差 |
| max_abs_error | <= 0.10 | 最大绝对误差 |
| 相对误差 | <= 5% | 典型值 |

---

## 4. 覆盖率目标

### 4.1 代码覆盖率

| 类型 | 目标 |
|------|------|
| Line Coverage | 100% |
| Branch Coverage | 100% |
| Condition Coverage | 95% |
| FSM Coverage | 100% |

### 4.2 功能覆盖率

| Coverpoint | 目标 |
|------------|------|
| 所有状态转换 | 100% |
| 所有寄存器读写 | 100% |
| Causal mask on/off | 100% |
| 边界 S=0,255 | 100% |
| 边界 tile=0,15 | 100% |

---

## 5. 回归测试

### 5.1 CI 测试 (每次 commit)

| 测试 | 时间 | 说明 |
|------|------|------|
| 寄存器读写 | <1s | 快速验证 |
| 控制流 | <5s | 启动/完成流程 |
| 小规模计算 | <10s | S=16, d=16 |

### 5.2 Nightly 测试

| 测试 | 时间 | 说明 |
|------|------|------|
| 完整功能 | <60s | S=256, d=64 |
| 随机测试 x100 | <300s | 多随机种子 |
| 覆盖率收集 | <120s | 生成报告 |

### 5.3 Gate 测试 (交付前)

| 测试 | 说明 |
|------|------|
| 全量回归 | 所有测试通过 |
| 覆盖率检查 | 达标 |
| 性能测试 | <300K cycles |
