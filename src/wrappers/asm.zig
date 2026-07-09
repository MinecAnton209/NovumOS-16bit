/// High-level assembly wrappers for NovumOS-16bit ISA.
///
/// This module provides convenient functions for generating machine code
/// without having to call raw encode functions directly.
///
/// Usage:
///   const asm = @import("asm.zig");
///   const program = [_]u16{
///       asm.mov_imm(.AX, 0x1234),
///       asm.add(.AX, .BX),
///       asm.hlt(),
///   };
const std = @import("std");
const ISA = @import("codegen.zig").ISA;

// =============================================================================
// Memory Instructions
// =============================================================================

/// MOV reg, immediate — Load 16-bit constant into register (32-bit instruction).
/// Example: MOV AX, 0x1234
pub fn mov_imm(dst: ISA.Register, imm: u16) u32 {
    return ISA.encode32(.MOV, dst, imm);
}

/// MOV dst, src — Copy value from src register to dst register.
/// Example: MOV AX, BX
pub fn mov(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encode16(.MOV, dst, src, .RegReg);
}

/// MOV dst, [src] — Load value from memory address in src into dst.
/// Example: MOV AX, [BX]
pub fn mov_load(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encode16(.MOV, dst, src, .Indirect);
}

/// MOV dst, [src+off] — Load value from memory with offset.
/// FIXME: encode32 hardcodes mode=Imm. Need proper32-bit IndirectOff encoding.
pub fn mov_load_off(dst: ISA.Register, src: ISA.Register, offset: u16) u32 {
    _ = dst;
    _ = src;
    _ = offset;
    return 0; // TODO: implement proper32-bit indirect+offset encoding
}

// =============================================================================
// ALU Instructions — Register to Register
// =============================================================================

/// ADD dst, src — dst = dst + src
pub fn add(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.ADD, dst, src);
}

/// SUB dst, src — dst = dst - src
pub fn sub(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.SUB, dst, src);
}

/// CMP dst, src — Compare (sets flags, result discarded)
pub fn cmp(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.CMP, dst, src);
}

/// AND dst, src — dst = dst AND src
pub fn @"and"(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.AND, dst, src);
}

/// OR dst, src — dst = dst OR src
pub fn @"or"(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.OR, dst, src);
}

/// XOR dst, src — dst = dst XOR src
pub fn xor(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.XOR, dst, src);
}

/// SHL dst, src — dst = dst << src
pub fn shl(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.SHL, dst, src);
}

/// SHR dst, src — dst = dst >> src
pub fn shr(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.SHR, dst, src);
}

/// INC dst — dst = dst + 1
pub fn inc(dst: ISA.Register) u16 {
    return ISA.encodeAlu(.INC, dst, .AX);
}

/// DEC dst — dst = dst - 1
pub fn dec(dst: ISA.Register) u16 {
    return ISA.encodeAlu(.DEC, dst, .AX);
}

/// NOT dst — dst = NOT dst (bitwise complement)
pub fn not(dst: ISA.Register) u16 {
    return ISA.encodeAlu(.NOT, dst, .AX);
}

/// NEG dst — dst = 0 - dst (two's complement negate)
pub fn neg(dst: ISA.Register) u16 {
    return ISA.encodeAlu(.NEG, dst, .AX);
}

/// XCHG dst, src — Swap values in dst and src registers
pub fn xchg(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.XCHG, dst, src);
}

/// ADC dst, src — dst = dst + src + Carry
pub fn adc(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.ADC, dst, src);
}

/// SBB dst, src — dst = dst - src - Carry
pub fn sbb(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.SBB, dst, src);
}

/// TEST dst, src — Bitwise AND (result discarded, flags only)
pub fn test_(dst: ISA.Register, src: ISA.Register) u16 {
    return ISA.encodeAlu(.TEST, dst, src);
}

// =============================================================================
// Stack Instructions
// =============================================================================

/// PUSH reg — Push register value onto stack
pub fn push(reg: ISA.Register) u16 {
    return ISA.encodePushPop(.PUSH, reg);
}

/// POP reg — Pop value from stack into register
pub fn pop(reg: ISA.Register) u16 {
    return ISA.encodePushPop(.POP, reg);
}

// =============================================================================
// Control Flow Instructions
// =============================================================================

/// JMP target — Unconditional jump to address
pub fn jmp(target: u16) u32 {
    return ISA.encode32(.JMP, .AX, target);
}

/// JMP reg — Jump to address in register
pub fn jmp_reg(reg: ISA.Register) u16 {
    return ISA.encode16(.JMP, .AX, reg, .RegReg);
}

/// CALL target — Call subroutine at address
pub fn call(target: u16) u32 {
    return ISA.encode32(.CALL, .AX, target);
}

/// RET — Return from subroutine
pub fn ret() u16 {
    return ISA.encode16(.RET, .AX, .AX, .RegReg);
}

/// JZ target — Jump if Zero flag set
pub fn jz(target: u16) u32 {
    return ISA.encodeCondJump(.JZ, target);
}

/// JNZ target — Jump if Zero flag clear
pub fn jnz(target: u16) u32 {
    return ISA.encodeCondJump(.JNZ, target);
}

/// JC target — Jump if Carry flag set
pub fn jc(target: u16) u32 {
    return ISA.encodeCondJump(.JC, target);
}

/// JNC target — Jump if Carry flag clear
pub fn jnc(target: u16) u32 {
    return ISA.encodeCondJump(.JNC, target);
}

