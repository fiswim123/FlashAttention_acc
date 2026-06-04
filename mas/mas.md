# FlashAttention 加速器 — MAS 总览

## 1. 设计概述

FlashAttention-style 注意力算子硬件加速器 IP, 面向大模型推理场景中 Scaled Dot-Product Attention 的高效计算。

| 参数 | 值 |
|------|-----|
| 算法 | FlashAttention (online softmax + tiling) |
| 精度 | Q8.8 定点 I/O (16-bit), 40-bit 累加 |
| 序列长度 | S=256 (固定) |
| 头维度 | d=64 (固定) |
| 头数 | 1 (单 head) |
| PDK | ASAP7 7nm |
| 目标频率 | 50 MHz |
| 面积预算 | <= 1.8M gates |
| 功耗预算 | <= 50 mW 动态 |

---

## 2. 模块层次

```
fa_top (M01)
├── fa_ctrl (M02) — 主控制器 FSM
├── fa_dma (M03) — AXI4 Master DMA
├── fa_systolic (M04) — MAC 阵列 16-wide
├── fa_softmax (M05) — 在线 Softmax
├── fa_divider (M06) — 迭代除法器
├── fa_buffer_mgr (M07) — Buffer 管理
└── fa_regfile (M08) — AXI4-Lite 寄存器
```

---

## 3. 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| Tiling Bc | 16 | 片上 buffer ~4KB, 面积友好 |
| Exp 实现 | 256-entry LUT + 插值 | 精度高, 面积 ~1KB, 延迟 2 cycles |
| 除法器 | 迭代 SRT, 固定 16 次 | 面积小, 逻辑最简单 |
| MAC 阵列 | 16-wide 向量 | 简单控制, 面积适中 |
| AXI 数据宽 | 128-bit | 带宽充足 |
| JTAG | 已移除 | 简化设计, scan_enable 引脚访问 |

---

## 4. 接口

| 接口 | 类型 | 协议 | 说明 |
|------|------|------|------|
| axil_s | Slave | AXI4-Lite | 寄存器配置 |
| axi_m | Master | AXI4 | DMA 数据搬运 |
| clk | Input | — | 50 MHz |
| rst_n | Input | — | 异步复位 |

---

## 5. 性能指标

| 指标 | 值 |
|------|-----|
| 总延迟 | ~150K cycles (优化后) |
| DMA 带宽 | 128-bit @ 50 MHz = 800 MB/s |
| MAC 吞吐 | 16 MAC/cycle |

---

## 6. 文件列表

| 文件 | 说明 |
|------|------|
| mas.json | MAS JSON (schema-valid) |
| mas.md | 本文件 (总览) |
| verif_plan_seed.md | 验证计划种子 |
| dft_plan_seed.md | DFT 计划种子 |
| plan.md | 实现计划 |
| module_tree.md | 模块树 |
| M01_fa_top/ | 顶层封装 |
| M02_fa_ctrl/ | 主控制器 |
| M03_fa_dma/ | DMA 引擎 |
| M04_fa_systolic/ | MAC 阵列 |
| M05_fa_softmax/ | Softmax |
| M06_fa_divider/ | 除法器 |
| M07_fa_buffer_mgr/ | Buffer 管理 |
| M08_fa_regfile/ | 寄存器文件 |
