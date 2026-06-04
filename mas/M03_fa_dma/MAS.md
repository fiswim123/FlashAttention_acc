---
module: M03
type: MAS
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_dma 微架构规范

## 1. 模块概述

### 1.1 功能描述
AXI4 Master DMA 引擎, 负责 Q/K/V 数据从外部内存加载到片上 buffer, 以及 O 数据从片上 buffer 写回外部内存。

### 1.2 模块类型
- 类型: `io`
- 层级: L1

### 1.3 设计约束
- 面积预算: ~15K gates
- 功耗预算: ~2 mW
- 时钟频率: 50 MHz

---

## 2. 接口定义

### 2.1 控制接口

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `clk` | input | 1 | 50 MHz |
| `rst_n` | input | 1 | 异步复位 |
| `dma_start` | input | 1 | 启动 DMA |
| `dma_done` | output | 1 | DMA 完成 |
| `dma_cmd` | input | 2 | 命令: 00=Q, 01=K, 10=V, 11=O |
| `row_cnt` | input | 8 | 行索引 |
| `tile_cnt` | input | 4 | tile 索引 |
| `q_base` | input | 64 | Q 基地址 |
| `k_base` | input | 64 | K 基地址 |
| `v_base` | input | 64 | V 基地址 |
| `o_base` | input | 64 | O 基地址 |
| `stride` | input | 32 | 行 stride (bytes) |

### 2.2 Buffer 接口

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `buf_wr_en` | output | 1 | buffer 写使能 |
| `buf_wr_addr` | output | 12 | buffer 写地址 |
| `buf_wr_data` | output | 128 | buffer 写数据 |
| `buf_rd_en` | output | 1 | buffer 读使能 (O 写回) |
| `buf_rd_addr` | output | 12 | buffer 读地址 |
| `buf_rd_data` | input | 128 | buffer 读数据 |

### 2.3 AXI4 Master 接口

| 端口名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `m_axi_awaddr` | Output | 64 | 写地址 |
| `m_axi_awlen` | Output | 8 | 突发长度-1 |
| `m_axi_awsize` | Output | 3 | 突发大小 |
| `m_axi_awburst` | Output | 2 | 突发类型 (INCR) |
| `m_axi_awvalid` | Output | 1 | 写地址有效 |
| `m_axi_awready` | Input | 1 | 写地址就绪 |
| `m_axi_wdata` | Output | 128 | 写数据 |
| `m_axi_wstrb` | Output | 16 | 写字节选通 |
| `m_axi_wlast` | Output | 1 | 写最后一个 |
| `m_axi_wvalid` | Output | 1 | 写数据有效 |
| `m_axi_wready` | Input | 1 | 写数据就绪 |
| `m_axi_bresp` | Input | 2 | 写响应 |
| `m_axi_bvalid` | Input | 1 | 写响应有效 |
| `m_axi_bready` | Output | 1 | 写响应就绪 |
| `m_axi_araddr` | Output | 64 | 读地址 |
| `m_axi_arlen` | Output | 8 | 突发长度-1 |
| `m_axi_arsize` | Output | 3 | 突发大小 |
| `m_axi_arburst` | Output | 2 | 突发类型 (INCR) |
| `m_axi_arvalid` | Output | 1 | 读地址有效 |
| `m_axi_arready` | Input | 1 | 读地址就绪 |
| `m_axi_rdata` | Input | 128 | 读数据 |
| `m_axi_rresp` | Input | 2 | 读响应 |
| `m_axi_rlast` | Input | 1 | 读最后一个 |
| `m_axi_rvalid` | Input | 1 | 读数据有效 |
| `m_axi_rready` | Output | 1 | 读数据就绪 |

---

## 3. 数据通路

### 3.1 地址计算

| 操作 | 地址公式 | 突发长度 |
|------|----------|----------|
| Load Q[i] | q_base + row_cnt * stride | 8 (128B/16B) |
| Load K tile | k_base + tile_cnt * Bc * stride | 16 (256B/16B) |
| Load V tile | v_base + tile_cnt * Bc * stride | 16 (256B/16B) |
| Store O[i] | o_base + row_cnt * stride | 8 (128B/16B) |

### 3.2 突发配置

| 参数 | 值 | 说明 |
|------|-----|------|
| DATA_WIDTH | 128 bit | AXI4 数据宽度 |
| MAX_BURST | 16 | AXI4 最大突发长度 |
| BURST_TYPE | INCR | 增量突发 |

---

## 4. 状态机设计

详见 [FSM.md](./FSM.md)

---

## 5. 时序规格

| 参数 | 数值 | 单位 |
|------|------|------|
| Q 加载延迟 | ~128 | cycles (8 bursts) |
| K/V 加载延迟 | ~256 | cycles (16 bursts) |
| O 写回延迟 | ~128 | cycles |

---

## 6. 功耗管理
- Clock Gating: dma_start=0 时门控

---

## 7. 验证要点

详见 [verification.md](./verification.md)

---

## 8. DFT 方案

详见 [DFT.md](./DFT.md)

---

## 9. 实现任务

详见 [tasks.md](./tasks.md)

---

## 10. 需求追踪矩阵

| REQ_ID | 需求描述 | 优先级 | 验收标准 | 边界条件 | RTL 组件 | 测试用例 |
|--------|---------|--------|---------|---------|---------|---------|
| REQ-M03-F01 | Q 行加载 | P1 | 128B 正确读入 | 地址对齐 | addr_gen | TC-M03-01 |
| REQ-M03-F02 | K tile 加载 | P1 | 256B 正确读入 | tile 边界 | addr_gen | TC-M03-02 |
| REQ-M03-F03 | V tile 加载 | P1 | 256B 正确读入 | tile 边界 | addr_gen | TC-M03-03 |
| REQ-M03-F04 | O 行写回 | P1 | 128B 正确写出 | burst 完整 | burst_ctrl | TC-M03-04 |
| REQ-M03-F05 | AXI4 协议合规 | P1 | 握手时序正确 | back-pressure | axi4_master | TC-M03-05 |
| REQ-M03-F06 | 地址计算 | P1 | stride 正确应用 | 大地址 | addr_gen | TC-M03-06 |
