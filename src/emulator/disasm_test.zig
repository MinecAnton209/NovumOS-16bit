const std = @import("std");
const ISA = @import("codegen");
const Disassembler = @import("disasm.zig").Disassembler;

/// Helper: write a 16-bit word into a byte buffer at the given offset (little-endian).
fn write16(buf: []u8, offset: u16, val: u16) void {
    buf[offset] = @intCast(val & 0xFF);
    buf[offset + 1] = @intCast((val >> 8) & 0xFF);
}

/// Helper: write a 32-bit word into a byte buffer at the given offset (little-endian).
fn write32(buf: []u8, offset: u16, val: u32) void {
    buf[offset] = @intCast(val & 0xFF);
    buf[offset + 1] = @intCast((val >> 8) & 0xFF);
    buf[offset + 2] = @intCast((val >> 16) & 0xFF);
    buf[offset + 3] = @intCast((val >> 24) & 0xFF);
}

/// Helper: extract null-terminated text from disassembly result.
fn getText(result: anytype) []const u8 {
    var len: usize = 0;
    while (len < result.text.len and result.text[len] != 0) : (len += 1) {}
    return result.text[0..len];
}

// =============================================================================
// 16-bit Instruction Decoding
// =============================================================================

test "disasm: NOP" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("NOP", getText(&r));
}

test "disasm: HLT" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.HLT, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("HLT", getText(&r));
}

test "disasm: RET" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.RET, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("RET", getText(&r));
}

test "disasm: IRET" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.IRET, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("IRET", getText(&r));
}

test "disasm: MOV reg, reg — AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .AX, .BX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("MOV AX, BX", getText(&r));
}

test "disasm: MOV DX, CX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .DX, .CX, .RegReg));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV DX, CX", getText(&r));
}

// =============================================================================
// 16-bit ALU Instructions
// =============================================================================

test "disasm: ADD AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.ADD, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("ADD AX, BX", getText(&r));
}

test "disasm: SUB CX, DX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.SUB, .CX, .DX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("SUB CX, DX", getText(&r));
}

test "disasm: CMP AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.CMP, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("CMP AX, BX", getText(&r));
}

test "disasm: AND AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.AND, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("AND AX, BX", getText(&r));
}

test "disasm: OR AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.OR, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("OR AX, BX", getText(&r));
}

test "disasm: XOR AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.XOR, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("XOR AX, BX", getText(&r));
}

test "disasm: SHL AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("SHL AX, BX", getText(&r));
}

test "disasm: SHR AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.SHR, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("SHR AX, BX", getText(&r));
}

test "disasm: INC AX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.INC, .AX, .AX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("INC AX, AX", getText(&r));
}

test "disasm: DEC BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.DEC, .BX, .AX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("DEC BX, AX", getText(&r));
}

test "disasm: NOT CX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.NOT, .CX, .CX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("NOT CX, CX", getText(&r));
}

test "disasm: NEG DX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.NEG, .DX, .DX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("NEG DX, DX", getText(&r));
}

test "disasm: XCHG AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.XCHG, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("XCHG AX, BX", getText(&r));
}

test "disasm: ADC AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.ADC, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("ADC AX, BX", getText(&r));
}

test "disasm: SBB AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.SBB, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("SBB AX, BX", getText(&r));
}

test "disasm: TEST AX, BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodeAlu(.TEST, .AX, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("TEST AX, BX", getText(&r));
}

// =============================================================================
// 16-bit PUSH/POP
// =============================================================================

test "disasm: PUSH AX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodePushPop(.PUSH, .AX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("PUSH AX", getText(&r));
}

test "disasm: POP BX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodePushPop(.POP, .BX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("POP BX", getText(&r));
}

test "disasm: PUSH DX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodePushPop(.PUSH, .DX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("PUSH DX", getText(&r));
}

// =============================================================================
// 32-bit MOV reg, imm (only MOV detected as 32-bit by heuristic)
// =============================================================================

test "disasm: MOV AX, 0x00FF" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .AX, 0x00FF));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("MOV AX, 0x00FF", getText(&r));
}

test "disasm: MOV BX, 0x1234" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .BX, 0x1234));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV BX, 0x1234", getText(&r));
}

test "disasm: MOV CX, 0x0000" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .CX, 0x0000));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV CX, 0x0000", getText(&r));
}

// =============================================================================
// Multi-instruction Disassembly
// =============================================================================

test "disasm: sequence — MOV, MOV, SUB, HLT" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    // MOV AX, 5 (32-bit)
    write32(&mem, 0, ISA.encode32(.MOV, .AX, 5));
    // MOV BX, 3 (32-bit)
    write32(&mem, 4, ISA.encode32(.MOV, .BX, 3));
    // SUB AX, BX (16-bit)
    write16(&mem, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // HLT (16-bit)
    write16(&mem, 10, ISA.encode16(.HLT, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);

    var r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV AX, 0x0005", getText(&r));

    r = dis.disassemble(4);
    try std.testing.expectEqualStrings("MOV BX, 0x0003", getText(&r));

    r = dis.disassemble(8);
    try std.testing.expectEqualStrings("SUB AX, BX", getText(&r));

    r = dis.disassemble(10);
    try std.testing.expectEqualStrings("HLT", getText(&r));
}
