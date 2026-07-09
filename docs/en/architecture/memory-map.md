# Memory Map

[← Back to Main](../README.md) | [← Overview](overview.md) | [← Registers](registers.md) | [← Execution Cycle](execution-cycle.md)

---

## 64KB Address Space Overview

The NovumOS-16bit CPU addresses a 64 KB (65,536 byte) memory space using a 16-bit address bus.

```mermaid
graph TB
    subgraph MemoryMap["64KB Memory Map (0x0000 – 0xFFFF)"]
        direction TB
        
        BOOT["0x0000 – 0x00FF<br/>Boot / Reset Vector<br/>(256 bytes)"]
        CODE["0x0100 – 0x7FFF<br/>Code Segment<br/>(~32 KB)"]
        DATA["0x8000 – 0xB7FF<br/>Data Segment<br/>(~14 KB)"]
        VGA_MEM["0xB800 – 0xBFFF<br/>VGA Text Buffer<br/>(2 KB)"]
        IO_REG["0xC000 – 0xEFFF<br/>Memory-mapped I/O<br/>(12 KB)"]
        STACK["0xF000 – 0xFFFF<br/>Stack Segment<br/>(4 KB)"]
    end
    
    BOOT --> CODE --> DATA --> VGA_MEM --> IO_REG --> STACK
```

---

## Segment Layout

### Boot / Reset Vector (0x0000 – 0x00FF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0x0000 – 0x0003 | 4 bytes | Reset vector: initial IP value |
| 0x0004 – 0x00FF | 252 bytes | Interrupt vector table (64 vectors × 4 bytes) |

The CPU begins execution at address `0x0000` after reset. The first instruction at this address is the boot code.

**Interrupt Vector Table:**

| Vector | Address | Interrupt |
|--------|---------|-----------|
| 0 | 0x0004 | Reserved (divide error) |
| 1 | 0x0008 | Debug |
| 2 | 0x000C | NMI |
| 3 | 0x0010 | Breakpoint |
| 8 | 0x0024 | Timer interrupt |
| 9 | 0x0028 | Keyboard interrupt |
| 10 | 0x002C | Reserved |
| 11 | 0x0030 | Reserved |
| 12 | 0x0034 | Reserved |
| 13 | 0x0038 | Reserved |
| 14 | 0x003C | Reserved |
| 15 | 0x0040 | Reserved |

Each vector entry contains:
- Bytes 0–1: New IP value (target address of ISR)
- Bytes 2–3: Segment hint (reserved for future use, currently ignored)

---

### Code Segment (0x0100 – 0x7FFF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0x0100 – 0x7FFF | ~32 KB | Executable instructions |

- Program code is loaded starting at `0x0100` (after the vector table)
- Code is **read-only** during execution (no self-modifying code)
- Instructions can be 16-bit (1 word) or 32-bit (2 words)
- Maximum code capacity: ~16,383 instructions (16-bit) or ~8,191 instructions (32-bit)

---

### Data Segment (0x8000 – 0xB7FF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0x8000 – 0xB7FF | ~14 KB | Global variables, constants, buffers |

- Read/write data storage
- Accessed via MOV instructions with direct or indirect addressing
- No memory protection — code can read/write any data address
- Data segment starts at `0x8000` (halfway through address space)

---

### VGA Text Buffer (0xB800 – 0xBFFF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0xB800 – 0xBFFF | 2 KB | VGA text mode framebuffer |

**VGA Text Mode Format:**

Each character cell occupies 2 bytes:

| Byte | Content |
|------|---------|
| Even address (0, 2, 4...) | ASCII character code |
| Odd address (1, 3, 5...) | Attribute byte (foreground/background color) |

**Attribute Byte Layout:**

```mermaid
graph LR
    subgraph Attr["Attribute Byte (8-bit)"]
        B7["Bit 7: Blink"]
        B6["Bit 6: BG Red"]
        B5["Bit 5: BG Green"]
        B4["Bit 4: BG Blue"]
        B3["Bit 3: FG Red"]
        B2["Bit 2: FG Green"]
        B1["Bit 1: FG Blue"]
        B0["Bit 0: FG Intensity"]
    end
```

**Text Mode Parameters:**

| Parameter | Value |
|-----------|-------|
| Columns | 80 |
| Rows | 25 |
| Total cells | 2,000 |
| Bytes per cell | 2 |
| Total buffer | 4,000 bytes (fits in 2 KB) |
| Screen address | 0xB800 |
| Cursor position | Stored in VGA registers (0x3D4/0x3D5) |

**Example:**

Writing "Hello" at row 0, column 0:

| Address | Value | Meaning |
|---------|-------|---------|
| 0xB800 | 0x48 | 'H' |
| 0xB801 | 0x07 | White on black |
| 0xB802 | 0x65 | 'e' |
| 0xB803 | 0x07 | White on black |
| 0xB804 | 0x6C | 'l' |
| 0xB805 | 0x07 | White on black |
| 0xB806 | 0x6C | 'l' |
| 0xB807 | 0x07 | White on black |
| 0xB808 | 0x6F | 'o' |
| 0xB809 | 0x07 | White on black |

