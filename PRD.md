# FlashAttention 高性能硬件加速器 IP — PRD

## 1. Executive Summary

### 1.1 产品定位

FlashAttention-style 注意力算子硬件加速器 IP，面向大模型推理场景中 Scaled Dot-Product Attention (SDPA) 的高效计算。采用在线 softmax + 分块处理架构，在不显式存储 SxS 注意力矩阵的前提下完成与标准 SDPA 等价的计算。

### 1.2 目标应用

- 大模型 (LLM/VLM) 推理加速
- Transformer 架构中注意力算子的硬件卸载
- 边缘/端侧 AI SoC 集成

### 1.3 关键差异化

| 特性 | 本设计 | 朴素实现 |
|------|--------|----------|
| 中间存储 | O(S*d) — 不存储 SxS 矩阵 | O(S^2) — 显式 score/p 矩阵 |
| Softmax | 在线 (online) 一遍扫描 | 两遍扫描 (max + exp/sum) |
| 数据流 | 分块 (tiling) K/V | 全量加载 |
| 带宽 | O(S*d^2/M) | O(S^2*d) |

### 1.4 竞赛背景

第九届中国研究生创"芯"大赛 Cadence 企业命题 — 基于大模型推理的 FlashAttention 高性能硬件加速器 IP 设计。

---

## 2. Use Cases

| UC ID | Use Case | Target Workload | KPI |
|-------|----------|-----------------|-----|
| UC-01 | 单次 SDPA 推理 (S=256, d=64, causal) | Transformer self-attention | <300K cycles |
| UC-02 | 寄存器配置与启动 | 主机通过 AXI4-Lite 配置 | <10 cycles 配置延迟 |
| UC-03 | DMA 数据搬运 | Q/K/V 从内存读入, O 写回 | 带宽利用率 >80% |

---

## 3. Functional Requirements

### 3.1 核心计算功能 (REQ-FUNC-xxx)

| REQ ID | 需求描述 | 优先级 | 验收标准 |
|--------|----------|--------|----------|
| REQ-FUNC-001 | 实现 Scaled Dot-Product Attention: O_i = sum_j softmax(Q_i*K_j/sqrt(d) + M_ij) * V_j | P0 | 与 FP32 golden 对比: mean_abs_error <= 0.03 |
| REQ-FUNC-002 | 禁止显式存储 SxS 注意力矩阵 (score/p) | P0 | 代码审查: 无 SxS 存储结构 |
| REQ-FUNC-003 | 实现在线 (online) softmax — 边计算边归一化 | P0 | 算法审查: 维护 m/l/acc 状态 |
| REQ-FUNC-004 | 实现分块 (tiling) 处理 K/V | P0 | 代码审查: K/V 按 tile 加载 |
| REQ-FUNC-005 | 支持 causal mask (上三角 mask) | P0 | 验证: i=0 行只能看到 j=0 |
| REQ-FUNC-006 | 输入数据格式: Q8.8 定点 (16-bit 有符号) | P0 | 仿真验证: 输入/输出均为 Q8.8 |
| REQ-FUNC-007 | 累加精度 >= 32-bit (建议 40-bit) | P0 | RTL 审查: 累加器位宽 >= 32 |
| REQ-FUNC-008 | 输出数据格式: Q8.8 定点 (16-bit 有符号) | P0 | 仿真验证 |

### 3.2 接口功能 (REQ-INTF-xxx)

