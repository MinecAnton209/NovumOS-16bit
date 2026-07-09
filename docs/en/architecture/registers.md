# Register Set

[← Back to Main](../README.md) | [← Overview](overview.md) | [ISA](isa.md) | [Execution Cycle →](execution-cycle.md) | [Memory Map →](memory-map.md)

---

## Register Overview

The NovumOS-16bit CPU has 7 primary registers, all 16 bits wide. They are divided into general-purpose registers, program control registers, and status flags.

```mermaid
graph TB
    subgraph Registers["CPU Register File"]
        subgraph GP["General-Purpose Registers"]
            AX["AX<br/>Accumulator<br/>16-bit"]
            BX["BX<br/>Base Register<br/>16-bit"]
            CX["CX<br/>Counter Register<br/>16-bit"]
            DX["DX<br/>Data Register<br/>16-bit"]
        end
        subgraph Control["Program Control"]
            IP["IP / PC<br/>Program Counter<br/>16-bit"]
            SP["SP<br/>Stack Pointer<br/>16-bit"]
        end
        subgraph Status["Status"]
            FLAGS["FLAGS<br/>Z, C, S<br/>16-bit"]
        end
    end
```

---

## Register Table

| Register | Name | Width | Encoding | Primary Purpose | Volatile | Access |
|----------|------|-------|----------|-----------------|----------|--------|
| AX | Accumulator | 16-bit | `00` | Arithmetic results, I/O data | Yes | Read/Write |
| BX | Base | 16-bit | `01` | Base address for memory access | Yes | Read/Write |
| CX | Counter | 16-bit | `10` | Loop counter, shift count | Yes | Read/Write |
| DX | Data | 16-bit | `11` | Secondary data, I/O port address | Yes | Read/Write |
| IP/PC | Program Counter | 16-bit | — | Address of next instruction | Auto | Read-only (auto-increment) |
| SP | Stack Pointer | 16-bit | — | Top of stack address | Auto | Read/Write (by PUSH/POP/CALL/RET) |
| FLAGS | Flags | 16-bit | — | Condition codes (Z, C, S) | Auto | Read/Write (by arithmetic, PUSHF/POPF) |

---

## General-Purpose Registers

### AX — Accumulator

The primary register for arithmetic and logic operations. Most ALU operations use AX as one of the operands and store the result in AX.

| Use Case | Description |
|----------|-------------|
| Arithmetic result | `ADD AX, BX` → AX = AX + BX |
| Logic result | `AND AX, CX` → AX = AX AND CX |
| I/O data (IN) | `IN AX, DX` → Read from port DX into AX |
| I/O data (OUT) | `OUT DX, AX` → Write AX to port DX |
| Memory load | `MOV AX, [BX]` → Load from address in BX to AX |
| Memory store | `MOV [BX], AX` → Store AX to address in BX |

### BX — Base

Provides a base address for memory operations. Used as a pointer for indirect addressing.

| Use Case | Description |
|----------|-------------|
| Base pointer | `MOV AX, [BX]` → Load from address BX |
| Base+offset | `MOV AX, [BX+imm]` → Load from BX + immediate offset |
| Pointer arithmetic | `ADD BX, CX` → Advance pointer by CX |

### CX — Counter

General-purpose counter, especially useful for loops and shift operations.

| Use Case | Description |
|----------|-------------|
| Loop counter | `MOV CX, 10` / `DEC CX` / `JNZ loop_start` |
| Shift count | `SHL AX, CL` → Shift AX left by CL bits |
| String operations | Can serve as repeat count for block operations |

### DX — Data

Secondary data register. Used for I/O port addressing and as a second operand.

| Use Case | Description |
|----------|-------------|
| I/O port address | `IN AX, DX` → Read from port DX |
| I/O data | `OUT DX, AX` → Write AX to port DX |
| Second operand | `ADD AX, DX` → AX = AX + DX |
| Extended multiply | Can hold high word of multiply result |

