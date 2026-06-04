# Handoff: ready-for-verification

## 设计信息

| 项目 | 内容 |
|------|------|
| 设计名 | flashattention |
| 顶层模块 | fa_top |
| 目标频率 | 50 MHz |
| PDK | ASAP7 7nm |
| AXI 数据宽 | 128-bit |

## RTL 产物清单

| 路径 | SHA256 (前 16 位) | 说明 |
|------|-------------------|------|
| rtl/fa_regfile.sv | 69d035c3cf2e34d7 | AXI4-Lite 寄存器文件 |
| rtl/fa_buffer_mgr.sv | 41c78134259c33d3 | Buffer 管理器 |
| rtl/fa_divider.sv | 0f6a370d4ad933d7 | SRT 除法器 |
| rtl/fa_softmax.sv | 1a429643ed0e3c52 | Softmax 单元 |
| rtl/fa_systolic.sv | 67b023c874112ecb | MAC 阵列 |
| rtl/fa_dma.sv | ea5dcea3418cdb4f | DMA 引擎 |
| rtl/fa_ctrl.sv | b894bb29a147d829 | 主控制器 FSM |
| rtl/fa_top.sv | 8974fb1add0db9fe | 顶层封装 |
| rtl/file_list.f | 32322e21f291e3a3 | 拓扑序文件列表 |

## Lint 结果

| 项目 | 值 |
|------|-----|
| 工具 | Verilator 5.032 |
| 错误数 | 0 |
| 警告数 | 13 |
| 警告类型 | PINCONNECTEMPTY(1), WIDTHEXPAND(10), UNUSEDSIGNAL(10), UNUSEDPARAM(1) |
| 迭代次数 | 3/3 |

## 模块依赖 (拓扑序)

```
fa_regfile (leaf)     ─┐
fa_buffer_mgr (leaf)  ─┤
fa_divider (leaf)     ─┤
fa_softmax (leaf)     ─┤
fa_systolic (leaf)    ─┤
fa_dma -> fa_buffer_mgr ─┤
fa_ctrl -> fa_dma,fa_systolic,fa_softmax,fa_divider ─┤
fa_top -> all modules ─┘
```

## 待办 (标记为 TODO 的连接)

1. fa_top: softmax m_old/l_old 连接到 buffer_mgr 状态寄存器
2. fa_top: softmax m_new/l_new/correction 连接到 buffer_mgr
3. fa_top: divider quotient 连接到 O buffer 写路径
4. fa_top: divider divisor 连接到 softmax l_new
5. fa_top: causal_mask 信号完整连接
6. fa_top: scan chain 由综合工具 stitch

## MAS drift check

- MAS sha256 值为 architect 提供的 placeholder, 已重新计算实际值并记录在 rtl_artifact.json inputs[] 中
- 后续验证可比对这些实际 sha256 值

## 状态

- fix_iter: 0/3
- global_fix_iter: 0/10
- lint_clean: true (0 errors, 13 warnings)
- ready-for-verification: OPEN
