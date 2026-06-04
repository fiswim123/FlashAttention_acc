# ADR-002: Exp 实现 — 256-entry LUT + 分段线性插值

## 状态

已接受

## 背景

Softmax 中的 exp 函数是关键计算单元。需要在精度、面积和延迟之间权衡。

## 决策

选择 256-entry 查找表 + 分段线性插值。

## 理由

| 方案 | 精度 | 面积 | 延迟 | 选择 |
|------|------|------|------|------|
| CORDIC | 高 | 大 | 高 | |
| 多项式近似 | 中 | 中 | 中 | |
| LUT (256-entry) | 中 | 小 (512B) | 低 (1 cycle) | |
| LUT + 线性插值 | 高 | 小 (512B) | 低 (2 cycles) | **选择** |

- 256-entry ROM 面积 ~512B，可接受
- 分段线性插值提高精度，延迟仅增加 1 cycle
- 输入范围 [-8, 0]，覆盖典型 softmax 值域

## 实现细节

```
输入: x (Q8.8, 范围 [-8, 0])
index = (x + 8) * 256 / 8 = (x + 8) * 32
frac = (x + 8) * 32 - index
result = LUT[index] + frac * (LUT[index+1] - LUT[index])
```

## 后果

- 需要 256-entry ROM (512B)
- 查表延迟 2 cycles
- 精度满足 mean_abs_error <= 0.03 要求
