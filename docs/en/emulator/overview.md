# Emulator Overview

[Русская версия](../../ru/emulator/overview.md)

---

## What is the Emulator?

The NovumOS-16bit emulator is a cycle-accurate software implementation of the custom TTL CPU, written in Zig. It loads a firmware binary from disk and executes it on a virtual CPU with 64 KB of memory and 256 I/O ports.

The emulator is used for:
- **Testing** — run unit tests against the CPU instruction set, disassembler, and codegen
- **Development** — test firmware without physical hardware
- **Debugging** — inspect CPU state, disassemble firmware, trace execution
- **Interactive use** — run the firmware as a complete system with terminal and keyboard

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                     emulator/                         │
│                                                       │
│  cpu.zig       main.zig      term.zig                 │
│  step/run      load/exec     Win/POSIX                │
│  ALU/mem/IO    interactive   terminal I/O             │
│                                                       │
│  disasm.zig    test.zig      disasm_test.zig          │
│  disassemble   207 tests     67 tests                 │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Files

| File | Purpose |
|------|---------|
| `src/emulator/cpu.zig` | CPU implementation — registers, memory, instruction decode, ALU, I/O peripherals |
| `src/emulator/main.zig` | Entry point — batch, debug, and interactive modes |
| `src/emulator/term.zig` | Terminal handling — WindowsTerm (GetStdHandle) and UnixTerm (posix) |
| `src/emulator/disasm.zig` | Disassembler — reads binary memory, outputs assembly text |
| `src/emulator/test.zig` | 207+ unit tests covering CPU, ALU, stack, jumps, I/O, VGA |
| `src/emulator/disasm_test.zig` | ~67 disassembly tests |
| `src/codegen.zig` | ISA encoding functions and firmware generator |
| `src/codegen_test.zig` | ~55 codegen encoding tests |
| `src/kernel.zig` | Kernel firmware — shell with command parsing |
| `src/kernel_main.zig` | Kernel writer — generates `build/kernel.bin` |
| `src/config.zig` | Emulator configuration constants |

---

## Build & Run

### Build Commands

```bash
zig build            # Compile all modules
zig build run        # Generate kernel + run emulator in interactive mode
zig build test       # Run all tests (207 cpu + 67 disasm + 55 codegen)
zig build firmware   # Generate build/firmware.bin (simple test firmware)
zig build kernel     # Generate build/kernel.bin (shell firmware)
zig build emulate    # Run emulator in batch mode (reads build/firmware.bin)
```

### Emulator Command-Line Options

```
NovumOS-16bit CPU Emulator

Usage: emulator [options]

Options:
  -f, --firmware <path>   Path to firmware binary (default: build/firmware.bin)
  -i, --interactive       Interactive mode — use emulator as a PC (terminal + keyboard)
  -c, --cycles <n>        Maximum execution cycles (default: 1000, ignored with -i)
  -d, --debug             Enable debug mode (step through instructions with trace)
  -a, --disasm            Disassemble firmware before execution
  -m, --dump <addr>       Dump memory at address (hex, e.g. 0x0000)
  -e, --dump-end <addr>   End address for memory dump range
  -q, --quiet             Suppress non-essential output
  -h, --help              Show this help message

Examples:
  emulator -i                       Interactive mode (use as PC)
  emulator -i -f kernel.bin         Interactive with custom firmware
  emulator                          Batch mode (run 1000 cycles)
  emulator -c 50000 -a              Disassemble + run 50000 cycles
```

### Interactive Mode

In interactive mode (`-i`), the emulator runs as a complete system with real-time terminal I/O:

1. Keyboard input is continuously polled and fed into the CPU's UART RX and keyboard ring buffers
2. The CPU executes instructions in batches of 500 for performance
3. Every 50 instructions, the emulator checks for new keyboard input so that Enter is picked up promptly
4. UART TX output is flushed to the terminal after each batch
5. Ctrl+C or Ctrl+Z exits interactive mode

In interactive mode, the shell firmware reads raw characters from the UART (port 0x00), echoes them to the VGA (port 0x10), and builds a line buffer. When Enter is pressed, the line is parsed into a command ID (port 0x03) and argument string (port 0x04) for the firmware to process.

### Batch Mode

In batch mode (default), the emulator loads firmware and runs for a fixed number of cycles (default 1000), then dumps CPU state and memory.

