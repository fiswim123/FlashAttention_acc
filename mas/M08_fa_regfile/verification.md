---
module: M08
type: verification
status: complete
parent: M01
module_type: io
generated: 2026-06-04T12:00:00+08:00
---

# fa_regfile 验证计划

## 1. 功能覆盖点

| ID | 功能 | 优先级 |
|----|------|--------|
| FC-001 | CTRL 读写 (START/SOFT_RESET/IRQ_EN) | P1 |
| FC-002 | STATUS W1C (DONE/ERROR) | P1 |
| FC-003 | CFG 读写 | P1 |
| FC-004 | 基地址寄存器读写 | P1 |
| FC-005 | 写保护 (BUSY) | P1 |
| FC-006 | 保留地址读返回 0 | P2 |
| FC-007 | START self-clear | P1 |
| FC-008 | CYCLES 只读 | P1 |

## 2. 断言

| ID | 描述 |
|----|------|
| A-001 | BUSY 时非 STATUS 写被忽略 |
| A-002 | START 写 1 后自动清零 |
| A-003 | W1C 写 0 不清零 |

## 3. 仿真场景

| ID | 名称 | 描述 | 预期 |
|----|------|------|------|
| N-001 | 全寄存器读写 | 逐一读写所有寄存器 | 值正确 |
| N-002 | W1C 测试 | 写 1 清零 DONE/ERROR | 状态清零 |
| N-003 | 写保护 | BUSY 时写寄存器 | 写被忽略 |
| B-001 | 保留地址 | 读写保留地址 | 读=0, 写忽略 |
| B-002 | START 连续写 | 连续写 START=1 | 每次 self-clear |

## 4. 时序验证

| 检查点 | 预期延迟 |
|--------|---------|
| awvalid -> bvalid | 2 cycles |
| arvalid -> rvalid | 2 cycles |
