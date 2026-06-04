---
module: M07
type: MAS
status: complete
parent: M01
module_type: storage
generated: 2026-06-04T12:00:00+08:00
---

# fa_buffer_mgr 微架构规范

## 1. 模块概述

### 1.1 功能描述
片上 buffer 管理器, 管理 Q/K/V/O 四个 SRAM buffer 的读写访问仲裁。实现 K/V tile 双缓冲以隐藏 DMA 延迟。

### 1.2 模块类型
- 类型: `storage`
- 层级: L1

### 1.3 设计约束
- 面积预算: ~20K gates + 4.5KB SRAM
- 功耗预算: ~2 mW
- 时钟频率: 50 MHz

---

## 2. 接口定义

### 2.1 信号列表

| 信号名 | 方向 | 位宽 | 类型 | 描述 |
|--------|------|------|------|------|
| `clk` | input | 1 | 时钟 | 50 MHz |
| `rst_n` | input | 1 | 控制 | 异步复位, 低有效 |
| `dma_wr_en` | input | 1 | 控制 | DMA 写使能 |
| `dma_wr_addr` | input | 12 | 控制 | DMA 写地址 |
| `dma_wr_data` | input | 128 | 数据 | DMA 写数据 (128-bit) |
| `dma_rd_en` | input | 1 | 控制 | DMA 读使能 |
| `dma_rd_addr` | input | 12 | 控制 | DMA 读地址 |
| `dma_rd_data` | output | 128 | 数据 | DMA 读数据 |
| `mac_q_en` | input | 1 | 控制 | MAC 读 Q 使能 |
| `mac_q_addr` | input | 6 | 控制 | MAC 读 Q 地址 |
| `mac_q_data` | output | 256 | 数据 | MAC 读 Q 数据 (16x16) |
| `mac_k_en` | input | 1 | 控制 | MAC 读 K 使能 |
| `mac_k_addr` | input | 10 | 控制 | MAC 读 K 地址 |
| `mac_k_data` | output | 256 | 数据 | MAC 读 K 数据 |
| `mac_v_en` | input | 1 | 控制 | MAC 读 V 使能 |
| `mac_v_addr` | input | 10 | 控制 | MAC 读 V 地址 |
| `mac_v_data` | output | 256 | 数据 | MAC 读 V 数据 |
| `o_wr_en` | input | 1 | 控制 | O 写使能 |
| `o_wr_addr` | input | 6 | 控制 | O 写地址 |
| `o_wr_data` | input | 256 | 数据 | O 写数据 |
| `o_rd_en` | input | 1 | 控制 | O DMA 读使能 |
| `o_rd_addr` | input | 6 | 控制 | O DMA 读地址 |
| `o_rd_data` | output | 128 | 数据 | O DMA 读数据 |
| `buf_sel` | input | 1 | 控制 | K/V 双缓冲选择 |
| `lut_rd_en` | input | 1 | 控制 | exp LUT 读使能 |
| `lut_rd_addr` | input | 8 | 控制 | exp LUT 地址 |
| `lut_rd_data` | output | 16 | 数据 | exp LUT 数据 |

---

## 3. 数据通路

### 3.1 存储分配

| Buffer | 大小 | 深度 | 宽度 | 用途 |
|--------|------|------|------|------|
| `q_buf` | 128B | 64 | 16-bit | Q 行缓存 |
| `k_buf_a/b` | 2KB x2 | 16x64 | 16-bit | K tile 双缓冲 |
| `v_buf_a/b` | 2KB x2 | 16x64 | 16-bit | V tile 双缓冲 |
| `o_buf` | 128B | 64 | 16-bit | O 行输出 |
| `exp_lut` | 512B | 256 | 16-bit | exp 查找表 (ROM) |

### 3.2 访问仲裁

| 请求源 | 优先级 | 说明 |
|--------|--------|------|
| MAC 读 | 最高 | 计算流水线不能停 |
| DMA 写 | 高 | 数据输入 |
| Softmax 读 | 中 | exp 查表 |
| Divider 读 | 低 | 归一化 |

### 3.3 双缓冲策略
- K/V 各有 A/B 两个 buffer
- buf_sel 选择当前活跃 buffer
- DMA 写入非活跃 buffer, MAC 读取活跃 buffer
- tile 切换时交换 buf_sel

---

## 4. 状态机设计

详见 [FSM.md](./FSM.md)

---

## 5. 时序规格

| 参数 | 数值 | 单位 |
|------|------|------|
| SRAM 读延迟 | 1 | cycle |
| 仲裁延迟 | 0-1 | cycle |
| 双缓冲切换 | 1 | cycle |

---

## 6. 存储资源

详见 3.1 存储分配表

---

## 7. 功耗管理
- Clock Gating: 未使用的 buffer 门控时钟
- SRAM 读写门控: en=0 时禁用

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
| REQ-M07-F01 | Q buffer 读写 | P1 | 128B 正确读写 | 地址越界 | q_buf | TC-M07-01 |
| REQ-M07-F02 | K/V 双缓冲 | P1 | 切换无数据丢失 | 快速切换 | k/v_buf_a/b | TC-M07-02 |
| REQ-M07-F03 | 访问仲裁 | P1 | MAC 优先不被阻塞 | 多源同时访问 | arbiter | TC-M07-03 |
| REQ-M07-F04 | exp LUT ROM | P1 | 256x16b 正确读取 | 地址 0-255 | exp_lut | TC-M07-04 |
| REQ-M07-F05 | O buffer 写回 | P1 | O 数据正确写入 | DMA burst 写 | o_buf | TC-M07-05 |
