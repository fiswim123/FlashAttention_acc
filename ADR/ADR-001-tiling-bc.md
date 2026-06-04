# ADR-001: Tiling Bc = 16

## 状态

已接受

## 背景

FlashAttention 算法需要将 K/V 矩阵分块加载到片上存储。Bc (block column) 决定了每个 tile 的行数，直接影响片上 buffer 面积和 DMA 效率。

## 决策

选择 Bc = 16。

## 理由

| Bc | Buffer 大小 | DMA 效率 | 面积 | 选择 |
|----|-------------|----------|------|------|
| 8 | 2 KB | 较低 | 最小 | |
| 16 | 4 KB | 适中 | 适中 | **选择** |
| 32 | 8 KB | 较高 | 较大 | |

- Bc=16 时，K/V tile buffer 共 4KB，面积友好
- DMA 突发长度 16 (256B/16B)，效率可接受
- 面积和性能的良好平衡

## 后果

- 片上 SRAM 需求: ~5KB (K/V tile + Q/O row + LUT)
- DMA 效率: 每次突发 16 拍
- 计算效率: 每 tile 16 行并行处理