### Debug Mode

In debug mode (`-d`), the emulator shows a full trace of every instruction executed:

```
[   0] 0x0000: MOV AX, 0x00FF       AX=0x0000 BX=0x0000 CX=0x0000 DX=0x0000 SP=0xFFFE FL=0x0000
[   1] 0x0004: MOV BX, 0x000F       AX=0x00FF BX=0x0000 CX=0x0000 DX=0x0000 SP=0xFFFE FL=0x0000
```

---

## CPU State

### Registers

| Register | Size | Purpose |
|----------|------|---------|
| AX | 16-bit | Accumulator — primary working register, ALU results |
| BX | 16-bit | Base — indexed addressing |
| CX | 16-bit | Counter — loop counter, shift count |
| DX | 16-bit | Data — I/O port addresses |
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
- Flat address space — no segments, no memory-mapped I/O

### I/O Ports

- 256 × 16-bit I/O ports
- Accessed via `IN` and `OUT` instructions
- Peripherals: UART (0x00), Timer (0x01), Keyboard (0x02), Line cmd_id (0x03), Line buffer (0x04), VGA char (0x10), VGA control (0x11), Generic (0x05–0xFF)

### Peripherals

| Port | Peripheral | Description |
|------|-----------|-------------|
| 0x00 | UART | Terminal character I/O (OUT=send, IN=read) |
| 0x01 | Timer | Read cycle count (low 16 bits) |
| 0x02 | Keyboard | Read scancode (0 if empty) |
| 0x03 | Line cmd_id | Read command ID (0=none, 1=help, 2=clear, 3=reboot, 4=info, 5=dump, 6=halt, 7=unknown); clears on read |
| 0x04 | Line buffer | Read next argument byte (0=empty) |
| 0x10 | VGA char | Write character to VGA buffer at cursor |
| 0x11 | VGA control | Write 0x0001=clear, 0x0002=flush |
| 0x05–0xFF | Generic | Generic R/W storage ports |

---

## Supported Instructions

All instructions are fully implemented and tested:

| Category | Instructions |
|----------|-------------|
| Data Movement | `MOV` (reg/reg, reg/imm, indirect) |
| Arithmetic | `ADD`, `SUB`, `INC`, `DEC` |
| Compare | `CMP`, `TEST` |
| Logic | `AND`, `OR`, `XOR`, `NOT`, `NEG` |
| Shift | `SHL`, `SHR` |
| Stack | `PUSH`, `POP` |
| Unconditional Jump | `JMP` |
| Conditional Jump | `JZ`, `JNZ`, `JC`, `JNC`, `JS`, `JNS` |
| Subroutine | `CALL`, `RET` |
| Interrupts | `INT`, `IRET` |
| I/O | `IN`, `OUT` |
| System | `NOP`, `HLT` |

### ALU Sub-Operations