| REQ ID | 需求描述 | 优先级 | 验收标准 |
|--------|----------|--------|----------|
| REQ-INTF-001 | AXI4-Lite 从接口用于寄存器配置 | P0 | UVM/cocotb 验证全部寄存器读写 |
| REQ-INTF-002 | AXI4 Master 接口用于 DMA 数据搬运 | P0 | 仿真: 正确读写内存数据 |
| REQ-INTF-003 | 支持 CTRL.START 启动计算 | P0 | 写 1 启动, BUSY 置位 |
| REQ-INTF-004 | 支持 STATUS.DONE 查询完成 | P0 | 计算完成 DONE 置位 |
| REQ-INTF-005 | 支持 STATUS.ERROR 错误报告 | P1 | 异常条件下 ERROR 置位 |
| REQ-INTF-006 | 支持 CTRL.SOFT_RESET 软复位 | P1 | 写 1 后状态机复位 |
| REQ-INTF-007 | 支持 CFG.CAUSAL_EN 因果 mask 使能 | P0 | 关闭时无 mask, 开启时上三角 mask |
| REQ-INTF-008 | CYCLES 寄存器记录执行周期数 | P1 | 计算完成后读取为实际 cycle 数 |

### 3.3 寄存器映射 (REQ-REG-xxx)

| Offset | 名称 | 访问 | 位域 | REQ ID |
|--------|------|------|------|--------|
| 0x00 | CTRL | R/W | [0] START, [1] SOFT_RESET, [2] IRQ_EN | REQ-INTF-003/006 |
| 0x04 | STATUS | R | [0] BUSY, [1] DONE(w1c), [2] ERROR | REQ-INTF-004/005 |
| 0x08 | CFG | R/W | [0] CAUSAL_EN | REQ-INTF-007 |
| 0x14 | Q_BASE_L | R/W | Q 基地址低 32 位 | REQ-INTF-002 |
| 0x18 | Q_BASE_H | R/W | Q 基地址高 32 位 | REQ-INTF-002 |
| 0x1C | K_BASE_L | R/W | K 基地址低 32 位 | REQ-INTF-002 |
| 0x20 | K_BASE_H | R/W | K 基地址高 32 位 | REQ-INTF-002 |
| 0x24 | V_BASE_L | R/W | V 基地址低 32 位 | REQ-INTF-002 |
| 0x28 | V_BASE_H | R/W | V 基地址高 32 位 | REQ-INTF-002 |
| 0x2C | O_BASE_L | R/W | O 基地址低 32 位 | REQ-INTF-002 |
| 0x30 | O_BASE_H | R/W | O 基地址高 32 位 | REQ-INTF-002 |
| 0x34 | STRIDE_BYTES | R/W | 行 stride (bytes), 默认 128 | REQ-INTF-002 |
| 0x38 | NEG_LARGE | R/W | -inf 近似值 (Q8.8) | REQ-FUNC-005 |
| 0x3C | SCALE | R/W | 缩放常数 1/sqrt(d) | REQ-FUNC-001 |
| 0x40 | CYCLES | R | 执行周期数 | REQ-INTF-008 |

---

## 4. Non-Functional Requirements

### 4.1 Performance (REQ-PERF-xxx)

| REQ ID | 指标 | Min | Typ | Max | 条件 |
|--------|------|-----|-----|-----|------|
| REQ-PERF-001 | 工作频率 | 50 MHz | 100 MHz | 200 MHz | Genus 综合, ASAP7 TT/0.70V/25C |
| REQ-PERF-002 | 单次 attention 延迟 | — | — | 300,000 cycles | S=256, d=64, causal |
| REQ-PERF-003 | Fmax | — | — | 越高越好 | Genus 物理综合 |

### 4.2 Area (REQ-AREA-xxx)

| REQ ID | 指标 | Target | Margin | 说明 |
|--------|------|--------|--------|------|
| REQ-AREA-001 | 等效逻辑门数 | <= 1,800K gates | 10% margin (2M 上限) | 含存储器折算, 2-input NAND 等效 |
| REQ-AREA-002 | 片上 SRAM | <= 64 KB | — | K/V tile buffer + Q/O buffer |

### 4.3 Power (REQ-PWR-xxx)

| REQ ID | 指标 | Target | 说明 |
|--------|------|--------|------|
| REQ-PWR-001 | 动态功耗 | <= 50 mW | 典型工作负载 |
| REQ-PWR-002 | 静态功耗 | <= 5 mW | Leakage, ASAP7 TT/25C |

