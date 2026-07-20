/// Tests for high-level assembly wrappers.
///
/// This file contains all tests for the asm.zig wrappers module.
const std = @import("std");
const asm_ = @import("asm.zig");
const ISA = @import("codegen.zig").ISA;

// =============================================================================
// Memory Instruction Tests
// =============================================================================

test "mov_imm generates correct u32" {
    const result = asm_.mov_imm(.AX, 0x1234);
    try std.testing.expectEqual(@as(u32, 0x12123400), result);
}

test "mov_reg generates correct u16" {
    const result = asm_.mov(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0x0010), result);
}

test "all registers work with mov_imm" {
    const tests_arr = [_]struct { reg: ISA.Register, expected: u32 }{
        .{ .reg = .AX, .expected = 0x12123400 },
        .{ .reg = .BX, .expected = 0x13123400 },
        .{ .reg = .CX, .expected = 0x14123400 },
        .{ .reg = .DX, .expected = 0x15123400 },
    };
    for (tests_arr) |t| {
        const result = asm_.mov_imm(t.reg, 0x1234);
        try std.testing.expectEqual(t.expected, result);
    }
}

// =============================================================================
// ALU Instruction Tests
// =============================================================================

test "add generates correct u16" {
    const result = asm_.add(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA010), result);
}

test "adc generates correct u16" {
    const result = asm_.adc(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA410), result);
}

test "sub generates correct u16" {
    const result = asm_.sub(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA110), result);
}

test "sbb generates correct u16" {
    const result = asm_.sbb(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA510), result);
}

test "cmp generates correct u16" {
    const result = asm_.cmp(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA210), result);
}

test "and generates correct u16" {
    const result = asm_.@"and"(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA610), result);
}

test "or generates correct u16" {
    const result = asm_.@"or"(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA710), result);
}

test "xor generates correct u16" {
    const result = asm_.xor(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA810), result);
}

test "shl generates correct u16" {
    const result = asm_.shl(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA910), result);
}

test "shr generates correct u16" {
    const result = asm_.shr(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xAA10), result);
}

test "inc generates correct u16" {
    const result = asm_.inc(.AX);
    try std.testing.expectEqual(@as(u16, 0xAB00), result);
}

test "dec generates correct u16" {
    const result = asm_.dec(.AX);
    try std.testing.expectEqual(@as(u16, 0xAC00), result);
}

test "not generates correct u16" {
    const result = asm_.not(.AX);
    try std.testing.expectEqual(@as(u16, 0xAD00), result);
}

test "neg generates correct u16" {
    const result = asm_.neg(.AX);
    try std.testing.expectEqual(@as(u16, 0xAE00), result);
}

test "test generates correct u16" {
    const result = asm_.test_(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA310), result);
}

test "xchg generates correct u16" {
    const result = asm_.xchg(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xAF10), result);
}

test "all registers work with add" {
    const tests_arr = [_]struct { dst: ISA.Register, src: ISA.Register, expected: u16 }{
        .{ .dst = .AX, .src = .BX, .expected = 0xA010 },
        .{ .dst = .BX, .src = .CX, .expected = 0xA060 },
        .{ .dst = .CX, .src = .DX, .expected = 0xA0B0 },
        .{ .dst = .DX, .src = .AX, .expected = 0xA0C0 },
    };
    for (tests_arr) |t| {
        const result = asm_.add(t.dst, t.src);
        try std.testing.expectEqual(t.expected, result);
    }
}

// =============================================================================
// Stack Instruction Tests
// =============================================================================

test "push generates correct u16" {
    const result = asm_.push(.AX);
    try std.testing.expectEqual(@as(u16, 0xC000), result);
}

test "pop generates correct u16" {
    const result = asm_.pop(.AX);
    try std.testing.expectEqual(@as(u16, 0xC100), result);
}

test "all registers work with push/pop" {
    const tests_arr = [_]struct { reg: ISA.Register, push_exp: u16, pop_exp: u16 }{
        .{ .reg = .AX, .push_exp = 0xC000, .pop_exp = 0xC100 },
        .{ .reg = .BX, .push_exp = 0xC040, .pop_exp = 0xC140 },
        .{ .reg = .CX, .push_exp = 0xC080, .pop_exp = 0xC180 },
        .{ .reg = .DX, .push_exp = 0xC0C0, .pop_exp = 0xC1C0 },
    };
    for (tests_arr) |t| {
        const push_result = asm_.push(t.reg);
        const pop_result = asm_.pop(t.reg);
        try std.testing.expectEqual(t.push_exp, push_result);
        try std.testing.expectEqual(t.pop_exp, pop_result);
    }
}

