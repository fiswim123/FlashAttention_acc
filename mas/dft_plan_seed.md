# FlashAttention 加速器 — DFT 计划种子

## 1. DFT 策略

### 1.1 目标

| 目标 | 指标 |
|------|------|
| Stuck-at Coverage | >= 95% |
| Transition Coverage | >= 90% |
| Memory BIST | 100% SRAM 覆盖 |
| 测试时间 | < 40ms |

### 1.2 DFT 方法

| 方法 | 适用范围 | 说明 |
|------|----------|------|
| Scan Insertion | 全部逻辑 | 标准 scan cell, test_se 访问 |
| Memory BIST | SRAM | March C- 算法 |

> JTAG 已移除, scan chain 通过专用 test_se/test_si/test_so 引脚访问。

---

## 2. Scan Chain 配置

| Chain | 覆盖模块 | 长度 |
|-------|----------|------|
| chain_0 | fa_ctrl | ~500 |
| chain_1 | fa_ctrl | ~500 |
| chain_2 | fa_dma | ~1500 |
| chain_3 | fa_dma | ~1500 |
| chain_4 | fa_systolic | ~2000 |
| chain_5 | fa_systolic | ~2000 |
| chain_6 | fa_softmax + fa_divider | ~1500 |
| chain_7 | fa_buffer_mgr + fa_regfile | ~1000 |

---

## 3. MBIST 配置

| BIST | 目标 | 算法 | 覆盖率 |
|------|------|------|--------|
| MBIST-001 | q_buf | March C- | 100% |
| MBIST-002 | k_buf_a/b | March C- | 100% |
| MBIST-003 | v_buf_a/b | March C- | 100% |
| MBIST-004 | o_buf | March C- | 100% |
| MBIST-005 | exp_lut | Signature | 100% |

---

## 4. 测试引脚

| 引脚 | 方向 | 说明 |
|------|------|------|
| test_mode[1:0] | Input | 测试模式选择 |
| test_se | Input | Scan Enable |
| test_si[7:0] | Input | Scan Input (8 chains) |
| test_so[7:0] | Output | Scan Output (8 chains) |

---

## 5. 测试模式

| 模式 | test_mode | 说明 |
|------|-----------|------|
| Functional | 00 | 正常功能 |
| Scan | 01 | Scan 测试 |
| MBIST | 10 | Memory BIST |

---

## 6. ATPG 向量估算

| 类型 | 数量 |
|------|------|
| Stuck-at | ~10,000 |
| Transition | ~5,000 |
| **总计** | **~15,000** |

---

## 7. 测试时间估算

```
Scan chains: 8
Chain length: ~1000
Clock period: 20ns (50MHz)
Shift cycles: 1000
Capture cycles: 10
Vectors: 15,000

Test time = 15000 * (1000 + 10) * 20ns / 8 chains
         ≈ 37.8 ms
```

---

## 8. DFT 验证清单

| 检查项 | 方法 | 标准 |
|--------|------|------|
| Scan Chain 连接 | Simulation | 无断裂 |
| Scan Shift | Simulation | 数据正确移入/移出 |
| Scan Capture | Simulation | 正确捕获状态 |
| Memory BIST | Simulation | March C- 通过 |
| Coverage | ATPG | >= 95% stuck-at |