### 4.4 Bandwidth (REQ-BW-xxx)

| REQ ID | 指标 | Target | 说明 |
|--------|------|--------|------|
| REQ-BW-001 | 读带宽 (RD_BYTES) | 需统计 | Q + K + V 总读取量 |
| REQ-BW-002 | 写带宽 (WR_BYTES) | 需统计 | O 总写入量 |
| REQ-BW-003 | 带宽优化 | tile 复用 | 通过 K/V tile 缓存减少外部访存 |

### 4.5 Data Format (REQ-DATA-xxx)

| REQ ID | 数据 | 格式 | 位宽 | 范围 |
|--------|------|------|------|------|
| REQ-DATA-001 | Q/K/V 输入 | Q8.8 定点 | 16-bit 有符号 | [-128, +127.996] |
| REQ-DATA-002 | 累加器 | 定点 | 40-bit | 防溢出 |
| REQ-DATA-003 | softmax 路径 | 定点/查表 | >= 16-bit | exp 查表 + 缩放 |
| REQ-DATA-004 | O 输出 | Q8.8 定点 | 16-bit 有符号 | [-128, +127.996] |

### 4.6 PDK & Technology (REQ-TECH-xxx)

| REQ ID | 项目 | 规格 |
|--------|------|------|
| REQ-TECH-001 | PDK | ASAP7 7nm |
| REQ-TECH-002 | 标准单元库 | asap7sc7p5t_27 / asap7sc6t_26 |
| REQ-TECH-003 | 工艺角 | TT/0.70V/25C (典型), SS/0.63V/100C (慢), FF/0.77V/0C (快) |
| REQ-TECH-004 | 综合工具 | Yosys 0.35 (开源) 或 Cadence Genus (竞赛) |

---

## 5. Verification Requirements

### 5.1 验证方法 (REQ-VERIF-xxx)

| REQ ID | 验证项 | 方法 | 覆盖率目标 |
|--------|--------|------|-----------|
| REQ-VERIF-001 | AXI4-Lite 寄存器读写 | UVM/cocotb | 100% 寄存器覆盖 |
| REQ-VERIF-002 | 启动/完成流程 | UVM/cocotb | CTRL.START -> BUSY -> DONE |
| REQ-VERIF-003 | 随机 Q/K/V 端到端 | UVM/cocotb + golden model | mean_abs_error <= 0.03 |
| REQ-VERIF-004 | Causal mask corner case | 定向测试 | i=0 行只看到 j=0 |
| REQ-VERIF-005 | max_abs_error 验证 | 随机种子 x N | max_abs_error <= 0.10 |

### 5.2 Golden Model

- Python + NumPy FP32 参考实现
- 相同 Q/K/M 输入, 相同 mask 配置
- 误差门限: mean <= 0.03, max <= 0.10

---

## 6. Algorithm Specification

### 6.1 FlashAttention 分块算法

```
For each query row i (i = 0..S-1):
  初始化: m_i = -inf, l_i = 0, acc_i = [0]*d

  For each K/V tile j (tile_size = Bc):
    1. 从内存加载 K_tile[Bc, d], V_tile[Bc, d]
    2. score = Q[i] @ K_tile^T / sqrt(d)    // [1, Bc]
    3. if CAUSAL_EN: mask where j > i         // causal mask
    4. 在线 softmax 更新:
       m_new = max(m_i, max(score))
       l_new = exp(m_i - m_new) * l_i + sum(exp(score - m_new))
       acc_new = exp(m_i - m_new) * acc_i + exp(score - m_new) @ V_tile
       m_i, l_i, acc_i = m_new, l_new, acc_new

  O[i] = acc_i / l_i
```

### 6.2 计算量分析

