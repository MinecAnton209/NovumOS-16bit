# NovumOS-16bit Instruction Encoding

Complete reference for binary instruction formats, opcode maps, and encoding rules.

---

## Table of Contents

1. [Encoding Overview](#encoding-overview)
2. [16-bit Instruction Format](#16-bit-instruction-format)
3. [32-bit Instruction Format](#32-bit-instruction-format)
4. [Opcode Map](#opcode-map)
5. [Operand Encoding](#operand-encoding)
6. [Addressing Modes](#addressing-modes)
7. [NOP Encoding](#nop-encoding)
8. [Encoding Examples](#encoding-examples)
9. [Illegal and Reserved Encodings](#illegal-and-reserved-encodings)

---

## Encoding Overview

The NovumOS-16bit uses a hybrid instruction encoding scheme with two formats:

```mermaid
flowchart LR
    F[Instruction Fetch] --> D{Mode bit analysis}
    D -- "bit 10 = 0" --> S16[16-bit Format]
    D -- "bit 10 = 1" --> S32[32-bit Format]
    S16 --> R[Register-Register]
    S32 --> I[Register-Immediate / Extended]
```

The CPU determines the instruction format by examining the **mode bits** (bits 9–8) of the first word:

- If mode bits indicate register-register operation: **16-bit format**, single word
- If mode bits indicate immediate or extended operation: **32-bit format**, two words

All instructions are fetched on 16-bit word boundaries. The IP always points to the next word to fetch.

---

## 16-bit Instruction Format

The 16-bit format is used for register-to-register operations.

### Bit Field Layout

```mermaid
block-beta
    columns 16
    block:opcode:4
        columns 4
        O3["bit 15"] O2["bit 14"] O1["bit 13"] O0["bit 12"]
    end
    block:dst:2
        columns 2
        D1["bit 11"] D0["bit 10"]
    end
    block:src:2
        columns 2
        S1["bit 9"] S0["bit 8"]
    end
    block:mode:2
        columns 2
        M1["bit 7"] M0["bit 6"]
    end
    block:unused:6
        columns 6
        U5["bit 5"] U4["bit 4"] U3["bit 3"] U2["bit 2"] U1["bit 1"] U0["bit 0"]
    end
```

### Field Descriptions

| Field   | Bits    | Width | Description                                     |
|---------|---------|-------|-------------------------------------------------|
| Opcode  | 15–12   | 4     | Instruction type (0000–1111)                     |
| Dst     | 11–10   | 2     | Destination register encoding (00–11)            |
| Src     | 9–8     | 2     | Source register encoding (00–11)                 |
| Mode    | 7–6     | 2     | Operation mode (see addressing modes)            |
| Unused  | 5–0     | 6     | Reserved, must be zero. Reads as 0.              |

### Hex Notation

A 16-bit instruction is written as four hexadecimal digits: `0xODSMUU` where:
- `O` = opcode nibble (1 hex digit)
- `D` = destination register (1 hex digit, 0–3)
- `S` = source register (1 hex digit, 0–3)
- `M` = mode (1 hex digit, 0–3)
- `UU` = unused bits, always 0

Example: `MOV AX, BX` encodes as `0x0120` (opcode=0, dst=00, src=01, mode=00, unused=0)

---

## 32-bit Instruction Format

The 32-bit format is used for register-immediate operations, where the second word contains a 16-bit immediate value or extended operand.

### Bit Field Layout — First Word

```mermaid
block-beta
    columns 16
    block:opcode:4
        columns 4
        O3["bit 15"] O2["bit 14"] O1["bit 13"] O0["bit 12"]
    end
    block:dst:2
        columns 2
        D1["bit 11"] D0["bit 10"]
    end
    block:mode:2
        columns 2
        M1["bit 9"] M0["bit 8"]
    end
    block:unused1:8
        columns 8
        X7["bit 7"] X6["bit 6"] X5["bit 5"] X4["bit 4"] X3["bit 3"] X2["bit 2"] X1["bit 1"] X0["bit 0"]
    end
```

### Bit Field Layout — Second Word (Immediate)

```mermaid
block-beta
    columns 16
    block:imm16:16
        columns 16
        I15["bit 15"] I14["bit 14"] I13["bit 13"] I12["bit 12"] I11["bit 11"] I10["bit 10"] I9["bit 9"] I8["bit 8"]
        I7["bit 7"] I6["bit 6"] I5["bit 5"] I4["bit 4"] I3["bit 3"] I2["bit 2"] I1["bit 1"] I0["bit 0"]
    end
```

### Field Descriptions — First Word

| Field   | Bits    | Width | Description                                         |
|---------|---------|-------|-----------------------------------------------------|
| Opcode  | 15–12   | 4     | Instruction type (0000–1111)                         |
| Dst     | 11–10   | 2     | Destination register encoding (00–11)                |
| Mode    | 9–8     | 2     | Operation mode — selects immediate encoding          |
| Unused1 | 7–0     | 8     | Reserved, must be zero. Reads as 0.                  |

### Field Descriptions — Second Word

| Field   | Bits    | Width | Description                                         |
|---------|---------|-------|-----------------------------------------------------|
| Imm16   | 15–0    | 16    | 16-bit immediate value or address operand            |

### Hex Notation

A 32-bit instruction occupies two consecutive words:

```
Word 1: 0xOMXX (opcode + dst + mode + 8 unused bits)
Word 2: 0xIIII (16-bit immediate value)
```

Example: `MOV AX, #0x1234` encodes as two words: `0x0080` then `0x1234`
- Word 1: opcode=0 (MOV), dst=00 (AX), mode=01 (immediate), unused=0x00
- Word 2: 0x1234 (the immediate value)

---

## Opcode Map

### Complete Opcode Table

| Opcode (binary) | Opcode (hex) | Mnemonic | Category          | Description              |
|------------------|--------------|----------|-------------------|--------------------------|
| `0000`           | `0x0`        | MOV      | Data Transfer     | Move / Load              |
| `0001`           | `0x1`        | ADD      | Arithmetic        | Integer addition         |
| `0010`           | `0x2`        | SUB      | Arithmetic        | Integer subtraction      |
| `0011`           | `0x3`        | AND      | Logic             | Bitwise AND              |
| `0100`           | `0x4`        | OR       | Logic             | Bitwise OR               |
| `0101`           | `0x5`        | XOR      | Logic             | Bitwise exclusive OR     |
| `0110`           | `0x6`        | SHL      | Shift             | Shift left logical       |
| `0111`           | `0x7`        | SHR      | Shift             | Shift right logical      |
| `1000`           | `0x8`        | JMP      | Control Flow      | Unconditional jump       |
| `1001`           | `0x9`        | JZ       | Control Flow      | Jump if zero             |
| `1010`           | `0xA`        | JNZ      | Control Flow      | Jump if not zero         |
| `1011`           | `0xB`        | IN       | I/O               | Input from port          |
| `1100`           | `0xC`        | OUT      | I/O               | Output to port           |
| `1101`           | `0xD`        | CALL/INT | Control Flow/System | Call subroutine / Interrupt |
| `1110`           | `0xE`        | RET/POP  | Control Flow/Stack | Return / Pop             |
| `1111`           | `0xF`        | HLT      | System            | Halt CPU                 |

### Opcode Map Visualization

```mermaid
flowchart TD
    subgraph "Opcode Map (4-bit)"
        direction LR
        subgraph "0xxx - Data/ALU"
            OP0["0000 MOV"] --- OP1["0001 ADD"]
            OP1 --- OP2["0010 SUB"]
            OP2 --- OP3["0011 AND"]
            OP3 --- OP4["0100 OR"]
            OP4 --- OP5["0101 XOR"]
            OP5 --- OP6["0110 SHL"]
            OP6 --- OP7["0111 SHR"]
        end
        subgraph "1xxx - Control/System"
            OP8["1000 JMP"] --- OP9["1001 JZ"]
            OP9 --- OPA["1010 JNZ"]
            OPA --- OPB["1011 IN"]
            OPB --- OPC["1100 OUT"]
            OPC --- OPD["1101 CALL/INT"]
            OPD --- OPE["1110 RET/POP"]
            OPE --- OPF["1111 HLT"]
        end
    end
```

### Register Encoding

| Encoding | Register | Alias |
|----------|----------|-------|
| `00`     | AX       | Accumulator |
| `01`     | BX       | Base |
| `10`     | CX       | Counter |
| `11`     | DX       | Data |

### Mode Encoding — 16-bit Format

| Mode (bits 9–8) | Value | Meaning |
|------------------|-------|---------|
| `00`             | 0     | Register-register operation |
| `01`             | 1     | Register-indirect (address in src register) |
| `10`             | 2     | Reserved (future use) |
| `11`             | 3     | Reserved (future use) |

### Mode Encoding — 32-bit Format

| Mode (bits 9–8) | Value | Meaning |
|------------------|-------|---------|
| `00`             | 0     | Register-immediate operation (lower 8 bits of instruction unused) |
| `01`             | 1     | Register-immediate with 16-bit immediate in second word |
| `10`             | 2     | Extended addressing (memory indirect) |
| `11`             | 3     | Reserved (future use) |

---

## Operand Encoding

### Register Operands

Registers are encoded as 2-bit fields within the instruction. The encoding applies to both source and destination fields.

```mermaid
block-beta
    columns 2
    block:reg0["00 = AX"]
        columns 1
        A1["Accumulator"]
    end
    block:reg1["01 = BX"]
        columns 1
        B1["Base"]
    end
    block:reg2["10 = CX"]
        columns 1
        C1["Counter"]
    end
    block:reg3["11 = DX"]
        columns 1
        D1["Data"]
    end
```

Register operands can appear in:

- **Dst field** (bits 11–10 in 16-bit, bits 11–10 in 32-bit): Target of the operation
- **Src field** (bits 9–8 in 16-bit): Source of the operation (register-register mode only)

### Immediate Operands

Immediate values are encoded in the second word of 32-bit instructions. The immediate is a full 16-bit unsigned value (0x0000–0xFFFF).

**Immediate representation:**

- Stored in two's complement form for signed interpretation
- Range: 0 to 65535 (unsigned) or −32768 to +32767 (signed)
- The CPU treats the immediate as a raw bit pattern; signedness depends on the instruction

**Immediate instruction flow:**

```mermaid
sequenceDiagram
    participant IP as IP Register
    participant IF as Instruction Fetch
    participant IR as Instruction Register

    IP->>IF: Fetch word at IP
    IF->>IR: First word (opcode + dst + mode)
    Note over IP: IP ← IP + 2
    IP->>IF: Fetch word at IP
    IF->>IR: Second word (immediate value)
    Note over IP: IP ← IP + 2
    Note over IR: Execute with immediate
```

### Memory Indirect Operands

Memory indirect operands use a register as a pointer to a memory location. The effective address is the value held in the specified register.

**Encoding in 16-bit format:**

| Mode | Src field | Effective address |
|------|-----------|-------------------|
| `01` | Register  | Value in register (0–65535) used as memory address |

**Encoding in 32-bit format (mode `10`):**

| Mode | Second word | Effective address |
|------|-------------|-------------------|
| `10` | Immediate   | 16-bit address used directly as memory address |

**Memory access flow:**

```mermaid
flowchart TD
    A[Fetch instruction] --> B{Mode bits?}
    B -- "00: reg-reg" --> C[Use register values directly]
    B -- "01: reg-indirect" --> D[Read address from src register]
    B -- "10: memory" --> E[Read address from immediate word]
    D --> F[Memory access at effective address]
    E --> F
    F --> G[Complete operation]
```

---

## Addressing Modes

The NovumOS-16bit supports three addressing modes, selected by the mode field:

### Mode 0: Register-Register

All operands are in registers. No memory access occurs (except instruction fetch).

**Instruction format:** 16-bit

```
[opcode:4][dst:2][src:2][00:2][unused:6]
```

**Operation:** `R[dst] ← R[dst] op R[src]`

**Examples:**

| Instruction | Opcode | Dst | Src | Mode | Hex |
|-------------|--------|-----|-----|------|-----|
| MOV AX, BX  | 0000   | 00  | 01  | 00   | 0x0120 |
| ADD CX, DX  | 0001   | 10  | 11  | 00   | 0x13A0 |
| XOR AX, AX  | 0101   | 00  | 00  | 00   | 0x5020 |
| AND BX, CX  | 0011   | 01  | 10  | 00   | 0x3260 |

### Mode 1: Register-Indirect (16-bit format)

The source operand is a memory location pointed to by the source register.

**Instruction format:** 16-bit

```
[opcode:4][dst:2][src:2][01:2][unused:6]
```

**Operation:** `R[dst] ← R[dst] op Memory[R[src]]`

**Examples:**

| Instruction | Opcode | Dst | Src | Mode | Hex |
|-------------|--------|-----|-----|------|-----|
| MOV AX, [BX] | 0000  | 00  | 01  | 01   | 0x0124 |
| ADD CX, [DX] | 0001  | 10  | 11  | 01   | 0x13A4 |

### Mode 0: Register-Immediate (32-bit format)

The source operand is an immediate value in the second instruction word.

**Instruction format:** 32-bit

```
Word 1: [opcode:4][dst:2][00:2][unused:8]
Word 2: [immediate:16]
```

**Operation:** `R[dst] ← R[dst] op imm16`

**Examples:**

| Instruction | Opcode | Dst | Mode | Immediate | Hex words |
|-------------|--------|-----|------|-----------|-----------|
| MOV AX, #0x1234 | 0000 | 00 | 00 | 0x1234 | 0x0080, 0x1234 |
| ADD BX, #10 | 0001 | 01 | 00 | 0x000A | 0x1080, 0x000A |
| SUB CX, #1 | 0010 | 10 | 00 | 0x0001 | 0x2080, 0x0001 |

### Mode 1: Register-Immediate with Address (32-bit format)

Used for operations that need both a register and a full 16-bit address, such as memory loads in future extensions.

**Instruction format:** 32-bit

```
Word 1: [opcode:4][dst:2][01:2][unused:8]
Word 2: [address:16]
```

### Mode 2: Memory Indirect (32-bit format)

The second word contains the direct memory address to access.

**Instruction format:** 32-bit

```
Word 1: [opcode:4][dst:2][10:2][unused:8]
Word 2: [address:16]
```

**Operation:** `R[dst] ← R[dst] op Memory[imm16]`

---

## NOP Encoding

**NOP (No Operation)** is encoded as `0x0000`.

This encoding corresponds to `MOV AX, AX` — moving AX into itself. Since no state changes occur, this functions as a NOP.

### Why 0x0000 is NOP

```mermaid
flowchart TD
    A["0x0000 in binary: 0000 00 00 00 000000"] --> B["Decode: opcode=0000 (MOV)"]
    B --> C["Decode: dst=00 (AX)"]
    C --> D["Decode: src=00 (AX)"]
    D --> E["Decode: mode=00 (register-register)"]
    E --> F["Execute: AX ← AX"]
    F --> G["Result: No change (NOP)"]
```

### NOP Properties

| Property | Value |
|----------|-------|
| Encoding | `0x0000` |
| Equivalent instruction | `MOV AX, AX` |
| Flags affected | None |
| Cycles | 1 |
| Side effects | None |

### Alternative NOP

Any instruction that has no observable effect can serve as a NOP:

| Instruction | Encoding | Notes |
|-------------|----------|-------|
| `MOV AX, AX` | `0x0020` | Primary NOP encoding |
| `MOV BX, BX` | `0x0160` | Alternative NOP |
| `MOV CX, CX` | `0x02A0` | Alternative NOP |
| `MOV DX, DX` | `0x03E0` | Alternative NOP |
| `XOR AX, AX` | `0x5020` | Also clears AX to zero (not a true NOP) |

The canonical NOP is `0x0000` (`MOV AX, AX`).

---

## Encoding Examples

### Example 1: Register-Register ADD

**Instruction:** `ADD AX, BX`

**Binary breakdown:**

```
Opcode: ADD = 0001
Dst:    AX  = 00
Src:    BX  = 01
Mode:   reg-reg = 00
Unused: 000000

Binary: 0001 00 01 00 000000
Hex:    0x1100
```

### Example 2: Register-Immediate MOV

**Instruction:** `MOV CX, #0xBEEF`

**Word 1 breakdown:**

```
Opcode: MOV = 0000
Dst:    CX  = 10
Mode:   immediate = 00
Unused: 00000000

Binary word 1: 0000 10 00 00000000
Hex word 1:    0x0280
```

**Word 2:** `0xBEEF`

### Example 3: Conditional Jump (JZ)

**Instruction:** `JZ #0x0100`

**Word 1 breakdown:**

```
Opcode: JZ  = 1001
Dst:    (unused for jumps)
Mode:   immediate = 01
Unused: 00000000

Binary word 1: 1001 00 01 00000000
Hex word 1:    0x9040
```

**Word 2:** `0x0100` (target address)

### Example 4: OUT to Port

**Instruction:** `OUT #0x0010, AX`

**Word 1 breakdown:**

```
Opcode: OUT = 1100
Dst:    port = #0x0010 (in immediate)
Mode:   immediate = 01
Unused: 00000000

Binary word 1: 1100 00 01 00000000
Hex word 1:    0xC040
```

**Word 2:** `0x0010` (port number)

### Example 5: PUSH register

**Instruction:** `PUSH AX`

**Binary breakdown:**

```
Opcode: PUSH = 1101 (shared with CALL/INT)
Dst:    (unused)
Src:    AX  = 00
Mode:   register = 00
Unused: 000000

Binary: 1101 00 00 00 000000
Hex:    0xD000
```

---

## Illegal and Reserved Encodings

### Undefined Opcode Behavior

Opcodes in the range `1111` (`0xF`) through unused combinations are treated as HLT. The CPU halts on encountering an undefined opcode.

### Reserved Mode Bits

Mode values `10` and `11` in the 16-bit format are reserved. If encountered, the CPU behavior is:

- **Mode `10`:** Treated as NOP (instruction ignored)
- **Mode `11`:** Treated as NOP (instruction ignored)

### Unused Bits

The unused bits in both instruction formats (bits 5–0 in 16-bit, bits 7–0 in first word of 32-bit) must be written as zero during normal operation. The CPU ignores these bits during decoding. However:

- The assembler must set unused bits to zero
- The CPU may use these bits in future extensions
- Debug tools may use them for metadata (e.g., breakpoints)

### Encoding Sanity Rules

| Rule | Description |
|------|-------------|
| Word alignment | All instructions start on 16-bit word boundaries |
| Immediate alignment | 32-bit instructions occupy exactly two consecutive words |
| Unused zeros | All unused bits must be zero |
| Stack bounds | PUSH/POP must not cause SP to go below 0x0000 or above 0xFFFF |
| Jump targets | JMP/JZ/JNZ targets must be word-aligned (even addresses) |

---

*This document defines the complete binary encoding for the NovumOS-16bit instruction set. Assembler implementations must follow these encoding rules exactly.*
