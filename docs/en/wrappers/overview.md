# Assembly Wrappers

High-level Zig wrappers for the NovumOS-16bit ISA. Provides convenient functions that generate machine code without calling raw encode functions directly.

**Source:** `src/wrappers/asm.zig` (tests: `src/wrappers/test.zig`)

---

## Usage

```zig
const asm_ = @import("wrappers/asm.zig");

const program = [_]u16{
    asm_.nop(),
    @truncate(asm_.mov_imm(.AX, 0x1234)),
    @truncate(asm_.mov_imm(.BX, 0x5678)),
    asm_.add(.AX, .BX),
    asm_.push(.AX),
    asm_.call(0x0100),
    asm_.hlt(),
};
```

**Note:** `mov_imm` returns `u32` (32-bit instruction). Use `@truncate` when embedding in a `u16` array — only the low 16 bits are stored.

---

## Memory Instructions

| Function | Returns | Description |
|----------|---------|-------------|
| `mov_imm(dst, imm)` | `u32` | `MOV dst, imm16` — load 16-bit immediate |
| `mov(dst, src)` | `u16` | `MOV dst, src` — register to register |
| `mov_load(dst, src)` | `u16` | `MOV dst, [src]` — load from memory |
| `mov_load_off(dst, src, off)` | `u32` | `MOV dst, [src+off]` — load with offset **(FIXME: encoding broken)** |

---

## ALU Instructions

All ALU functions return `u16`.

| Function | Instruction | Description |
|----------|-------------|-------------|
| `add(dst, src)` | `ADD dst, src` | dst = dst + src |
| `sub(dst, src)` | `SUB dst, src` | dst = dst - src |
| `cmp(dst, src)` | `CMP dst, src` | Compare (sets flags only) |
| `and(dst, src)` | `AND dst, src` | dst = dst AND src |
| `or(dst, src)` | `OR dst, src` | dst = dst OR src |
| `xor(dst, src)` | `XOR dst, src` | dst = dst XOR src |
| `shl(dst, src)` | `SHL dst, src` | dst = dst << src |
| `shr(dst, src)` | `SHR dst, src` | dst = dst >> src |
| `inc(dst)` | `INC dst` | dst = dst + 1 |
| `dec(dst)` | `DEC dst` | dst = dst - 1 |
| `not(dst)` | `NOT dst` | dst = NOT dst |
| `neg(dst)` | `NEG dst` | dst = 0 - dst |
| `xchg(dst, src)` | `XCHG dst, src` | Swap dst and src |
| `adc(dst, src)` | `ADC dst, src` | dst = dst + src + Carry |
| `sbb(dst, src)` | `SBB dst, src` | dst = dst - src - Carry |
| `test_(dst, src)` | `TEST dst, src` | Bitwise AND (flags only) |

**Note:** `test_` has underscore suffix because `test` is a Zig keyword.

---

## Shift by Immediate

Clobbers CX to hold the shift count.

| Function | Returns | Description |
|----------|---------|-------------|
| `shl_imm(reg, imm)` | `[2]u32` | `MOV CX, imm; SHL reg, CX` |
| `shr_imm(reg, imm)` | `[2]u32` | `MOV CX, imm; SHR reg, CX` |

---

## Compare + Branch Aliases

Convenience aliases for conditional jumps. All return `u32`.

| Function | Alias for | Condition |
|----------|-----------|-----------|
| `je(target)` | `JZ` | Equal (Zero flag set) |
| `jne(target)` | `JNZ` | Not Equal (Zero flag clear) |
| `jge(target)` | `JNS` | Greater or Equal (signed) |
| `jl(target)` | `JS` | Less (signed) |
| `ja(target)` | `JNC` | Above (unsigned) |
| `jbe(target)` | `JC` | Below or Equal (unsigned) |

Original jumps also available: `jz`, `jnz`, `jc`, `jnc`, `js`, `jns`.

---

## Stack Instructions

| Function | Returns | Description |
|----------|---------|-------------|
| `push(reg)` | `u16` | PUSH single register |
| `pop(reg)` | `u16` | POP single register |
| `push2(a, b)` | `[2]u16` | PUSH two registers |
| `pop2(a, b)` | `[2]u16` | POP two registers (reverse order) |
| `push4(a, b, c, d)` | `[4]u16` | PUSH four registers |
| `pop4(a, b, c, d)` | `[4]u16` | POP four registers (reverse order) |

**Note:** `pop2` and `pop4` pop in reverse order of push (LIFO).

---

## Control Flow

| Function | Returns | Description |
|----------|---------|-------------|
| `jmp(target)` | `u32` | Unconditional jump |
| `jmp_reg(reg)` | `u16` | Jump to address in register |
| `call(target)` | `u32` | Call subroutine |
| `ret()` | `u16` | Return from subroutine |

---

## I/O Instructions

| Function | Returns | Description |
|----------|---------|-------------|
| `out(port, reg)` | `u32` | Write register to I/O port |
| `in(reg, port)` | `u32` | Read I/O port into register |
| `out_char(reg)` | `u32` | Write register to UART (port 0x00) |
| `in_char(reg)` | `u32` | Read from UART (port 0x00) |

---

## System Instructions

| Function | Returns | Description |
|----------|---------|-------------|
| `nop()` | `u16` | No operation |
| `hlt()` | `u16` | Halt CPU |
| `int(vector)` | `u32` | Software interrupt (handler at vector × 4) |
| `iret()` | `u16` | Return from interrupt |

---

## Utility Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `clear(reg)` | `u16` | Clear register (XOR reg, reg) |
| `nops(n)` | `[n]u16` | Insert n NOP instructions |

---

## Software Multiply / Divide

**Not yet implemented.** CPU has no MUL/DIV instructions. Requires Program Builder with runtime loop generation (forward jumps cannot be expressed as comptime arrays).

TODO: Implement shift-and-add multiply and restoring divide when Program Builder is ready.

---

## Test Coverage

23 wrapper tests covering all instruction types:
- Memory (mov_imm, mov, mov_load)
- ALU (all 16 operations)
- Shift immediate (shl_imm, shr_imm)
- Compare+Branch aliases (je, jne, jge, jl, ja, jbe)
- Stack pairs (push2, pop2, push4, pop4)
- I/O helpers (out_char, in_char)
- System (int, nop, hlt, clear, nops)
