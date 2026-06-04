# FlashAttention Hardware Accelerator IP

FlashAttention-style 注意力算子硬件加速器 IP，面向大模型推理场景中 Scaled Dot-Product Attention (SDPA) 的高效计算。

> 研究生创"芯"大赛 Cadence 企业命题 — 基于大模型推理的 FlashAttention 高性能硬件加速器 IP 设计

## 特性

| 项目 | 规格 |
|------|------|
| 算法 | FlashAttention (online softmax + tiling) |
| 序列长度 | S=256 |
| Head 维度 | d=64 |
| 数据格式 | Q8.8 定点 I/O (16-bit), 40-bit 累加 |
| 接口 | AXI4-Lite 控制 + AXI4 128-bit Master DMA |
| Tiling | Bc=16, 片上 buffer ~4.5KB |
| Exp 实现 | 256-entry LUT + 分段线性插值 |
| 除法器 | 迭代 SRT, 固定 16 cycles |
| 目标频率 | 50 MHz |
| PDK | ASAP7 7nm |

## 目录结构

```
├── idea/                    # 赛题需求 + 算法原理
├── PRD.md                   # 产品需求文档 (39 条需求)
├── ADR/                     # 架构决策记录
├── arch_spec/               # 系统架构文档 (10 个)
├── mas/                     # Machine-Adoptable Spec (8 模块 × 6 文件)
│   ├── mas.json             # 机器可读规格
│   └── M01~M08_fa_*/        # 每模块详细设计
├── rtl/                     # 可综合 SystemVerilog RTL
│   ├── fa_top.sv            # 顶层封装
│   ├── fa_ctrl.sv           # 主控制器 FSM (18 状态)
│   ├── fa_dma.sv            # AXI4 Master DMA 引擎
│   ├── fa_systolic.sv       # 16-wide MAC 阵列
│   ├── fa_softmax.sv        # 在线 Softmax 单元
│   ├── fa_divider.sv        # 迭代除法器
│   ├── fa_buffer_mgr.sv     # 片上 Buffer 管理器
│   ├── fa_regfile.sv        # AXI4-Lite 寄存器文件
│   └── file_list.f          # 拓扑排序文件列表
├── verif/                   # 验证计划
├── tb/                      # SystemVerilog 测试平台
├── sim_results/             # 仿真日志
├── docs/                    # 竞赛文档
├── rtl_artifact.json        # RTL 产物 SHA256 校验
├── test_report.json         # 验证报告
└── coverage.json            # 覆盖率报告
```

## 子模块架构

```
fa_top (顶层)
├── fa_ctrl         — 主控制器 FSM
├── fa_dma          — AXI4 Master DMA
├── fa_systolic     — MAC 阵列 16-wide
├── fa_softmax      — 在线 Softmax
├── fa_divider      — 迭代除法器
├── fa_buffer_mgr   — Buffer 管理器
└── fa_regfile      — AXI4-Lite 寄存器文件
```

## FlashAttention 算法

$$O_i = \sum_{j=0}^{S-1} \text{softmax}\left(\frac{Q_i \cdot K_j}{\sqrt{d}} + M_{i,j}\right) V_j$$

核心思想:
1. **禁止存储 S×S 注意力矩阵** — 中间存储 O(S×d)
2. **在线 softmax** — 一遍扫描维护 m/l/acc 状态
3. **分块处理 K/V** — 每次加载 Bc=16 行到片上 buffer

## 寄存器映射

| Offset | 名称 | 说明 |
|--------|------|------|
| 0x00 | CTRL | [0] START, [1] SOFT_RESET, [2] IRQ_EN |
| 0x04 | STATUS | [0] BUSY, [1] DONE(w1c), [2] ERROR |
| 0x08 | CFG | [0] CAUSAL_EN |
| 0x14~0x30 | Q/K/V/O_BASE | 基地址 (低/高 32 位) |
| 0x34 | STRIDE_BYTES | 行 stride (默认 128) |
| 0x38 | NEG_LARGE | -inf 近似值 |
| 0x3C | SCALE | 缩放常数 1/sqrt(d) |
| 0x40 | CYCLES | 执行周期数 |

## 快速开始

```bash
# 使用 Verilator 仿真
source ~/wrk/eda_opensources/eda_env.sh
verilator --cc --exe --build -f rtl/file_list.f tb/tb_fa_top.sv
./obj_dir/Vtb_fa_top

# 使用 Yosys 综合
yosys -p "read_verilog -sv rtl/*.sv; synth -top fa_top"
```

## 验证状态

| 模块 | 测试数 | 通过 | 状态 |
|------|--------|------|------|
| fa_regfile | 32 | 32 | ✅ |
| fa_buffer_mgr | 16 | 16 | ✅ |
| fa_divider | 15 | 15 | ✅ |
| fa_softmax | 11 | 11 | ✅ |
| fa_systolic | 13 | 13 | ✅ |
| fa_ctrl | 28 | 22 | ⚠️ timing |
| fa_dma | 19 | 19 | ✅ |
| fa_top | 15 | 11 | ⚠️ TODO connections |

## License

TBD
