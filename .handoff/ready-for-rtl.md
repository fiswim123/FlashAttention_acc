# Handoff: ready-for-rtl

## 设计信息

| 项目 | 内容 |
|------|------|
| 设计名 | flashattention |
| 顶层模块 | fa_top |
| 目标频率 | 50 MHz |
| PDK | ASAP7 7nm |
| AXI 数据宽 | 128-bit |
| 除法器迭代 | 固定 16 次 |
| JTAG | 已移除 (scan_enable 引脚访问) |

## 产物清单

| 路径 | 说明 |
|------|------|
| designs/flashattention/PRD.md | 产品需求文档 |
| designs/flashattention/arch_spec/*.md | 架构规范 (12 文件) |
| designs/flashattention/ADR/*.md | 设计决策记录 (5 文件) |
| designs/flashattention/mas/mas.json | MAS JSON (schema-valid) |
| designs/flashattention/mas/mas.md | MAS 总览 |
| designs/flashattention/mas/module_tree.md | 模块树 |
| designs/flashattention/mas/plan.md | 实现计划 |
| designs/flashattention/mas/verif_plan_seed.md | 验证计划种子 |
| designs/flashattention/mas/dft_plan_seed.md | DFT 计划种子 |
| designs/flashattention/mas/M01_fa_top/ | 顶层封装 (6 文件) |
| designs/flashattention/mas/M02_fa_ctrl/ | 主控制器 (6 文件) |
| designs/flashattention/mas/M03_fa_dma/ | DMA 引擎 (6 文件) |
| designs/flashattention/mas/M04_fa_systolic/ | MAC 阵列 (6 文件) |
| designs/flashattention/mas/M05_fa_softmax/ | Softmax (6 文件) |
| designs/flashattention/mas/M06_fa_divider/ | 除法器 (6 文件) |
| designs/flashattention/mas/M07_fa_buffer_mgr/ | Buffer 管理 (6 文件) |
| designs/flashattention/mas/M08_fa_regfile/ | 寄存器文件 (6 文件) |

## 模块汇总

| 模块 | 类型 | 面积估算 | 功能 |
|------|------|----------|------|
| fa_top | io | 封装 | 顶层例化 |
| fa_ctrl | compute | ~5K gates | 主 FSM, 18 状态 |
| fa_dma | io | ~15K gates | AXI4 Master DMA |
| fa_systolic | compute | ~200K gates | 16-wide MAC |
| fa_softmax | compute | ~30K gates | 在线 softmax |
| fa_divider | compute | ~10K gates | SRT 除法器 |
| fa_buffer_mgr | storage | ~20K gates + 4.5KB | Buffer 管理 |
| fa_regfile | io | ~10K gates | AXI4-Lite 寄存器 |

## KPIs

| KPI | 值 |
|-----|-----|
| 目标频率 | 50 MHz |
| 面积预算 | <= 1.8M gates (估算 ~500K) |
| 功耗预算 | <= 50 mW (估算 ~22 mW) |
| 延迟目标 | < 300K cycles (估算 ~150K) |

## mas.json schema 验证

- 必填字段: 9/9 存在
- design_name: "flashattention" (匹配 ^[a-z0-9][a-z0-9_-]{0,31}$)
- top_module: "fa_top" (匹配 ^[A-Za-z_][A-Za-z0-9_]{0,63}$)
- target_pdk: "asap7" (enum 通过)
- modules: 8 个模块, 每个有 name + interface
- clock_domains: 1 个 (clk_domain, 50 MHz)
- 注意: inputs[]/outputs[] 的 sha256 为 placeholder, 需要 hash_outputs.py 计算真实值

## 状态

- fix_iter: 0/3
- global_fix_iter: 0/10
- bb-spec-review: 待执行 (需运行后确认 0 HIGH)