---

## Program Control Registers

### IP / PC — Program Counter

Holds the address of the **next instruction** to be fetched from memory.

| Property | Value |
|----------|-------|
| Width | 16-bit |
| Initial value | `0x0000` (boot address) |
| Update | Auto-incremented by 1 (or 2 for 32-bit instructions) after each fetch |
| Branching | Overwritten by JMP, JZ, JNZ, CALL, INT |

```mermaid
graph LR
    IP["IP<br/>(current)"] -->|"Fetch instruction"| MEM["Memory"]
    MEM -->|"Instruction word"| IR["Instruction Register"]
    IP -->|"Auto-increment"| IP_INC["IP + 1 or +2"]
    IP_INC -->|"Next cycle"| IP
```

**Auto-increment behavior:**

| Instruction Format | Words | IP Increment |
|--------------------|-------|--------------|
| 16-bit (short) | 1 | IP += 2 |
| 32-bit (long) | 2 | IP += 4 |

The IP is **not directly writable** by user instructions. It can only be modified by:
- Jump instructions (`JMP`, `JZ`, `JNZ`)
- Subroutine call (`CALL`)
- Interrupt (`INT`)
- Return (`RET`)
- Reset/boot

### SP — Stack Pointer

Holds the address of the **top of the stack** in memory.

| Property | Value |
|----------|-------|
| Width | 16-bit |
| Growth direction | Downward (toward lower addresses) |
| PUSH | SP = SP - 2; word[SP] = value |
| POP | value = word[SP]; SP = SP + 2 |
| CALL | Push IP; SP -= 2; IP = target |
| RET | Pop IP from stack; SP += 2 |

```mermaid
graph TB
    subgraph Stack["Stack in Memory"]
        direction TB
        HIGH["High Address (initial SP)"]
        PUSH1["PUSH #1 → SP decreases by 2"]
        PUSH2["PUSH #2 → SP decreases by 2"]
        TOP["← Current SP"]
    end
    HIGH --> PUSH1 --> PUSH2 --> TOP
```

**Stack growth direction:**

| Operation | SP Change | Description |
|-----------|-----------|-------------|
| `PUSH reg` | SP = SP - 2 | Store word (2 bytes), decrement SP |
| `POP reg` | SP = SP + 2 | Load word (2 bytes), increment SP |
| `CALL` | SP = SP - 2 | Push return address (2 bytes) |
| `RET` | SP = SP + 2 | Pop return address (2 bytes) |
| `INT` | SP = SP - 2 | Push FLAGS + IP |
| `IRET` | SP = SP + 2 | Pop IP + FLAGS |

---

## FLAGS Register

The FLAGS register holds condition codes set by ALU operations and tested by conditional jumps.

### FLAGS Bit Layout

```mermaid
graph LR
    subgraph FLAGS["FLAGS Register (16-bit)"]
        B15["15"] 
        B14["14"]
        B13["13"]
        B12["12"]
        B11["11"]
        B10["10"]
        B9["9"]
        B8["8"]
        B7["7"]
        B6["6"]
        B5["5"]
        B4["4"]
        B3["3"]
        B2["2"]
        B1["1"]
        B0["0"]
    end

    B0 -.->|"Bit 0"| Z["Z — Zero Flag"]
    B1 -.->|"Bit 1"| C["C — Carry Flag"]
    B2 -.->|"Bit 2"| S["S — Sign Flag"]
```

### Flags Detail Table