The ALU instruction supports 13 active sub-operations encoded into a single opcode (4-bit field):

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0x0 | ADD | dst = dst + src |
| 0x1 | SUB | dst = dst - src |
| 0x2 | CMP | Compare (flags only, no result) |
| 0x3 | TEST | Bitwise AND (flags only, no result) |
| 0x4 | AND | dst = dst AND src |
| 0x5 | OR | dst = dst OR src |
| 0x6 | XOR | dst = dst XOR src |
| 0x7 | SHL | dst = dst << src |
| 0x8 | SHR | dst = dst >> src |
| 0x9 | INC | dst = dst + 1 |
| 0xA | DEC | dst = dst - 1 |
| 0xB | NOT | dst = NOT dst (bitwise complement) |
| 0xC | NEG | dst = 0 - dst (two's complement negate) |
| 0xD | MUL | dst = dst * src (planned) |
| 0xE | DIV | dst = dst / src (planned) |

### Conditional Jump Conditions

All 6 conditions are supported:

| Value | Mnemonic | Condition |
|-------|----------|-----------|
| 0x0 | JZ | Jump if Zero (Z=1) |
| 0x1 | JNZ | Jump if Not Zero (Z=0) |
| 0x2 | JC | Jump if Carry (C=1) |
| 0x3 | JNC | Jump if Not Carry (C=0) |
| 0x4 | JS | Jump if Sign (S=1) |
| 0x5 | JNS | Jump if Not Sign (S=0) |

---

## Instruction Size Detection

The CPU uses a heuristic to detect 16-bit vs 32-bit instructions:

```
raw32 = lo16 | (hi16 << 16)
mode  = (raw32 >> 24) & 0x3

if mode == 0b01:
    32-bit instruction — decode opcode from bits 31:28
else:
    16-bit instruction — decode opcode from lo16 bits 15:12
```

This works because `encode32()` always sets mode=01 at bits 25:24, while `encode16()` never uses mode=01 in that position.

---

## Testing

### Test Suites

| Suite | File | Count |
|-------|------|-------|
| CPU Tests | `src/emulator/test.zig` | 207 |
| Disassembly Tests | `src/emulator/disasm_test.zig` | ~67 |
| Codegen Tests | `src/codegen_test.zig` | ~55 |
| **Total** | | **~329** |

### CPU Test Coverage (207 tests)

| Category | Tests |
|----------|-------|
| CPU Reset | Reset clears all registers, SP=0xFFFE |
| NOP | Advances IP by 2 with no side effects |
| MOV | reg/reg, reg/imm, edge cases |
| ALU Arithmetic | ADD, SUB (flags: zero, carry, sign) |
| ALU Compare | CMP equal, less |
| ALU Logic | AND, OR, XOR (flags) |
| ALU Shift | SHL, SHR (by 0, 1, 8, 15) |
| ALU Inc/Dec | INC, DEC (no carry flag) |
| ALU Bit | NOT, NEG (including edge cases: 0, 1, 0x8000, 0xFFFF) |
| Stack | PUSH/POP (normal, wrap, multiple) |
| Conditional Jump | JZ, JNZ, JC, JNC, JS, JNS (taken and not taken for each) |
| HLT | Halt at various addresses |
| CALL/RET | Subroutine call and return |
| IN/OUT | I/O port read/write |
| INT/IRET | Interrupt pushes IP+FLAGS, IRET restores |
| VGA | putChar printable, CR, LF, backspace, wrap, scroll |
| UART | Write, read, read empty, flush |
| Timer | Read cycle count |
| Keyboard | Read scancode, read empty |
| Flags | All flag permutations for ALU and jumps |
| Integration | Full program sequences |

### Running Tests

```bash
zig build test
```

All tests should pass with exit code 0.

---

## Disassembler

The disassembler (`src/emulator/disasm.zig`) converts binary instruction words into human-readable assembly text. It supports both 16-bit and 32-bit instruction formats.

```bash
emulator -a -f kernel.bin    # Disassemble kernel firmware
```

The disassembler output uses `std.debug.print` and includes a `countCollapsed` function that groups consecutive identical instructions.

### Disassembly Output Format

```
0x0000: 00 00       NOP
0x0002: 00 FF 00 11 MOV AX, 0x00FF
0x0006: 00 0F 00 11 MOV BX, 0x000F
```

---

## Codegen

The codegen module (`src/codegen.zig`) provides ISA encoding functions (`encode16`, `encode32`, `encodeAlu`, etc.) used both by the emulator tests and by the firmware generator (`src/kernel.zig`). The codegen tests (`src/codegen_test.zig`, ~55 tests) verify that every encoding function produces the correct bit patterns.

```bash
zig build firmware    # Generate build/firmware.bin using codegen
zig build kernel      # Generate build/kernel.bin (shell firmware)
```

---

## Debugging

### CPU State Dump

The emulator dumps CPU state after execution (or on request):

```
=== CPU State ===
AX=0x00FF BX=0x0000 CX=0x0001 DX=0xFFF0
IP=0x0044 SP=0x0002 FLAGS=0x0000 [Z=false C=false S=false]
Halted=true
```

### Memory Dump

Memory is printed in hex format with ASCII side panel:

```
Memory dump [0x0000 - 0x0080]:
  0x0000: 00 00 00 FF 00 11 00 0F 00 15 10 A0 80 A1 C0 A2  |................|
  0x0010: 00 31 00 00 00 32 50 00 80 32 80 00 00 95 E0 ...  |.1...2P..2......|
```

### Adding Debug Prints

To add custom debug output, use `std.debug.print()` in `cpu.zig`:

```zig
pub fn step(self: *CPU) !void {
    std.debug.print("IP=0x{X:0>4} ", .{self.ip});
    // ... existing code ...
}
```
