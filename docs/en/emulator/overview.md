# Emulator Overview

[Русская версия](../../ru/emulator/overview.md)

---

## What is the Emulator?

The NovumOS-16bit emulator is a cycle-accurate software implementation of the custom TTL CPU, written in Zig. It loads a firmware binary from disk and executes it on a virtual CPU with 64 KB of memory and 256 I/O ports.

The emulator is used for:
- **Testing** — run unit tests against the CPU instruction set
- **Development** — test firmware without physical hardware
- **Debugging** — inspect CPU state after each instruction

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Emulator (Zig)                       │
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │  cpu.zig │    │ main.zig │    │    test.zig      │  │
│  │          │    │          │    │                  │  │
│  │ CPU      │◄───│ Load     │    │ 38 unit tests   │  │
│  │ step()   │    │ firmware │    │ covering all ISA │  │
│  │ run()    │    │ Execute  │    │ instructions     │  │
│  │ ALU      │    │ Dump     │    │                  │  │
│  └──────────┘    └──────────┘    └──────────────────┘  │
│       ▲                                                │
│       │                                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │              codegen.zig                         │  │
│  │                                                  │  │
│  │  ISA enums, encode functions, firmware generator │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Files

| File | Purpose |
|------|---------|
| `src/emulator/cpu.zig` | CPU implementation — registers, memory, instruction decode, ALU |
| `src/emulator/main.zig` | Entry point — loads firmware.bin, runs CPU, dumps state |
| `src/emulator/test.zig` | 38 unit tests covering all instruction categories |
| `src/codegen.zig` | ISA encoding functions and firmware generator |

---

## Build & Run

### Build Commands

```bash
zig build firmware    # Generate build/firmware.bin (1024 bytes)
zig build emulate     # Run emulator (loads firmware.bin)
zig build test        # Run all 38 tests
```

### Emulator Output

```
Loaded firmware: 1024 bytes

First 32 bytes: 00 00 00 FF 00 11 00 0F 00 15 10 A0 ...

=== CPU State ===
AX=0x0000 BX=0x0000 CX=0x0000 DX=0x0000
IP=0x0000 SP=0xFFFE FLAGS=0x0000 [Z=false C=false S=false]
Halted=false

Executed 29 cycles

=== CPU State ===
AX=0x00FF BX=0x0000 CX=0x0001 DX=0xFFF0
IP=0x0044 SP=0x0002 FLAGS=0x0000 [Z=false C=false S=false]
Halted=true
```

---

## CPU State

### Registers

| Register | Size | Purpose |
|----------|------|---------|
| AX | 16-bit | Accumulator — primary working register |
| BX | 16-bit | Base — indexed addressing |
| CX | 16-bit | Counter — loop counter, shift count |
| DX | 16-bit | Data — I/O port address |
| IP | 16-bit | Instruction Pointer — next instruction address |
| SP | 16-bit | Stack Pointer — top of stack (0xFFFE at reset) |
| FLAGS | 16-bit | Flags register (Z, C, S) |

### Flags

| Flag | Bit | Set when |
|------|-----|----------|
| Z (Zero) | 0 | ALU result == 0 |
| C (Carry) | 1 | Unsigned overflow/borrow |
| S (Sign) | 2 | Result bit 15 == 1 (negative) |

### Memory

- 64 KB addressable memory (byte-addressable)
- Little-endian byte order
- Stack grows downward from 0xFFFE
- Firmware loaded at address 0x0000

### I/O Ports

- 256 × 16-bit I/O ports
- Accessed via `IN` and `OUT` instructions

---

## Supported Instructions

All instructions are fully implemented and tested:

| Category | Instructions | Tests |
|----------|-------------|-------|
| Data Movement | `MOV` (reg/reg, reg/imm, indirect) | ✓ |
| Arithmetic | `ADD`, `SUB`, `INC`, `DEC` | ✓ |
| Compare | `CMP`, `TEST` | ✓ |
| Logic | `AND`, `OR`, `XOR`, `NOT`, `NEG` | ✓ |
| Shift | `SHL`, `SHR` | ✓ |
| Exchange | `XCHG` | ✓ |
| Add/Sub Carry | `ADC`, `SBB` | ✓ |
| Stack | `PUSH`, `POP` | ✓ |
| Control Flow | `JMP`, `JZ`, `JNZ`, `JC`, `JNC`, `JS`, `JNS` | ✓ |
| Subroutine | `CALL`, `RET` | ✓ |
| Interrupts | `INT`, `IRET` | ✓ |
| I/O | `IN`, `OUT` | ✓ |
| System | `NOP`, `HLT` | ✓ |

