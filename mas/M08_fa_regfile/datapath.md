---
module: M08
type: datapath
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_regfile 数据通路设计

## 1. 概述
AXI4-Lite 从接口到 16 个 32-bit 寄存器的数据通路。

## 2. 模块框图

```mermaid
graph TB
    subgraph AXI4Lite_Slave
        AW[awaddr 6b]
        W[wdata 32b]
        AR[araddr 6b]
    end

    subgraph Decode
        DEC[addr_decode: 6b -> 16 sel]
    end

    subgraph RegArray
        R0[CTRL 32b]
        R1[STATUS 32b]
        R2[CFG 32b]
        R3[Q_BASE_L 32b]
        R4[Q_BASE_H 32b]
        R5-14[...]
        R15[CYCLES 32b]
    end

    subgraph WriteProtect
        WP[wr_protect: BUSY && addr!=STATUS]
    end

    AW --> DEC
    AR --> DEC
    DEC --> WP
    WP --> R0
    WP --> R1
    W --> R0
    W --> R1
    R0 --> RDATA[rdata 32b]
    R1 --> RDATA
```

## 3. 数据处理

| 操作 | 路径 | 延迟 |
|------|------|------|
| 写 | awaddr -> decode -> reg_write | 2 cycles |
| 读 | araddr -> decode -> reg_read -> rdata | 2 cycles |

## 4. W1C 处理

| 寄存器 | W1C 位 | 说明 |
|--------|--------|------|
| STATUS[1] | DONE | 写 1 清零 |
| STATUS[2] | ERROR | 写 1 清零 |

## 5. Self-clearing 位

| 寄存器 | 位 | 说明 |
|--------|-----|------|
| CTRL[0] | START | 写 1 后硬件自动清零 |
| CTRL[1] | SOFT_RESET | 写 1 后硬件自动清零 |