/// JS target — Jump if Sign flag set (negative result)
pub fn js(target: u16) u32 {
    return ISA.encodeCondJump(.JS, target);
}

/// JNS target — Jump if Sign flag clear (positive result)
pub fn jns(target: u16) u32 {
    return ISA.encodeCondJump(.JNS, target);
}

// =============================================================================
// System Instructions
// =============================================================================

/// NOP — No operation
pub fn nop() u16 {
    return ISA.encode16(.NOP, .AX, .AX, .RegReg);
}

/// HLT — Halt CPU
pub fn hlt() u16 {
    return ISA.encode16(.HLT, .AX, .AX, .RegReg);
}

/// IN reg, port — Read from I/O port into register
pub fn in(reg: ISA.Register, port: u16) u32 {
    return ISA.encode32(.IN, reg, port);
}

/// OUT port, reg — Write register value to I/O port
pub fn out(port: u16, reg: ISA.Register) u32 {
    return ISA.encode32(.OUT, reg, port);
}

/// INT vector — Software interrupt. Handler at vector * 4.
pub fn int(vector: u16) u32 {
    return ISA.encode32(.INT, .AX, vector);
}

/// IRET — Return from interrupt
pub fn iret() u16 {
    return ISA.encode16(.IRET, .AX, .AX, .RegReg);
}

// =============================================================================
// Utility Functions
// =============================================================================

/// MOV reg, 0 — Clear register (uses XOR trick)
pub fn clear(reg: ISA.Register) u16 {
    return ISA.encodeAlu(.XOR, reg, reg);
}

/// NOP x n — Insert n NOP instructions
pub fn nops(comptime n: usize) [n]u16 {
    var result: [n]u16 = undefined;
    for (&result) |*inst| {
        inst.* = nop();
    }
    return result;
}

// =============================================================================
// Shift by Immediate (uses CX as shift count holder)
// =============================================================================

/// SHL reg, imm — Shift left by immediate. Clobbers CX.
pub fn shl_imm(reg: ISA.Register, imm: u4) [2]u32 {
    return .{ mov_imm(.CX, imm), encodeAluRaw(.SHL, reg, .CX) };
}

/// SHR reg, imm — Shift right by immediate. Clobbers CX.
pub fn shr_imm(reg: ISA.Register, imm: u4) [2]u32 {
    return .{ mov_imm(.CX, imm), encodeAluRaw(.SHR, reg, .CX) };
}

fn encodeAluRaw(alu: ISA.AluOp, dst: ISA.Register, src: ISA.Register) u32 {
    return @as(u32, ISA.encodeAlu(alu, dst, src));
}

// =============================================================================
// Compare + Branch Aliases
// =============================================================================

/// JE target — Jump if Equal (alias for JZ)
pub fn je(target: u16) u32 {
    return ISA.encodeCondJump(.JZ, target);
}

/// JNE target — Jump if Not Equal (alias for JNZ)
pub fn jne(target: u16) u32 {
    return ISA.encodeCondJump(.JNZ, target);
}

/// JGE target — Jump if Greater or Equal (signed, alias for JNS)
pub fn jge(target: u16) u32 {
    return ISA.encodeCondJump(.JNS, target);
}

/// JL target — Jump if Less (signed, alias for JS)
pub fn jl(target: u16) u32 {
    return ISA.encodeCondJump(.JS, target);
}

/// JA target — Jump if Above (unsigned, alias for JNC)
pub fn ja(target: u16) u32 {
    return ISA.encodeCondJump(.JNC, target);
}

/// JBE target — Jump if Below or Equal (unsigned, alias for JC)
pub fn jbe(target: u16) u32 {
    return ISA.encodeCondJump(.JC, target);
}

// =============================================================================
// Stack — Push/Pop Pairs
// =============================================================================

/// PUSH2 a, b — Push two registers onto stack
pub fn push2(a: ISA.Register, b: ISA.Register) [2]u16 {
    return .{ push(a), push(b) };
}

/// POP2 a, b — Pop two registers from stack (reverse order)
pub fn pop2(a: ISA.Register, b: ISA.Register) [2]u16 {
    return .{ pop(b), pop(a) };
}

/// PUSH4 a, b, c, d — Push four registers
pub fn push4(a: ISA.Register, b: ISA.Register, c: ISA.Register, d: ISA.Register) [4]u16 {
    return .{ push(a), push(b), push(c), push(d) };
}

/// POP4 a, b, c, d — Pop four registers (reverse order)
pub fn pop4(a: ISA.Register, b: ISA.Register, c: ISA.Register, d: ISA.Register) [4]u16 {
    return .{ pop(d), pop(c), pop(b), pop(a) };
}

// =============================================================================
// I/O Output Helpers (UART on port 0x00)
// =============================================================================

/// OUT_CHAR reg — Write register value to UART (port 0x00)
pub fn out_char(reg: ISA.Register) u32 {
    return ISA.encode32(.OUT, reg, 0x0000);
}

/// IN_CHAR reg — Read byte from UART (port 0x00) into register
pub fn in_char(reg: ISA.Register) u32 {
    return ISA.encode32(.IN, reg, 0x0000);
}

// =============================================================================
// Software Multiply / Divide (CPU has no MUL/DIV instructions)
// =============================================================================
// TODO: Implement when Program Builder is ready.
// mul/div require runtime code generation with loops and forward jumps,
// which cannot be expressed as comptime instruction arrays.
