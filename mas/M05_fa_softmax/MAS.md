---
module: M05
type: MAS
status: complete
parent: M01
module_type: compute
generated: 2026-06-04T12:00:00+08:00
---

# fa_softmax 微架构规范

## 1. 模块概述

### 1.1 功能描述
在线 (online) softmax 单元, 实现 max 比较、exp 查表 (256-entry ROM + 分段线性插值)、累加和缩放功能。维护运行最大值 m 和运行和 l, 每次新数据到来时修正之前的结果。

### 1.2 模块类型
- 类型: `compute`
- 层级: L1 (fa_top 直接子模块)

### 1.3 设计约束
- 面积预算: ~30K gates
- 功耗预算: ~3 mW (动态)
- 时钟频率: 50 MHz
- 关键路径延迟: ~5ns (ROM 读 + 插值)

---

## 2. 接口定义

### 2.1 信号列表

| 信号名 | 方向 | 位宽 | 类型 | 描述 |
|--------|------|------|------|------|
| `clk` | input | 1 | 时钟 | 主时钟 50 MHz |
| `rst_n` | input | 1 | 控制 | 异步复位, 低有效 |
| `sm_start` | input | 1 | 控制 | 启动 softmax 更新 |
| `sm_done` | output | 1 | 控制 | softmax 完成 |
| `score` | input | 256 (16x16) | 数据 | 当前 tile 的 score 值 (16 个 Q8.8) |
| `score_valid` | input | 1 | 控制 | score 数据有效 |
| `m_old` | input | 40 | 数据 | 旧的最大值 |
| `l_old` | input | 40 | 数据 | 旧的累加和 |
| `m_new` | output | 40 | 数据 | 新的最大值 |
| `l_new` | output | 40 | 数据 | 新的累加和 |
| `correction` | output | 16 | 数据 | 缩放因子 exp(m_old - m_new), Q8.8 |
| `exp_out` | output | 256 (16x16) | 数据 | exp(score - m_new), 16 个 Q8.8 |
| `exp_valid` | output | 1 | 控制 | exp 输出有效 |
| `causal_mask` | input | 16 | 控制 | causal mask 位图 |
| `row_idx` | input | 8 | 控制 | 当前行索引 i |
| `tile_start` | input | 4 | 控制 | 当前 tile 起始 j |

---

## 3. 数据通路

### 3.1 模块框图

```mermaid
graph TB
    subgraph Input
        SCORE[score 16x16b]
        M_OLD[m_old 40b]
        L_OLD[l_old 40b]
    end

    subgraph Max_Compare
        TREE[max tree: 16->1]
        M_NEW[m_new = max(m_old, max_score)]
    end

    subgraph Exp_LUT
        ROM[256-entry ROM]
        INTERP[linear interpolation]
        EXP_OUT[exp(score - m_new)]
    end

    subgraph Correction
        CORR[correction = exp(m_old - m_new)]
        L_NEW[l_new = correction * l_old + sum(exp_out)]
    end

    SCORE --> TREE
    TREE --> M_NEW
    M_OLD --> M_NEW
    M_NEW --> ROM
    SCORE --> ROM
    ROM --> INTERP
    INTERP --> EXP_OUT
    M_OLD --> CORR
    M_NEW --> CORR
    CORR --> L_NEW
    L_OLD --> L_NEW
    EXP_OUT --> L_NEW
```

### 3.2 流水线结构

| 级别 | 操作 | 延迟 (cycles) | 寄存器 |
|------|------|---------------|--------|
| S1 | max 比较 (树形) | 1 | max_reg |
| S2 | exp 查表 (ROM) | 1 | lut_out_reg |
| S3 | 线性插值 | 1 | interp_reg |
| S4 | 累加 (sum + correction) | 1 | sum_reg |

### 3.3 关键路径分析
- 最大延迟路径: score -> max_tree -> ROM addr -> ROM read -> interp -> output
- 延迟值: ~5ns
- 50 MHz 目标: 20ns 周期, 时序余量充足

---

## 4. 状态机设计

详见 [FSM.md](./FSM.md)

---

## 5. 时序规格

### 5.1 时钟域
- 主时钟域: `clk_domain`, 50 MHz

### 5.2 时序约束

| 参数 | 数值 | 单位 |
|------|------|------|
| softmax 更新延迟 | 4 | cycles/tile |
| 16 元素并行处理 | 4 | cycles/tile |

---

## 6. 存储资源

### 6.1 存储器实例

| 名称 | 类型 | 深度 | 宽度 | 端口数 |
|------|------|------|------|--------|
| `exp_lut` | ROM | 256 | 16 (Q8.8) | 1 (读) |

### 6.2 寄存器定义

| 寄存器 | 位宽 | 类型 | 复位值 | 描述 |
|--------|------|------|--------|------|
| `m_reg` | 40 | R/W | 0x8000000000 (-inf) | 运行最大值 |
| `l_reg` | 40 | R/W | 0 | 运行累加和 |

---

## 7. 功耗管理

### 7.1 电源域
- 所属电源域: `VDD_CORE`, 0.70V

### 7.2 低功耗策略
- Clock Gating: sm_start=0 时门控
- ROM 读门控: score_valid=0 时禁用 ROM 访问

---

## 8. 验证要点

详见 [verification.md](./verification.md)

---

## 9. DFT 方案

详见 [DFT.md](./DFT.md)

---

## 10. 实现任务

详见 [tasks.md](./tasks.md)

---

## 11. 需求追踪矩阵

| REQ_ID | 需求描述 | 优先级 | 验收标准 | 边界条件 | RTL 组件 | 测试用例 |
|--------|---------|--------|---------|---------|---------|---------|
| REQ-M05-F01 | 在线 max 更新 | P1 | m_new = max(m_old, max(score)) | m_old=-inf 初始 | max_comparator | TC-M05-01 |
| REQ-M05-F02 | exp 查表 | P1 | exp 精度误差 <=1% | 输入 [-8,0] 范围 | exp_lut | TC-M05-02 |
| REQ-M05-F03 | 分段线性插值 | P1 | 插值误差 <=0.5% | 256 段边界 | linear_interp | TC-M05-03 |
| REQ-M05-F04 | 累加和更新 | P1 | l_new = correction*l_old + sum(exp) | l_old=0 初始 | sum_accumulator | TC-M05-04 |
| REQ-M05-F05 | correction 计算 | P1 | correction = exp(m_old - m_new) | m_old==m_new 时 =1.0 | scale_multiplier | TC-M05-05 |
| REQ-M05-F06 | causal mask 支持 | P1 | j > i 位置 score 赋 -inf | j_start > i 全 tile 跳过 | mask_logic | TC-M05-06 |