---

### Memory-mapped I/O (0xC000 – 0xEFFF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0xC000 – 0xC0FF | 256 bytes | Device control registers |
| 0xC100 – 0xC1FF | 256 bytes | DMA buffers |
| 0xC200 – 0xEFFF | ~11.5 KB | Extended memory-mapped devices |

Memory-mapped I/O regions mirror the functionality of port-mapped I/O but are accessed through regular memory instructions. This provides an alternative access path for devices.

**Note:** Memory-mapped I/O is **not compatible** with port-mapped I/O for the same device. Use one or the other, not both.

---

### Stack Segment (0xF000 – 0xFFFF)

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0xF000 – 0xFFFF | 4 KB | Stack space |

**Stack characteristics:**

| Property | Value |
|----------|-------|
| Initial SP | 0xFFFF (top of memory) |
| Growth direction | Downward (toward lower addresses) |
| Word size | 16-bit (2 bytes per push/pop) |
| Max stack depth | 2,048 entries (4 KB / 2 bytes) |
| Stack frames | Supported via CALL/RET with BP-like convention |

**Stack operations:**

```mermaid
graph TB
    subgraph StackGrowth["Stack Growth Direction"]
        TOP["0xFFFF<br/>← Initial SP"]
        P1["0xFFFE<br/>PUSH #1"]
        P2["0xFFFC<br/>PUSH #2"]
        P3["0xFFFA<br/>PUSH #3"]
        CURR["← Current SP"]
    end
    
    TOP --> P1 --> P2 --> P3 --> CURR
```

| Operation | SP Change | Memory Access |
|-----------|-----------|---------------|
| `PUSH AX` | SP = SP - 2 | word[SP] = AX |
| `POP AX` | SP = SP + 2 | AX = word[SP] |
| `CALL subroutine` | SP = SP - 2 | word[SP] = IP (return address) |
| `RET` | SP = SP + 2 | IP = word[SP] |
| `INT n` | SP = SP - 2 | word[SP] = FLAGS; word[SP-1] = IP |
| `IRET` | SP = SP + 2 | IP = word[SP]; FLAGS = word[SP+1] |

---

## Complete Address Map

```mermaid
graph TB
    subgraph FullMap["64KB Address Space"]
        A0000["0x0000<br/>Boot Vector"]
        A0100["0x0100<br/>Code Start"]
        A7FFF["0x7FFF<br/>Code End"]
        A8000["0x8000<br/>Data Start"]
        AB800["0xB800<br/>VGA Buffer"]
        ABFFF["0xBFFF<br/>VGA End"]
        AC000["0xC000<br/>MMIO Start"]
        AEFFF["0xEFFF<br/>MMIO End"]
        AF000["0xF000<br/>Stack Start"]
        AFFFF["0xFFFF<br/>Stack Top"]
    end
    
    A0000 ---|"Boot/IVT<br/>256 B"| A0100
    A0100 ---|"Code<br/>~32 KB"| A7FFF
    A7FFF ---|"Data<br/>~14 KB"| A8000
    A8000 ---|"VGA<br/>2 KB"| AB800
    AB800 ---|"MMIO<br/>12 KB"| AC000
    AC000 ---|"Reserved"| AEFFF
    AEFFF ---|"Stack<br/>4 KB"| AF000
    AF000 ---|"Top"| AFFFF
```

---

## Memory Map Table

| Start | End | Size | Name | Access | Description |
|-------|-----|------|------|--------|-------------|
| 0x0000 | 0x0003 | 4 B | Reset Vector | R | CPU boot address |
| 0x0004 | 0x00FF | 252 B | IVT | R | Interrupt vector table (64 vectors) |
| 0x0100 | 0x7FFF | 32,512 B | Code | R/X | Executable code segment |
| 0x8000 | 0xB7FF | 14,336 B | Data | R/W | Global data segment |
| 0xB800 | 0xBFFF | 2,048 B | VGA | R/W | VGA text mode buffer |
| 0xC000 | 0xC0FF | 256 B | Device Reg | R/W | Device control registers |
| 0xC100 | 0xC1FF | 256 B | DMA | R/W | DMA buffer area |
| 0xC200 | 0xEFFF | 11,776 B | MMIO | R/W | Extended memory-mapped I/O |
| 0xF000 | 0xFFFF | 4,096 B | Stack | R/W | Stack segment (grows down) |

---

## I/O Port Map

The CPU uses **isolated I/O** (separate address space) for peripherals. I/O ports are accessed via `IN` and `OUT` instructions.

### Peripheral Port Allocation

```mermaid
graph TB
    subgraph IOPortMap["I/O Port Address Space (8-bit, 0x00–0xFF)"]
        subgraph UART["UART (port 0x00)"]
            UART_D["0x00 — Data (terminal I/O)"]
        end
        subgraph TIMER["Timer (port 0x01)"]
            TIMER_D["0x01 — Cycle counter"]
        end
        subgraph KBD["Keyboard (port 0x02)"]
            KBD_D["0x02 — Scan codes"]
        end
    end
```