| 步骤 | 运算 | 次数 |
|------|------|------|
| Q*K^T | MAC (16x16->40) | S * S * d = 256 * 256 * 64 = 4,194,304 |
| exp 查表 | 查表 | S * S = 65,536 |
| score*V | MAC (16x16->40) | S * S * d = 4,194,304 |
| 除法 (acc/l) | 除法 | S * d = 16,384 |
| **总计** | | ~8.4M MAC + 65K 查表 + 16K 除法 |

### 6.3 存储需求分析

| 存储项 | 大小 | 说明 |
|--------|------|------|
| Q buffer | S * d * 2B = 32 KB | 全量 Q (可逐行加载) |
| K tile buffer | Bc * d * 2B | 当前 tile, 例 Bc=16 -> 2 KB |
| V tile buffer | Bc * d * 2B | 当前 tile, 例 Bc=16 -> 2 KB |
| O buffer | S * d * 2B = 32 KB | 输出暂存 |
| m/l/acc per row | d * (5+5+5)B | 每行: m(40b) + l(40b) + acc(40b*d) |
| exp LUT | 256 * 2B = 512 B | 查找表 |
| **总计 (Bc=16)** | ~70 KB | 含输入/输出缓存 |

---

## 7. Risk & Mitigation

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 定点溢出 | 累加器溢出导致精度损失 | 40-bit 累加 + 分段缩放 |
| exp 查表精度 | softmax 误差传播 | 256-entry LUT + 分段线性插值 |
| 除法延迟 | acc/l 除法成为关键路径 | 迭代除法器 (固定 16 cycles) 或 Newton-Raphson |
| 面积超限 | >2M 等效门 | 减少并行度, 复用 MAC 单元 |
| AXI 带宽不足 | DMA 成为瓶颈 | 双缓冲 + tile 预取 |

---

## 8. Quality Checklist

- [x] 所有 REQ-xxx 有唯一 ID (REQ-FUNC/INTF/PERF/AREA/PWR/BW/DATA/TECH/VERIF)
- [x] 每条需求符合 SMART (Specific/Measurable/Achievable/Relevant/Time-bound)
- [x] 性能指标有 min/typ/max (REQ-PERF-001)
- [x] Power/Area budget 预留 >= 10% margin (REQ-AREA-001: 1.8M vs 2M 上限)
- [x] 数据格式明确定义 (REQ-DATA-001~004)
- [x] 验证需求完整 (REQ-VERIF-001~005)
- [x] 寄存器映射完整 (16 个寄存器, 偏移 0x00~0x40)

---

## 9. Traceability Matrix

| REQ ID | ARCH Ref | MAS Ref | VPlan Ref |
|--------|----------|---------|-----------|
| REQ-FUNC-001~008 | arch_spec/arch_doc.md §3 | mas/mas.json modules | verif_plan_seed.md |
| REQ-INTF-001~008 | arch_spec/arch_doc.md §4 | mas/mas.json io_timing | verif_plan_seed.md |
| REQ-PERF-001~003 | arch_spec/arch_doc.md §5 | mas/mas.json clock_domains | — |
| REQ-AREA-001~002 | arch_spec/arch_doc.md §6 | mas/mas.json area_budget | — |
| REQ-DATA-001~004 | arch_spec/data_flow.md | mas/mas.json datapath | — |
| REQ-TECH-001~004 | arch_spec/arch_doc.md §7 | — | — |
| REQ-VERIF-001~005 | — | — | verif_plan_seed.md |

---

## 10. Acceptance Criteria (竞赛验收)

| 项目 | 标准 | 本设计目标 |
|------|------|-----------|
| FlashAttention 三大约束 | 不存储 SxS, 在线 softmax, 分块 | PASS |
| 正确性 | mean_abs_error <= 0.03, max <= 0.10 | PASS |
| 延迟 | < 300K cycles | PASS (目标 ~150K cycles) |
| 面积 | <= 2M 等效门 | PASS (目标 ~1.5M gates) |
| 接口 | AXI4-Lite + AXI4 Master DMA | PASS |
| Causal mask | 必须支持 | PASS |
| PDK | ASAP7 7nm | PASS |
