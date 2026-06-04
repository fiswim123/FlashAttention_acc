---
module: M07
type: DFT
status: complete
parent: M01
module_type: storage
generated: 2026-06-04T12:00:00+08:00
---

# fa_buffer_mgr 可测性设计方案

## 1. DFT 概述
- Stuck-at Coverage: >= 95%
- Memory BIST: 100% SRAM 覆盖

## 2. 扫描链配置

| 链 ID | 长度 | 时钟域 | 用途 |
|--------|------|--------|------|
| `chain_7` | ~1000 | clk_domain | buffer_mgr + regfile |

## 3. Memory BIST

### MBIST 配置

| BIST ID | 目标 | 算法 | 覆盖率 |
|---------|------|------|--------|
| MBIST-001 | q_buf | March C- | 100% |
| MBIST-002 | k_buf_a/b | March C- | 100% |
| MBIST-003 | v_buf_a/b | March C- | 100% |
| MBIST-004 | o_buf | March C- | 100% |
| MBIST-005 | exp_lut | Signature | 100% |

### 控制信号

| 信号 | 方向 | 描述 |
|------|------|------|
| `bist_start` | input | 启动 BIST |
| `bist_done` | output | BIST 完成 |
| `bist_fail` | output | 故障检测 |

## 4. 测试模式

| 模式 | 入口 | 说明 |
|------|------|------|
| Functional | test_mode=0 | 正常访问 |
| Scan | test_mode=1 | Scan 测试 |
| MBIST | test_mode=2 | Memory BIST |
