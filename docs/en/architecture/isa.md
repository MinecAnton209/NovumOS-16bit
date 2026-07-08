# Instruction Set Architecture

[← Back to Main](../README.md) | [← Overview](overview.md) | [Registers →](registers.md)

---

## Overview

The NovumOS-16bit CPU uses a hybrid 16/32-bit instruction format with 4-bit opcodes. Instructions are divided into **simple** (one opcode = one command) and **group** (one opcode = multiple commands, sub-decoded by Mode/Size bits).

---

## Instruction Formats

### 16-bit Format

```
┌─────────┬─────────┬─────────┬─────────┬──────────┐
│ [15:12] │ [11:10] │  [9:8]  │  [7:6]  │  [5:0]   │
│  Opcode │   Dst   │   Src   │  Mode   │  Unused  │
│  (4)    │  (2)    │  (2)    │  (2)    │  (6)     │
└─────────┴─────────┴─────────┴─────────┴──────────┘
```

### 32-bit Format (with immediate)

```
┌─────────┬─────────┬─────────┬──────────────────────┐
│ [15:12] │ [11:10] │  [9:8]  │        [7:0]         │
│  Opcode │   Dst   │  Mode   │  Unused (high byte)  │
│  (4)    │  (2)    │  (2)    │  (8)                  │
├─────────────────────────────────────────────────────┤
│               [31:16] — Immediate Value              │
└─────────────────────────────────────────────────────┘
```

### Group Command Format (ALU, CondJump, PushPop)

For group commands, bits [11:8] are repurposed as **Mode** and **Size** (4-bit sub-opcode):

```
┌─────────┬──────────────────────────────────────────┐
│ [15:12] │               [11:0]                     │
│  Opcode │  Sub-opcode (Mode+Size) or Dst/Src      │
│  (4)    │  (12)                                    │
└─────────┴──────────────────────────────────────────┘
```

---

## Opcode Map

| Opcode | Mnemonic | Type | Description |
|--------|----------|------|-------------|
| `0x0` | NOP | Simple | No operation |
| `0x1` | MOV | Simple | Move data between registers/memory |
| `0x2` | JMP | Simple | Unconditional jump |
| `0x3` | CALL | Simple | Call subroutine |
| `0x4` | RET | Simple | Return from subroutine |
| `0x5` | INT | Simple | Software interrupt |
| `0x6` | IRET | Simple | Return from interrupt |
| `0x7` | HLT | Simple | Halt CPU |
| `0x8` | IN | Simple | Read from I/O port |
| `0x9` | OUT | Simple | Write to I/O port |
| `0xA` | ALU | Group | ALU operations (16 sub-ops) |
| `0xB` | CondJump | Group | Conditional jumps (6 sub-ops) |
| `0xC` | PushPop | Group | Stack operations (2 sub-ops) |
| `0xD` | — | Reserved | Future use |
| `0xE` | — | Reserved | Future use |
| `0xF` | — | Reserved | Future use |

---

## ALU Group (0xA)

Sub-decoded by Mode[11:10] + Size[9:8]:

| Sub-op | Binary | Mnemonic | Description | Flags |
|--------|--------|----------|-------------|-------|
| 0 | `0000` | ADD | Addition | Z, C, S |
| 1 | `0001` | SUB | Subtraction | Z, C, S |
| 2 | `0010` | CMP | Compare (flags only) | Z, C, S |
| 3 | `0011` | TEST | Test (flags only) | Z |
| 4 | `0100` | ADC | Add with carry | Z, C, S |
| 5 | `0101` | SBB | Subtract with borrow | Z, C, S |
| 6 | `0110` | AND | Bitwise AND | Z |
| 7 | `0111` | OR | Bitwise OR | Z |
| 8 | `1000` | XOR | Bitwise XOR | Z |
| 9 | `1001` | SHL | Shift left | Z, C |
| 10 | `1010` | SHR | Shift right | Z, C |
| 11 | `1011` | INC | Increment | Z, S |
| 12 | `1100` | DEC | Decrement | Z, S |
| 13 | `1101` | NOT | Bitwise NOT | — |
| 14 | `1110` | NEG | Negate (two's complement) | Z, C, S |
| 15 | `1111` | XCHG | Exchange registers | — |

### ALU Instruction Encoding

```
┌─────────┬─────────────────────────────┬─────────┬─────────┬──────────┐
│ [15:12] │          [11:8]             │  [7:6]  │  [5:4]  │  [3:0]   │
│  0xA    │    ALU sub-opcode (4)       │   Dst   │   Src   │  Unused  │
└─────────┴─────────────────────────────┴─────────┴─────────┴──────────┘
```

---

## Conditional Jump Group (0xB)

Sub-decoded by Mode[11:10] + Size[9:8]:

| Sub-op | Binary | Mnemonic | Condition | Description |
|--------|--------|----------|-----------|-------------|
| 0 | `0000` | JZ / JE | Z = 1 | Jump if Zero / Equal |
| 1 | `0001` | JNZ / JNE | Z = 0 | Jump if Not Zero / Not Equal |
| 2 | `0010` | JC / JB | C = 1 | Jump if Carry / Below (unsigned) |
| 3 | `0011` | JNC / JAE | C = 0 | Jump if No Carry / Above or Equal |
| 4 | `0100` | JS | S = 1 | Jump if Sign (negative) |
| 5 | `0101` | JNS | S = 0 | Jump if No Sign (positive) |

### Conditional Jump Encoding

```
┌─────────┬─────────────────────────────┬──────────────────────────────┐
│ [15:12] │          [11:8]             │          [7:0]               │
│  0xB    │    CondJump sub-opcode (4)  │    Unused                    │
├───────────────────────────────────────────────────────────────────────┤
│               [31:16] — Target Address                                │
└───────────────────────────────────────────────────────────────────────┘
```

---

## PUSH/POP Group (0xC)

Sub-decoded by Mode[9:8]:

| Sub-op | Binary | Mnemonic | Description |
|--------|--------|----------|-------------|
| 0 | `00` | PUSH | Push register to stack |
| 1 | `01` | POP | Pop from stack to register |

### PUSH/POP Encoding

```
┌─────────┬─────────┬─────────┬──────────────────────┐
│ [15:12] │ [11:10] │  [9:8]  │        [7:0]         │
│  0xC    │   Reg   │  Mode   │  Unused               │
└─────────┴─────────┴─────────┴──────────────────────┘
```

---

## Simple Instructions

### NOP (0x0)

No operation. Processor continues to next instruction.

### MOV (0x1)

Move data between registers or between register and memory.

| Encoding | Example | Description |
|----------|---------|-------------|
| Reg→Reg | `MOV AX, BX` | Copy BX to AX |
| Imm→Reg | `MOV AX, 0x1234` | Load immediate (32-bit format) |
| [Reg]→Reg | `MOV AX, [BX]` | Load from memory address in BX |
| Reg→[Reg] | `MOV [BX], AX` | Store AX to memory address in BX |
| [Reg+off]→Reg | `MOV AX, [BX+0x10]` | Load from BX + offset |

### JMP (0x2)

Unconditional jump to target address.

### CALL (0x3)

Call subroutine. Pushes return address (IP+4) onto stack, then jumps to target.

### RET (0x4)

Return from subroutine. Pops return address from stack into IP.

### INT (0x5)

Software interrupt. Pushes FLAGS and IP onto stack, loads IP from interrupt vector table.

### IRET (0x6)

Return from interrupt. Pops IP and FLAGS from stack.

### HLT (0x7)

Halt CPU until next interrupt.

### IN (0x8)

Read 16-bit value from I/O port.

### OUT (0x9)

Write 16-bit value to I/O port.

---

## Addressing Modes

| Mode | Binary | Description |
|------|--------|-------------|
| Reg→Reg | `00` | Register to register |
| Immediate | `01` | Immediate value (32-bit format) |
| Indirect | `10` | Memory at address in register |
| Indirect+Offset | `11` | Memory at register + immediate offset |

---

## Flags

| Flag | Bit | Name | Description |
|------|-----|------|-------------|
| Z | 0 | Zero | Set if ALU result is zero |
| C | 1 | Carry | Set if arithmetic produces carry out |
| S | 2 | Sign | Set if result bit 15 is 1 (negative) |
| 3–15 | — | Reserved | Unused |

---

## Register Encoding

| Binary | Register | Name |
|--------|----------|------|
| `00` | AX | Accumulator |
| `01` | BX | Base |
| `10` | CX | Counter |
| `11` | DX | Data |

---

*See [Registers](registers.md) for detailed register specifications.*
