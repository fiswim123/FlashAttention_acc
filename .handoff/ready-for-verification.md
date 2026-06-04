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
| rtl/fa_regfile.sv | 607fa00f5afb0916 | AXI4-Lite 寄存器文件 (wstrb byte-lane writes) |
| rtl/fa_buffer_mgr.sv | 8ce3ba1d8ab4b8e1 | Buffer 管理器 (新增 running stats 端口) |
| rtl/fa_divider.sv | fec27c10163408ed | 恢复式除法器 (Q8.8 输出, 48-bit) |
| rtl/fa_softmax.sv | 1a429643ed0e3c52 | Softmax 单元 (未修改) |
| rtl/fa_systolic.sv | 37d79712357968ff | MAC 阵列 (pipeline flush 修复) |
| rtl/fa_dma.sv | ea5dcea3418cdb4f | DMA 引擎 (未修改) |
| rtl/fa_ctrl.sv | 9b2ea641fc56fb13 | 主控制器 FSM (新增 DIV_NEXT/O_WRITE 状态) |
| rtl/fa_top.sv | 9a613a423149c729 | 顶层封装 (所有 TODO 连接已修复) |
| rtl/file_list.f | 32322e21f291e3a3 | 拓扑序文件列表 (未修改) |

## Lint 结果

| 项目 | 值 |
|------|-----|
| 工具 | Verilator 5.032 |
| 错误数 | 0 |
| 警告数 | 30 |
| 警告类型 | UNUSEDSIGNAL(15), WIDTHEXPAND(13), UNUSEDPARAM(1), PINCONNECTEMPTY(1) |
| 迭代次数 | 4 (fix_iter 1/3, global_fix_iter 1/10) |

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

## rtl-needs-fix 修复清单

### 1. fa_top (HIGH) -- 6 TODO 连接 [已修复]
- softmax m_old/l_old 已连接到 buffer_mgr running stats 寄存器
- softmax m_new/l_new/correction 已连接回 buffer_mgr 更新 running stats
- divider divisor 已连接到 softmax l_new
- divider quotient 通过 256-bit 累加器连接到 O buffer 写路径
- causal_mask 已实现 tile-aware 逻辑 (tile_above/tile_below/diagonal)

### 2. fa_divider (MEDIUM) -- bit_pos 溢出 [已修复]
- 完全重写: 48-bit 恢复式除法, dividend<<8 产生 Q8.40
- 5-bit iter_cnt/bit_pos 防止溢出
- 48-bit divisor_shifted mux 覆盖 bit_pos 0..23
- 输出 Q8.8 (16-bit) from Q8.32 / Q8.32

### 3. fa_systolic (LOW) -- pipeline off-by-one [已修复]
- 新增 MAC_FLUSH 状态 (2 周期排空 pipeline)
- 累加器门控: 仅在 elem_cnt >= 2 时累加 (跳过 2 周期 pipeline fill)
- MAC_RUN 在 elem_cnt==63 后进入 MAC_FLUSH, flush_cnt==1 后进入 MAC_DONE

### 4. fa_ctrl (LOW) -- dma_cmd mux 缺少 LOAD_Q [已修复]
- dma_cmd case 已添加显式 LOAD_Q 条目 (2'b00)
- 新增 DIV_NEXT 状态 (循环 16 次 divider 调用)
- 新增 O_WRITE 状态 (DMA 写 O buffer 到外部存储)
- 新增 div_elem_cnt 计数器 (0..15) 和 div_elem_idx 输出

### 5. fa_regfile (INFO) -- wstrb unused [已修复]
- 移除中间 wstrb_mask wire
- 每个寄存器写入使用显式 per-byte-lane if(s_axil_wstrb[n]) 赋值
- 16 个寄存器地址全部实现 byte-lane 写入支持

## MAS drift check

- MAS sha256 值为 architect 提供的 placeholder, 已重新计算实际值并记录在 rtl_artifact.json inputs[] 中
- 后续验证可比对这些实际 sha256 值

## 状态

- fix_iter: 1/3
- global_fix_iter: 1/10
- lint_clean: true (0 errors, 30 warnings)
- ready-for-verification: OPEN