| Bit | Name | Set When | Cleared When | Used By |
|-----|------|----------|--------------|---------|
| 0 | **Z** (Zero) | ALU result is all zeros | ALU result is non-zero | `JZ` (jump if Z=1), `JNZ` (jump if Z=0) |
| 1 | **C** (Carry) | Arithmetic produces carry out of bit 15 (addition) or borrow (subtraction) | No carry/borrow | `JC` (if added), unsigned overflow detection |
| 2 | **S** (Sign) | ALU result bit 15 is 1 (negative in two's complement) | Result bit 15 is 0 (positive) | `JS` (if added), signed comparison |
| 3–15 | Reserved | — | — | Unused (read as 0) |

### How Flags Are Updated

Flags are updated **atomically** at the end of each ALU operation:

| Instruction | Z | C | S |
|-------------|---|---|---|
| `ADD` | ✓ Set | ✓ Set | ✓ Set |
| `SUB` | ✓ Set | ✓ Set | ✓ Set |
| `CMP` | ✓ Set | ✓ Set | ✓ Set |
| `TEST` | ✓ Set | ✗ Cleared | ✗ Cleared |
| `ADC` | ✓ Set | ✓ Set | ✓ Set |
| `SBB` | ✓ Set | ✓ Set | ✓ Set |
| `AND` | ✓ Set | ✗ Cleared | ✗ Cleared |
| `OR` | ✓ Set | ✗ Cleared | ✗ Cleared |
| `XOR` | ✓ Set | ✗ Cleared | ✗ Cleared |
| `SHL` | ✓ Set | Last shifted-out bit | ✓ Set |
| `SHR` | ✓ Set | Last shifted-out bit | ✓ Set |
| `INC` | ✓ Set | ✗ Cleared | ✓ Set |
| `DEC` | ✓ Set | ✗ Cleared | ✓ Set |
| `NOT` | ✗ Unchanged | ✗ Unchanged | ✗ Unchanged |
| `NEG` | ✓ Set | ✓ Set | ✓ Set |
| `XCHG` | ✗ Unchanged | ✗ Unchanged | ✗ Unchanged |
| `MOV` | ✗ Unchanged | ✗ Unchanged | ✗ Unchanged |

### Flag Update Logic

```mermaid
graph TB
    ALU_OUT["ALU Result<br/>(16-bit)"] --> Z_DET["Zero Detector<br/>(OR all 16 bits)"]
    ALU_OUT --> S_DET["Sign Detector<br/>(Bit 15)"]
    ALU_OUT --> C_DET["Carry Detector<br/>(Carry out of module 3)"]

    Z_DET -->|"result == 0"| Z_FLAG["Z Flag"]
    C_DET -->|"carry out"| C_FLAG["C Flag"]
    S_DET -->|"bit 15 == 1"| S_FLAG["S Flag"]

    Z_FLAG --> FLAGS_REG["FLAGS Register"]
    C_FLAG --> FLAGS_REG
    S_FLAG --> FLAGS_REG
```

---

## Register Encoding

General-purpose registers are encoded using 2 bits in instruction words:

| Binary | Register | Mnemonic |
|--------|----------|----------|
| `00` | AX | Accumulator |
| `01` | BX | Base |
| `10` | CX | Counter |
| `11` | DX | Data |

This encoding appears in:
- **Source register** field (bits [5:4] in 16-bit format)
- **Destination register** field (bits [7:6] in 16-bit format)
- **Register-indirect addressing** (base register selector)

### Instruction Word Format

```mermaid
block-beta
    columns 16
    block:opcode:4
        columns 4
        O3["bit 15"] O2["bit 14"] O1["bit 13"] O0["bit 12"]
    end
    block:mode:2
        columns 2
        M1["bit 11"] M0["bit 10"]
    end
    block:size:2
        columns 2
        S1["bit 9"] S0["bit 8"]
    end
    block:dest:2
        columns 2
        D1["bit 7"] D0["bit 6"]
    end
    block:source:6
        columns 6
        SR5["bit 5"] SR4["bit 4"] SR3["bit 3"] SR2["bit 2"] SR1["bit 1"] SR0["bit 0"]
    end
```

```mermaid
block-beta
    columns 16
    block:opcode:4
        columns 4
        O3["bit 15"] O2["bit 14"] O1["bit 13"] O0["bit 12"]
    end
    block:mode:2
        columns 2
        M1["bit 11"] M0["bit 10"]
    end
    block:size:2
        columns 2
        S1["bit 9"] S0["bit 8"]
    end
    block:dest:2
        columns 2
        D1["bit 7"] D0["bit 6"]
    end
    block:src_imm:6
        columns 6
        SI5["bit 5"] SI4["bit 4"] SI3["bit 3"] SI2["bit 2"] SI1["bit 1"] SI0["bit 0"]
    end
```

```mermaid
block-beta
    columns 16
    block:extended:16
        columns 16
        E15["bit 31"] E14["bit 30"] E13["bit 29"] E12["bit 28"]
        E11["bit 27"] E10["bit 26"] E9["bit 25"] E8["bit 24"]
        E7["bit 23"] E6["bit 22"] E5["bit 21"] E4["bit 20"]
        E3["bit 19"] E2["bit 18"] E1["bit 17"] E0["bit 16"]
    end
```

---

## Register Instruction Effects

This table shows which instructions modify which registers:

| Instruction | AX | BX | CX | DX | IP | SP | FLAGS |
|-------------|:--:|:--:|:--:|:--:|:--:|:--:|:-----:|
| `MOV dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | — |
| `ADD dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `SUB dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `CMP dest, src` | — | — | — | — | Auto | — | ✓ |
| `TEST dest, src` | — | — | — | — | Auto | — | ✓ |
| `ADC dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `SBB dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `AND dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `OR dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `XOR dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `SHL dest, count` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `SHR dest, count` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `INC dest` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `DEC dest` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `NOT dest` | ✓* | ✓* | ✓* | ✓* | Auto | — | — |
| `NEG dest` | ✓* | ✓* | ✓* | ✓* | Auto | — | ✓ |
| `XCHG dest, src` | ✓* | ✓* | ✓* | ✓* | Auto | — | — |
| `JMP addr` | — | — | — | — | ✓ | — | — |
| `JZ addr` | — | — | — | — | ✓† | — | — |
| `JNZ addr` | — | — | — | — | ✓† | — | — |
| `JC addr` | — | — | — | — | ✓† | — | — |
| `JNC addr` | — | — | — | — | ✓† | — | — |
| `JS addr` | — | — | — | — | ✓† | — | — |
| `JNS addr` | — | — | — | — | ✓† | — | — |
| `IN dest, port` | ✓* | — | — | ✓ | Auto | — | — |
| `OUT port, src` | — | — | — | ✓ | Auto | — | — |
| `PUSH reg` | — | — | — | — | Auto | ✓ | — |
| `POP reg` | ✓* | ✓* | ✓* | ✓* | Auto | ✓ | — |
| `CALL addr` | — | — | — | — | ✓ | ✓ | — |
| `RET` | — | — | — | — | ✓ | ✓ | — |
| `INT n` | — | — | — | — | ✓ | ✓ | ✓ |
| `HLT` | — | — | — | — | — | — | — |

*\* If that register is the destination operand.*
*† Only if the condition (Z flag) is met.*

---

## Special Register Behaviors

### Program Counter (IP) Protection

The IP register cannot be used as a general-purpose register. Attempting to use IP as a source or destination in MOV, ADD, or other ALU instructions is undefined behavior and may cause a CPU fault.

### Stack Pointer (SP) Alignment

While the hardware does not enforce alignment, it is recommended to keep SP aligned to even addresses (16-bit word boundaries) for correct PUSH/POP operations.

### FLAGS Preservation

The FLAGS register is only modified by ALU instructions (ADD, SUB, AND, OR, XOR, SHL, SHR). It is **not** modified by MOV, PUSH, POP, JMP, or I/O instructions. This allows conditional branches to test flags set by a previous arithmetic operation.

---

*See [Execution Cycle](execution-cycle.md) for how register updates are sequenced during instruction execution.*
