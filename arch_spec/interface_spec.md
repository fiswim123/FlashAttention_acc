# FlashAttention 加速器 IP — 接口规范

## 1. 顶层端口列表

### 1.1 时钟与复位

| 端口名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| clk | Input | 1 | 系统时钟, 50 MHz |
| rst_n | Input | 1 | 异步复位, 低有效 |

### 1.2 AXI4-Lite 从接口 (寄存器配置)

| 端口名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| s_axil_awaddr | Input | 6 | 写地址 |
| s_axil_awvalid | Input | 1 | 写地址有效 |
| s_axil_awready | Output | 1 | 写地址就绪 |
| s_axil_wdata | Input | 32 | 写数据 |
| s_axil_wstrb | Input | 4 | 写字节选通 |
| s_axil_wvalid | Input | 1 | 写数据有效 |
| s_axil_wready | Output | 1 | 写数据就绪 |
| s_axil_bresp | Output | 2 | 写响应 |
| s_axil_bvalid | Output | 1 | 写响应有效 |
| s_axil_bready | Input | 1 | 写响应就绪 |
| s_axil_araddr | Input | 6 | 读地址 |
| s_axil_arvalid | Input | 1 | 读地址有效 |
| s_axil_arready | Output | 1 | 读地址就绪 |
| s_axil_rdata | Output | 32 | 读数据 |
| s_axil_rresp | Output | 2 | 读响应 |
| s_axil_rvalid | Output | 1 | 读数据有效 |
| s_axil_rready | Input | 1 | 读数据就绪 |

### 1.3 AXI4 Master 接口 (DMA)

| 端口名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| m_axi_awaddr | Output | 64 | 写地址 |
| m_axi_awlen | Output | 8 | 突发长度-1 |
| m_axi_awsize | Output | 3 | 突发大小 |
| m_axi_awburst | Output | 2 | 突发类型 (INCR) |
| m_axi_awvalid | Output | 1 | 写地址有效 |
| m_axi_awready | Input | 1 | 写地址就绪 |
| m_axi_wdata | Output | 128 | 写数据 |
| m_axi_wstrb | Output | 16 | 写字节选通 |
| m_axi_wlast | Output | 1 | 写最后一个 |
| m_axi_wvalid | Output | 1 | 写数据有效 |
| m_axi_wready | Input | 1 | 写数据就绪 |
| m_axi_bresp | Input | 2 | 写响应 |
| m_axi_bvalid | Input | 1 | 写响应有效 |
| m_axi_bready | Output | 1 | 写响应就绪 |
| m_axi_araddr | Output | 64 | 读地址 |
| m_axi_arlen | Output | 8 | 突发长度-1 |
| m_axi_arsize | Output | 3 | 突发大小 |
| m_axi_arburst | Output | 2 | 突发类型 (INCR) |
| m_axi_arvalid | Output | 1 | 读地址有效 |
| m_axi_arready | Input | 1 | 读地址就绪 |
| m_axi_rdata | Input | 128 | 读数据 |
| m_axi_rresp | Input | 2 | 读响应 |
| m_axi_rlast | Input | 1 | 读最后一个 |
| m_axi_rvalid | Input | 1 | 读数据有效 |
| m_axi_rready | Output | 1 | 读数据就绪 |

---

## 2. AXI4-Lite 时序

### 2.1 写事务时序

```
     ___     ___     ___     ___     ___
clk _|   |___|   |___|   |___|   |___|   |___

awaddr  XXXX<ADDR>XXXXXXXXXXXXXXXXXXXXXXXXXXX
awvalid _____/```\____________________________
awready _____________/```\___________________

wdata   XXXX<DATA>XXXXXXXXXXXXXXXXXXXXXXXXXXX
wvalid  _____/```\____________________________
wready  _____________/```\___________________

bresp   XXXXXXXXXXXXXXXX<OKAY>XXXXXXXXXXXXXXXX
bvalid  XXXXXXXXXXXXXXXX/```\________________
bready  ________________/```\________________
```

### 2.2 读事务时序

```
     ___     ___     ___     ___     ___
clk _|   |___|   |___|   |___|   |___|   |___

araddr  XXXX<ADDR>XXXXXXXXXXXXXXXXXXXXXXXXXXX
arvalid _____/```\____________________________
arready _____________/```\___________________

rdata   XXXXXXXXXXXXXXXX<DATA>XXXXXXXXXXXXXXXX
rresp   XXXXXXXXXXXXXXXX<OKAY>XXXXXXXXXXXXXXXX
rvalid  XXXXXXXXXXXXXXXX/```\________________
rready  ________________/```\________________
```

---

## 3. AXI4 Master DMA 时序

### 3.1 读突发时序

```
     ___     ___     ___     ___     ___     ___
clk _|   |___|   |___|   |___|   |___|   |___|   |___

araddr  XXXX<ADDR>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
arlen   XXXX<LEN-1>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
arsize  XXXX<SIZE>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
arburst XXXX<INCR>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
arvalid _____/```\___________________________________
arready _____/```\___________________________________

rdata   XXXXXXXXXXX<DATA0><DATA1>...<DATAn>XXXXXXXXXXX
rlast   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/```\________
rvalid  XXXXXXXXXXX/```\_____________/```\___________
rready  __________________________________________/```
```

### 3.2 写突发时序

```
     ___     ___     ___     ___     ___     ___
clk _|   |___|   |___|   |___|   |___|   |___|   |___

awaddr  XXXX<ADDR>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
awlen   XXXX<LEN-1>XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
awvalid _____/```\___________________________________
awready _____/```\___________________________________

wdata   XXXX<DATA0><DATA1>...<DATAn>XXXXXXXXXXXXXXXXX
wlast   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/```\________
wvalid  _____/```\___/```\___.../```\________________
wready  _____/```\___/```\___.../```\________________

bresp   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX<OKAY>XXXXXXX
bvalid  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/```\________
bready  ________________________________________/```\_
```

---

## 4. DMA 数据布局

### 4.1 内存中 Q/K/V/O 布局

```
Q: row-major [S, d], stride = d * 2B = 128B
   Q[0][0..63] | Q[1][0..63] | ... | Q[255][0..63]

K: row-major [S, d], stride = d * 2B = 128B
   K[0][0..63] | K[1][0..63] | ... | K[255][0..63]

V: row-major [S, d], stride = d * 2B = 128B
   V[0][0..63] | V[1][0..63] | ... | V[255][0..63]

O: row-major [S, d], stride = d * 2B = 128B
   O[0][0..63] | O[1][0..63] | ... | O[255][0..63]
```

### 4.2 DMA 访问模式

| 操作 | 地址计算 | 突发长度 | 说明 |
|------|----------|----------|------|
| Load Q[i] | Q_BASE + i * STRIDE | 8 (128B/16B) | 1 行, 64 元素 |
| Load K tile | K_BASE + j_start * STRIDE | 16 (256B/16B) | Bc=16 行 |
| Load V tile | V_BASE + j_start * STRIDE | 16 (256B/16B) | Bc=16 行 |
| Store O[i] | O_BASE + i * STRIDE | 8 (128B/16B) | 1 行, 64 元素 |