### Detailed Port Table

| Port | Device | Register | R/W | Description |
|------|--------|----------|-----|-------------|
| 0x00 | UART | Data | R/W | Terminal I/O (send/receive characters) |
| 0x01 | Timer | Counter | R/W | Cycle counter |
| 0x02 | Keyboard | Scan code | R | Keyboard scan codes |

---

## Memory Access Patterns

### Direct Addressing

The instruction contains the full 16-bit address.

```mermaid
graph LR
    INSTR["Instruction<br/>MOV AX, [0x8000]"] --> ADDR["Address: 0x8000"]
    ADDR --> MEM["Memory[0x8000]"]
    MEM --> DATA["Data → AX"]
```

| Instruction | Address Source |
|-------------|----------------|
| `MOV AX, [0x8000]` | Direct: 0x8000 |
| `MOV [0xB800], AX` | Direct: 0xB800 |

### Register Indirect Addressing

The address is held in a register (typically BX).

```mermaid
graph LR
    INSTR["Instruction<br/>MOV AX, [BX]"] --> REG["BX contains address"]
    REG --> MEM["Memory[BX]"]
    MEM --> DATA["Data → AX"]
```

| Instruction | Address Source |
|-------------|----------------|
| `MOV AX, [BX]` | Address = BX |
| `MOV [BX], AX` | Address = BX |
| `MOV AX, [BX+imm]` | Address = BX + offset |

### Immediate Addressing

The operand is embedded in the instruction (no memory access for the operand).

| Instruction | Value Source |
|-------------|--------------|
| `MOV AX, 0x1234` | Immediate: 0x1234 |
| `ADD AX, 5` | Immediate: 5 |

---

## Stack Memory Layout

```mermaid
graph TB
    subgraph StackLayout["Stack Segment Detail"]
        direction TB
        S_FFFF["0xFFFF<br/>Top of Stack (initial SP)"]
        S_FFFE["0xFFFE<br/>Word 0 (last pushed)"]
        S_FFFC["0xFFFC<br/>Word 1"]
        S_FFFA["0xFFFA<br/>Word 2"]
        S_FFF8["0xFF8<br/>Word 3"]
        S_DOT["⋮"]
        S_F002["0xF002<br/>Word 2046"]
        S_F000["0xF000<br/>Bottom of Stack"]
    end
    
    S_FFFF --> S_FFFE --> S_FFFC --> S_FFFA --> S_FFF8 --> S_DOT --> S_F002 --> S_F000
```

### Stack Frame Convention

For function calls, a standard stack frame convention is used:

| Offset | Content |
|--------|---------|
| SP+0 | Return address (pushed by CALL) |
| SP+1 | Saved BP (if frame pointer used) |
| SP+2 | Local variable 1 |
| SP+3 | Local variable 2 |
| ... | ... |

**CALL/RET sequence:**

| Step | SP | Memory | Description |
|------|-----|--------|-------------|
| Before CALL | 0xFF00 | — | SP points to next free slot |
| CALL subroutine | 0xFEFF | [0xFEFF] = IP | Push return address |
| Inside subroutine | 0xFEFF | — | SP at return address |
| RET | 0xFF00 | IP = [0xFEFF] | Pop return address, resume |

---

## Memory Protection

**Current implementation:** No hardware memory protection. All segments are accessible from all privilege levels.

| Feature | Status |
|---------|--------|
| Segmentation | Flat model (no segments) |
| Paging | Not supported |
| User/supervisor modes | Not implemented |
| Read-only code | Not enforced (software convention) |
| Stack overflow detection | Not implemented |

**Software conventions for protection:**

- Code segment is treated as read-only by compiler/assembler convention
- Stack overflow is checked by comparing SP against `0xF000` (stack bottom)
- Data segment bounds are managed by the OS kernel

---

## Byte Ordering (Endianness)

The NovumOS-16bit CPU uses **little-endian** byte ordering:

| Address | Value (16-bit word 0x1234) |
|---------|---------------------------|
| N | 0x34 (low byte) |
| N+1 | 0x12 (high byte) |

This affects:
- Multi-byte data storage in memory
- Instruction word encoding
- I/O port data transfer order

---

## Summary

| Segment | Address Range | Size | Direction | Purpose |
|---------|---------------|------|-----------|---------|
| Boot/IVT | 0x0000–0x00FF | 256 B | — | Reset vector + interrupt table |
| Code | 0x0100–0x7FFF | ~32 KB | ↑ | Executable instructions |
| Data | 0x8000–0xB7FF | ~14 KB | ↑ | Global variables |
| VGA | 0xB800–0xBFFF | 2 KB | — | Text mode display buffer |
| MMIO | 0xC000–0xEFFF | 12 KB | — | Memory-mapped devices |
| Stack | 0xF000–0xFFFF | 4 KB | ↓ | Call stack (grows downward) |

**Total:** 64 KB (0x0000–0xFFFF)

---

*See [Overview](overview.md) for how the bus interface accesses this memory and [Execution Cycle](execution-cycle.md) for timing of memory operations.*