---

## Instruction Size Detection

The CPU uses a heuristic to detect 16-bit vs 32-bit instructions:

```
raw32 = lo16 | (hi16 << 16)
mode = (raw32 >> 24) & 0x3

if mode == 0b01:
    32-bit instruction — decode opcode from bits 31:28
else:
    16-bit instruction — decode opcode from lo16 bits 15:12
```

This works because `encode32()` always sets mode=01 at bits 25:24, while `encode16()` never uses mode=01 in that position.

---

## Testing

### Test Coverage (38 tests)

| Category | Count | Tests |
|----------|-------|-------|
| CPU Reset | 1 | Reset clears all registers |
| NOP | 1 | No operation advances IP |
| MOV | 2 | reg/reg, reg/imm |
| ALU Arithmetic | 2 | ADD, SUB |
| CMP | 2 | Equal, less than |
| ALU Logic | 3 | AND, OR, XOR |
| ALU Shift | 2 | SHL, SHR |
| ALU Inc/Dec | 2 | INC, DEC |
| ALU Bit | 2 | NOT, NEG |
| ALU Exchange | 1 | XCHG |
| ADC/SBB | 2 | Add/sub with carry |
| Stack | 1 | PUSH/POP pair |
| Conditional Jump | 7 | JZ, JNZ, JC, JNC, JS, JNS (taken/not taken) |
| HLT | 1 | Halt CPU |
| CALL/RET | 1 | Subroutine call and return |
| IN/OUT | 1 | I/O port read/write |
| Integration | 1 | Full program: MOV, SUB, HLT |

### Running Tests

```bash
zig build test
```

All 38 tests should pass with exit code 0.

---

## Firmware Format

The firmware binary (`build/firmware.bin`) is a raw 1024-byte binary file containing instructions in little-endian byte order. It is loaded at address 0x0000 when the emulator starts.

### Default Test Firmware

The firmware exercises most of the ISA:

```nasm
0x00: NOP                    ; no operation
0x02: MOV AX, 0x00FF         ; load immediate 255
0x06: MOV BX, 0x000F         ; load immediate 15
0x0A: ADD AX, BX             ; AX = 0xFF + 0x0F = 0x0108
0x0C: SUB CX, AX             ; CX = 0 - 0x0108 = 0xFF00
0x0E: CMP DX, AX             ; compare (flags only)
0x10: AND DX, AX             ; bitwise AND
0x12: OR DX, BX              ; bitwise OR
0x14: XOR AX, AX             ; clear AX
0x16: SHL BX, AX             ; shift left by 0
0x18: SHR BX, AX             ; shift right by 0
0x1A: INC DX                 ; increment DX
0x1C: DEC CX                 ; decrement CX
0x1E: SHR CX, AX             ; shift right by 0
0x20: INC AX                 ; increment AX
0x22: DEC BX                 ; decrement BX
0x24: NOT CX                 ; bitwise complement
0x26: NEG DX                 ; two's complement negate
0x28: XCHG AX, BX            ; exchange registers
0x2A: ADC AX, BX             ; add with carry
0x2C: SBB AX, BX             ; subtract with borrow
0x2E: TEST AX, BX            ; bitwise AND (flags only)
0x30: PUSH AX                ; push to stack
0x32: POP BX                 ; pop from stack
0x34: MOV AX, 0x1234         ; load test value
0x38: IN AX, 0x00            ; read I/O port
0x3C: OUT 0x00, AX           ; write I/O port
0x40: MOV AX, 0x00FF         ; final value
0x44: HLT                    ; halt CPU
```

---

## Debugging

### CPU State Dump

The emulator dumps CPU state before and after execution:

```
=== CPU State ===
AX=0x00FF BX=0x0000 CX=0x0001 DX=0xFFF0
IP=0x0044 SP=0x0002 FLAGS=0x0000 [Z=false C=false S=false]
Halted=true
```

### Memory Dump

First 128 bytes of memory are printed in hex format:

```
Memory (first 128 bytes):
  0x0000: 00 00 00 FF 00 11 00 0F ...
  0x0008: 00 15 10 A0 80 A1 C0 A2 ...
```

### Adding Debug Prints

To add custom debug output, use `std.debug.print()` in `cpu.zig`:

```zig
pub fn step(self: *CPU) !void {
    // Add debug print before instruction execution
    std.debug.print("IP=0x{X:0>4} ", .{self.ip});
    // ... existing code ...
}
```
