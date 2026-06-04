---
module: M01
type: FSM
status: complete
parent: none
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_top 状态机设计

## 1. FSM 概述

fa_top 为顶层封装模块, 无自身 FSM。控制逻辑由 fa_ctrl (M02) 承载。

## 2. 复位同步器

```systemverilog
// 异步置位同步释放
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_n_meta <= 1'b0;
        rst_n_sync <= 1'b0;
    end else begin
        rst_n_meta <= 1'b1;
        rst_n_sync <= rst_n_meta;
    end
end
```

## 3. Scan Chain 连接

| Chain | SI | SO | 覆盖模块 |
|-------|----|----|----------|
| 0 | test_si[0] | test_so[0] | fa_ctrl |
| 1 | test_si[1] | test_so[1] | fa_ctrl |
| 2 | test_si[2] | test_so[2] | fa_dma |
| 3 | test_si[3] | test_so[3] | fa_dma |
| 4 | test_si[4] | test_so[4] | fa_systolic |
| 5 | test_si[5] | test_so[5] | fa_systolic |
| 6 | test_si[6] | test_so[6] | fa_softmax + fa_divider |
| 7 | test_si[7] | test_so[7] | fa_buffer_mgr + fa_regfile |
```
