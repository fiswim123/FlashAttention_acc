---
module: M08
type: MAS
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_regfile 微架构规范

## 1. 模块概述

### 1.1 功能描述
AXI4-Lite 从接口 + 16 个 32-bit 配置/状态寄存器。负责接收 CPU 配置命令, 报告加速器状态。

### 1.2 模块类型
- 类型: `io`
- 层级: L1

### 1.3 设计约束
- 面积预算: ~10K gates
- 功耗预算: ~0.5 mW
- 时钟频率: 50 MHz

---

## 2. 接口定义

### 2.1 AXI4-Lite 从接口

| 端口名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `s_axil_awaddr` | Input | 6 | 写地址 |
| `s_axil_awvalid` | Input | 1 | 写地址有效 |
| `s_axil_awready` | Output | 1 | 写地址就绪 |
| `s_axil_wdata` | Input | 32 | 写数据 |
| `s_axil_wstrb` | Input | 4 | 写字节选通 |
| `s_axil_wvalid` | Input | 1 | 写数据有效 |
| `s_axil_wready` | Output | 1 | 写数据就绪 |
| `s_axil_bresp` | Output | 2 | 写响应 |
| `s_axil_bvalid` | Output | 1 | 写响应有效 |
| `s_axil_bready` | Input | 1 | 写响应就绪 |
| `s_axil_araddr` | Input | 6 | 读地址 |
| `s_axil_arvalid` | Input | 1 | 读地址有效 |
| `s_axil_arready` | Output | 1 | 读地址就绪 |
| `s_axil_rdata` | Output | 32 | 读数据 |
| `s_axil_rresp` | Output | 2 | 读响应 |
| `s_axil_rvalid` | Output | 1 | 读数据有效 |
| `s_axil_rready` | Input | 1 | 读数据就绪 |

### 2.2 寄存器接口

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `reg_ctrl` | output | 32 | CTRL 寄存器 |
| `reg_status` | input | 32 | STATUS 寄存器 |
| `reg_cfg` | output | 32 | CFG 寄存器 |
| `reg_q_base_l/h` | output | 32x2 | Q 基地址 |
| `reg_k_base_l/h` | output | 32x2 | K 基地址 |
| `reg_v_base_l/h` | output | 32x2 | V 基地址 |
| `reg_o_base_l/h` | output | 32x2 | O 基地址 |
| `reg_stride` | output | 32 | 行 stride |
| `reg_neg_large` | output | 32 | -inf 近似值 |
| `reg_scale` | output | 32 | 缩放常数 |
| `reg_cycles` | input | 32 | 周期计数 |

---

## 3. 寄存器映射

| Offset | 名称 | 访问 | 复位值 | 说明 |
|--------|------|------|--------|------|
| 0x00 | CTRL | R/W | 0x0000_0000 | START, SOFT_RESET, IRQ_EN |
| 0x04 | STATUS | R/W1C | 0x0000_0000 | BUSY, DONE, ERROR |
| 0x08 | CFG | R/W | 0x0000_0000 | CAUSAL_EN |
| 0x10-0x2C | Q/K/V/O_BASE | R/W | 0 | 64-bit 地址 |
| 0x30 | STRIDE | R/W | 0x80 | 行 stride |
| 0x34 | NEG_LARGE | R/W | 0x8000 | -inf 近似 |
| 0x38 | SCALE | R/W | 0x0020 | 1/sqrt(d) |
| 0x3C | CYCLES | R | 0 | 执行周期数 |

### 3.1 写保护
- BUSY=1 时, 除 STATUS (W1C) 外所有写被忽略

---

## 4. 状态机设计

详见 [FSM.md](./FSM.md)

---

## 5. 时序规格

| 参数 | 数值 | 单位 |
|------|------|------|
| AXI4-Lite 写延迟 | 2 | cycles |
| AXI4-Lite 读延迟 | 2 | cycles |

---

## 6. 存储资源

16 个 32-bit 寄存器 (纯寄存器实现)

---

## 7. 功耗管理
- Clock Gating: 无访问时门控 AXI 接口时钟

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
| REQ-M08-F01 | AXI4-Lite 写事务 | P1 | 正确写入寄存器 | 地址未对齐 | axil_slave | TC-M08-01 |
| REQ-M08-F02 | AXI4-Lite 读事务 | P1 | 正确读取寄存器 | 保留地址返回 0 | axil_slave | TC-M08-02 |
| REQ-M08-F03 | W1C 寄存器 | P1 | DONE/ERROR 写 1 清零 | 写 0 无效 | w1c_logic | TC-M08-03 |
| REQ-M08-F04 | 写保护 | P1 | BUSY 时写被忽略 | STATUS W1C 例外 | decode_logic | TC-M08-04 |
| REQ-M08-F05 | START self-clear | P1 | START 写 1 后自动清零 | 连续写 | ctrl_logic | TC-M08-05 |