// =============================================================================
// Control Flow Instruction Tests
// =============================================================================

test "jmp generates correct u32" {
    const result = asm_.jmp(0x0100);
    try std.testing.expectEqual(@as(u32, 0x21001000), result);
}

test "call generates correct u32" {
    const result = asm_.call(0x0100);
    try std.testing.expectEqual(@as(u32, 0x31001000), result);
}

test "ret generates correct u16" {
    const result = asm_.ret();
    try std.testing.expectEqual(@as(u16, 0x4000), result);
}

test "jz generates correct u32" {
    const result = asm_.jz(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1000100), result);
}

test "jnz generates correct u32" {
    const result = asm_.jnz(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1100100), result);
}

test "jc generates correct u32" {
    const result = asm_.jc(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1200100), result);
}

test "jnc generates correct u32" {
    const result = asm_.jnc(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1300100), result);
}

test "js generates correct u32" {
    const result = asm_.js(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1400100), result);
}

test "jns generates correct u32" {
    const result = asm_.jns(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1500100), result);
}

// =============================================================================
// System Instruction Tests
// =============================================================================

test "nop generates correct u16" {
    const result = asm_.nop();
    try std.testing.expectEqual(@as(u16, 0x0000), result);
}

test "hlt generates correct u16" {
    const result = asm_.hlt();
    try std.testing.expectEqual(@as(u16, 0x0070), result);
}

test "in generates correct u32" {
    const result = asm_.@"in"(.AX, 0x00);
    try std.testing.expectEqual(@as(u32, 0x81000000), result);
}

test "out generates correct u32" {
    const result = asm_.out(0x00, .AX);
    try std.testing.expectEqual(@as(u32, 0x91000000), result);
}

// =============================================================================
// Utility Function Tests
// =============================================================================

test "clear generates correct u16" {
    const result = asm_.clear(.AX);
    try std.testing.expectEqual(@as(u16, 0xA800), result);
}

test "nops generates array of NOPs" {
    const result = asm_.nops(3);
    try std.testing.expectEqual(@as(u16, 0x0000), result[0]);
    try std.testing.expectEqual(@as(u16, 0x0000), result[1]);
    try std.testing.expectEqual(@as(u16, 0x0000), result[2]);
}

// =============================================================================
// Integration Tests — Program Patterns
// =============================================================================

test "example program compiles and has correct sizes" {
    const program = [_]u16{
        asm_.nop(),
        @truncate(asm_.mov_imm(.AX, 0x1234)),
        @truncate(asm_.mov_imm(.BX, 0x5678)),
        asm_.add(.AX, .BX),
        asm_.mov(.CX, .AX),
        asm_.push(.AX),
        asm_.push(.BX),
        asm_.pop(.DX),
        asm_.pop(.CX),
        asm_.hlt(),
    };
    try std.testing.expectEqual(@as(usize, 10), program.len);
}

test "loop pattern with conditional jumps" {
    const loop_start: u16 = 0x0010;
    const loop_end: u16 = 0x0020;

    const loop_body = [_]u32{
        asm_.jz(loop_end),
        asm_.jnz(loop_start),
        asm_.jc(loop_end),
        asm_.jnc(loop_start),
        asm_.js(loop_end),
        asm_.jns(loop_start),
    };

    try std.testing.expectEqual(@as(usize, 6), loop_body.len);
    for (loop_body) |inst| {
        try std.testing.expect(inst != 0);
    }
}

test "subroutine call pattern" {
    const subroutine_addr: u16 = 0x0100;

    const call_pattern = [_]u32{
        asm_.mov_imm(.AX, 0x0001),
        asm_.call(subroutine_addr),
        asm_.mov_imm(.BX, 0x0002),
        asm_.hlt(),
    };

    try std.testing.expectEqual(@as(usize, 4), call_pattern.len);
}

test "stack operations pattern" {
    const stack_ops = [_]u16{
        asm_.push(.AX),
        asm_.push(.BX),
        asm_.push(.CX),
        asm_.pop(.DX),
        asm_.pop(.CX),
        asm_.pop(.BX),
    };

    try std.testing.expectEqual(@as(usize, 6), stack_ops.len);
}

