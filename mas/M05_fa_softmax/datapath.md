---
module: M05
type: datapath
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_softmax 数据通路设计

## 1. 数据通路概述

### 1.1 数据流方向
- 输入: score[16] (Q8.8), m_old, l_old (40-bit)
- 处理: max -> exp LUT -> sum -> scale
- 输出: m_new, l_new (40-bit), exp_out[16] (Q8.8), correction (Q8.8)

### 1.2 吞吐规格
- 输入吞吐: 16 elements/cycle
- 处理吞吐: 4 cycles/tile (16 elements)
- 输出吞吐: 1 result/4 cycles

---

## 2. 模块框图

### 2.1 顶层结构 (Mermaid)

```mermaid
graph TB
    subgraph Input
        SCORE[score 16x16b]
        M_OLD[m_old 40b]
        L_OLD[l_old 40b]
    end

    subgraph Max_Stage
        TREE[4-level compare tree: 16->8->4->2->1]
        CMP[compare with m_old]
        M_REG[m_new_reg]
    end

    subgraph Exp_Stage
        ADDR[addr_gen: (score - m_new + 8) * 256/8]
        ROM[exp_lut_rom 256x16b]
        INTERP[linear_interp: LUT[idx] + frac * delta]
        EXP_REG[exp_out_reg 16x16b]
    end

    subgraph Correction_Stage
        EXP_M[exp(m_old - m_new)]
        CORR_REG[correction_reg 16b]
    end

    subgraph Sum_Stage
        SUM_TREE[sum tree: 16->1]
        MUL[correction * l_old]
        ADD[mul_result + sum_result]
        L_REG[l_new_reg 40b]
    end

    SCORE --> TREE
    TREE --> CMP
    M_OLD --> CMP
    CMP --> M_REG
    M_REG --> ADDR
    SCORE --> ADDR
    ADDR --> ROM
    ROM --> INTERP
    INTERP --> EXP_REG

    M_OLD --> EXP_M
    M_REG --> EXP_M
    EXP_M --> CORR_REG

    CORR_REG --> MUL
    L_OLD --> MUL
    EXP_REG --> SUM_TREE
    SUM_TREE --> ADD
    MUL --> ADD
    ADD --> L_REG

    EXP_REG --> OUT_EXP[exp_out]
    CORR_REG --> OUT_CORR[correction]
    M_REG --> OUT_M[m_new]
    L_REG --> OUT_L[l_new]
```

### 2.2 模块实例表

| 模块 | 实例名 | 类型 | 描述 |
|------|--------|------|------|
| `max_tree` | `max_tree` | compare | 4-level 树形比较器 |
| `exp_rom` | `exp_lut` | rom | 256x16b exp 查找表 |
| `linear_interp` | `interp` | compute | 分段线性插值 |
| `sum_tree` | `sum_tree` | adder | 16 输入求和树 |
| `multiplier` | `corr_mul` | compute | correction * l_old |

---

## 3. 流水线结构

### 3.1 流水线级定义

| 级别 | 名称 | 操作 | 延迟 (cycles) | 输入 | 输出 |
|------|------|------|---------------|------|------|
| S1 | `MAX` | 树形 max 比较 | 1 | score[16] | max_score, m_new |
| S2 | `ROM_READ` | ROM 地址计算+读取 | 1 | addr | rom_data |
| S3 | `INTERP` | 线性插值 | 1 | rom_data, frac | exp_out[16] |
| S4 | `SUM_SCALE` | 求和 + correction + 更新 | 1 | exp_out, l_old | l_new |

### 3.2 流水线时序图

```
Cycle:    0    1    2    3    4
S1(MAX): score m_new  --   --   --
S2(ROM):  --  addr  rom_data  --   --
S3(INT):  --   --  interp  exp_out  --
S4(SUM):  --   --   --   sum   l_new
```

---

## 4. 数据处理单元

### 4.1 计算单元

| 单元 | 功能 | 输入位宽 | 输出位宽 | 延迟 |
|------|------|---------|---------|------|
| `max_tree` | 16 输入 max | 16x16 | 16 | 1 cycle |
| `exp_rom` | exp 查表 | 8 (addr) | 16 | 1 cycle |
| `linear_interp` | 插值 | 16+8 | 16 | 1 cycle |
| `sum_tree` | 16 输入求和 | 16x16 | 40 | 1 cycle |
| `multiplier` | correction * l_old | 16x40 | 40 | 1 cycle |

### 4.2 数据格式

| 数据 | 格式 | 位宽 | 范围 |
|------|------|------|------|
| score 元素 | Q8.8 | 16-bit | [-128, +127.996] |
| m_new | Q8.32 | 40-bit | [-128, +127.999] |
| l_new | Q8.32 | 40-bit | [0, +127.999] |
| exp_out | Q8.8 | 16-bit | [0, +1.0] (exp 输入 <=0) |
| correction | Q8.8 | 16-bit | [0, +1.0] |

---

## 5. 关键路径分析

### 5.1 最大延迟路径

```mermaid
graph LR
    A[score_in] --> B[max_tree 4级]
    B --> C[m_new_reg]
    C --> D[addr_gen]
    D --> E[ROM read]
    E --> F[interp]
    F --> G[exp_out_reg]

    linkStyle 0 stroke:red,stroke-width:2px
    linkStyle 1 stroke:red,stroke-width:2px
    linkStyle 2 stroke:red,stroke-width:2px
    linkStyle 3 stroke:red,stroke-width:2px
```

**路径延迟分解**:
| 节点 | 延迟 (ns) | 类型 |
|------|-----------|------|
| max_tree | 2.0 | 组合逻辑 (4 级比较) |
| addr_gen | 1.0 | 减法 + 缩放 |
| ROM read | 1.5 | 存储器读取 |
| interp | 0.5 | 乘法 + 加法 |
| **总计** | **5.0 ns** | - |

### 5.2 时序约束
- 目标频率: 50 MHz (20ns 周期)
- 流水线深度: 4 stages
- 最大单级延迟: ~5ns

---

## 6. 数据缓冲

无外部 FIFO, 内部流水线寄存器。

---

## 7. 控制信号

### 7.1 数据通路控制

| 控制信号 | 来源 | 作用 | 时序 |
|----------|------|------|------|
| `sm_start` | fa_ctrl | 启动 softmax | 脉冲 |
| `causal_mask` | fa_ctrl | mask 位图 | 电平 |
| `m_old`, `l_old` | fa_buffer_mgr | 旧状态输入 | 电平 |