test "ALU operations pattern" {
    const alu_ops = [_]u16{
        asm_.add(.AX, .BX),
        asm_.sub(.AX, .BX),
        asm_.@"and"(.AX, .BX),
        asm_.@"or"(.AX, .BX),
        asm_.xor(.AX, .BX),
        asm_.shl(.AX, .BX),
        asm_.shr(.AX, .BX),
        asm_.inc(.AX),
        asm_.dec(.AX),
        asm_.not(.AX),
        asm_.neg(.AX),
        asm_.cmp(.AX, .BX),
        asm_.test_(.AX, .BX),
    };

    try std.testing.expectEqual(@as(usize, 16), alu_ops.len);
}

test "complex program with loops and subroutines" {
    const program = [_]u16{
        // Initialize
        asm_.nop(),
        @truncate(asm_.mov_imm(.AX, 0x0000)),
        @truncate(asm_.mov_imm(.BX, 0x000A)),

        // Loop: AX += BX
        asm_.add(.AX, .BX),
        asm_.cmp(.AX, .BX),
        asm_.jz(0x0020),

        // Subroutine call
        asm_.call(0x0100),
        asm_.mov(.CX, .AX),

        // Stack operations
        asm_.push(.AX),
        asm_.push(.BX),
        asm_.pop(.DX),
        asm_.pop(.CX),

        // Halt
        asm_.hlt(),
    };

    try std.testing.expect(program.len > 0);
}

// =============================================================================
// Shift Immediate Tests
// =============================================================================

test "shl_imm generates correct instructions" {
    const result = asm_.shl_imm(.AX, 3);
    try std.testing.expectEqual(@as(u32, 0x19000300), result[0]); // MOV CX, 3
    try std.testing.expectEqual(@as(u32, 0xA920), @as(u32, result[1])); // SHL AX, CX
}

test "shr_imm generates correct instructions" {
    const result = asm_.shr_imm(.BX, 2);
    try std.testing.expectEqual(@as(u32, 0x19000200), result[0]); // MOV CX, 2
    try std.testing.expectEqual(@as(u32, 0xAA60), @as(u32, result[1])); // SHR BX, CX
}

// =============================================================================
// Compare + Branch Alias Tests
// =============================================================================

test "je generates correct u32" {
    const result = asm_.je(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1000100), result);
}

test "jne generates correct u32" {
    const result = asm_.jne(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1100100), result);
}

test "jge generates correct u32" {
    const result = asm_.jge(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1500100), result);
}

test "jl generates correct u32" {
    const result = asm_.jl(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1400100), result);
}

test "ja generates correct u32" {
    const result = asm_.ja(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1300100), result);
}

test "jbe generates correct u32" {
    const result = asm_.jbe(0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1200100), result);
}

// =============================================================================
// Push/Pop Pair Tests
// =============================================================================

test "push2 generates correct u16 pair" {
    const result = asm_.push2(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xC000), result[0]); // PUSH AX
    try std.testing.expectEqual(@as(u16, 0xC040), result[1]); // PUSH BX
}

test "pop2 generates correct u16 pair" {
    const result = asm_.pop2(.AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xC140), result[0]); // POP BX
    try std.testing.expectEqual(@as(u16, 0xC100), result[1]); // POP AX
}

test "push4 generates correct u16 quad" {
    const result = asm_.push4(.AX, .BX, .CX, .DX);
    try std.testing.expectEqual(@as(u16, 0xC000), result[0]);
    try std.testing.expectEqual(@as(u16, 0xC040), result[1]);
    try std.testing.expectEqual(@as(u16, 0xC080), result[2]);
    try std.testing.expectEqual(@as(u16, 0xC0C0), result[3]);
}

test "pop4 generates correct u16 quad" {
    const result = asm_.pop4(.AX, .BX, .CX, .DX);
    try std.testing.expectEqual(@as(u16, 0xC1C0), result[0]);
    try std.testing.expectEqual(@as(u16, 0xC180), result[1]);
    try std.testing.expectEqual(@as(u16, 0xC140), result[2]);
    try std.testing.expectEqual(@as(u16, 0xC100), result[3]);
}

// =============================================================================
// I/O Helper Tests
// =============================================================================

test "out_char generates correct u32" {
    const result = asm_.out_char(.AX);
    try std.testing.expectEqual(@as(u32, 0x90000000), result);
}

test "in_char generates correct u32" {
    const result = asm_.in_char(.AX);
    try std.testing.expectEqual(@as(u32, 0x80000000), result);
}

// =============================================================================
// INT Test
// =============================================================================

test "int generates correct u32" {
    const result = asm_.int(0x03);
    try std.testing.expectEqual(@as(u32, 0x50000300), result);
}
