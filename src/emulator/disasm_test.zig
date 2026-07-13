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
// 16-bit Instruction Size Verification
// =============================================================================

// Extended instructions (with immediate/offset) should report size=4.
// Non-extended should report size=2.

test "disasm: JMP imm is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.JMP, .AX, .AX, .Imm));
    write16(&mem, 2, 0x0050);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("JMP 0x0050", getText(&r));
}

test "disasm: CALL imm is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.CALL, .AX, .AX, .Imm));
    write16(&mem, 2, 0x0050);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("CALL 0x0050", getText(&r));
}

test "disasm: INT imm is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.INT, .AX, .AX, .Imm));
    write16(&mem, 2, 0x0021);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("INT 0x0021", getText(&r));
}

test "disasm: IN AX, 0x22 is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.IN, .AX, .AX, .Imm));
    write16(&mem, 2, 0x0022);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("IN AX, 0x0022", getText(&r));
}

test "disasm: OUT 0x22, AX is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.OUT, .AX, .AX, .Imm));
    write16(&mem, 2, 0x0022);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("OUT 0x0022, AX", getText(&r));
}

test "disasm: MOV indirect is 2 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .AX, .BX, .Indirect));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("MOV AX, [BX]", getText(&r));
}

test "disasm: MOV indirect-offset is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .AX, .BX, .IndirectOff));
    write16(&mem, 2, 0x0004);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("MOV AX, [BX+0x0004]", getText(&r));
}

test "disasm: MOV imm 16-bit is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
    write16(&mem, 2, 0x1234);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("MOV AX, 0x1234", getText(&r));
}

test "disasm: MOV reg,indirect is 2 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .BX, .DX, .Indirect));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("MOV BX, [DX]", getText(&r));
}

// =============================================================================
// 16-bit CondJump Disassembly
// =============================================================================

test "disasm: JZ 16-bit is 4 bytes" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    const word: u16 = (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(ISA.CondJump.JZ)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
    write16(&mem, 0, word);
    write16(&mem, 2, 0x0040);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("JZ 0x0040", getText(&r));
}

test "disasm: JNZ 16-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    const word: u16 = (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(ISA.CondJump.JNZ)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
    write16(&mem, 0, word);
    write16(&mem, 2, 0x0080);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNZ 0x0080", getText(&r));
}

// =============================================================================
// 32-bit Addressing Mode Disassembly
// =============================================================================

test "disasm: CALL 0x0020 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.CALL, .AX, 0x0020));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("CALL 0x0020", getText(&r));
}

test "disasm: INT 0x0021 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.INT, .AX, 0x0021));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("INT 0x0021", getText(&r));
}

test "disasm: IN AX, 0x0022 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.IN, .AX, 0x0022));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("IN AX, 0x0022", getText(&r));
}

test "disasm: OUT 0x0000, AX 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.OUT, .AX, 0x0000));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("OUT 0x0000, AX", getText(&r));
}

test "disasm: JZ 0x0040 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JZ, 0x0040));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("JZ 0x0040", getText(&r));
}

test "disasm: JNZ 0x0080 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JNZ, 0x0080));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNZ 0x0080", getText(&r));
}

test "disasm: JC 0x0100 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JC, 0x0100));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JC 0x0100", getText(&r));
}

test "disasm: JNC 0x0200 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JNC, 0x0200));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNC 0x0200", getText(&r));
}

test "disasm: JS 0x0400 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JS, 0x0400));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JS 0x0400", getText(&r));
}

test "disasm: JNS 0x0800 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encodeCondJump(.JNS, 0x0800));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNS 0x0800", getText(&r));
}

// =============================================================================
// 32-bit Unknown Opcode — should fall back to DW
// =============================================================================

test "disasm: DW unknown 32-bit opcode" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    // opcode=0xC (not in 32-bit switch) with mode=01 for 32-bit detection
    const raw32: u32 = (@as(u32, 0xC) << 28) | (@as(u32, 0x01) << 24);
    write32(&mem, 0, raw32);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("DW 0x0000", getText(&r));
}

// =============================================================================
// Collapsed Range Tests — repeated instructions are grouped
// =============================================================================

// 3+ repeated instructions should be collapsed into a range line.
test "disasm: collapse 3 NOPs" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 2, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 4, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 6, ISA.encode16(.HLT, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);

    var r = dis.disassemble(0);
    try std.testing.expectEqualStrings("NOP", getText(&r));

    r = dis.disassemble(2);
    try std.testing.expectEqualStrings("NOP", getText(&r));

    r = dis.disassemble(4);
    try std.testing.expectEqualStrings("NOP", getText(&r));

    try std.testing.expectEqual(@as(u16, 3), dis.countCollapsed(0, 8));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(6, 8));
}

test "disasm: 2 NOPs not collapsed" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 2, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 4, ISA.encode16(.HLT, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 2), dis.countCollapsed(0, 6));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(4, 6));
}

test "disasm: mixed instructions not collapsed" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 2, ISA.encode16(.HLT, .AX, .AX, .RegReg));
    write16(&mem, 4, ISA.encode16(.NOP, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(0, 6));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(2, 6));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(4, 6));
}

test "disasm: collapse — 3 MOV imm into range" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .AX, 0x00FF));
    write32(&mem, 4, ISA.encode32(.MOV, .AX, 0x00FF));
    write32(&mem, 8, ISA.encode32(.MOV, .AX, 0x00FF));
    write16(&mem, 12, ISA.encode16(.HLT, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 3), dis.countCollapsed(0, 14));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(12, 14));
}

test "disasm: range boundary — collapse only up to differing instruction" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 2, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 4, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    write16(&mem, 6, ISA.encode16(.HLT, .AX, .AX, .RegReg));
    write16(&mem, 8, ISA.encode16(.HLT, .AX, .AX, .RegReg));
    write16(&mem, 10, ISA.encode16(.HLT, .AX, .AX, .RegReg));

    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 3), dis.countCollapsed(0, 12));
    try std.testing.expectEqual(@as(u16, 3), dis.countCollapsed(6, 12));
}

test "disasm: sequence — MOV, MOV, SUB, HLT" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .AX, 5));
    write32(&mem, 4, ISA.encode32(.MOV, .BX, 3));
    write16(&mem, 8, ISA.encodeAlu(.SUB, .AX, .BX));
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

    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(0, 12));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(4, 12));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(8, 12));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(10, 12));
}

// =============================================================================
// 16-bit CondJump Disassembly — All Conditions
// =============================================================================

fn condWord16(cond: ISA.CondJump) u16 {
    return (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(cond)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
}

test "disasm: JC 0x0020 16-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, condWord16(.JC));
    write16(&mem, 2, 0x0020);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("JC 0x0020", getText(&r));
}

test "disasm: JNC 0x0030 16-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, condWord16(.JNC));
    write16(&mem, 2, 0x0030);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNC 0x0030", getText(&r));
}

test "disasm: JS 0x0040 16-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, condWord16(.JS));
    write16(&mem, 2, 0x0040);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JS 0x0040", getText(&r));
}

test "disasm: JNS 0x0080 16-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, condWord16(.JNS));
    write16(&mem, 2, 0x0080);
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("JNS 0x0080", getText(&r));
}

// =============================================================================
// Additional 32-bit Disassembly Tests
// =============================================================================

test "disasm: JMP 0x0050 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.JMP, .AX, 0x0050));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 4), r.size);
    try std.testing.expectEqualStrings("JMP 0x0050", getText(&r));
}

// =============================================================================
// Additional MOV 32-bit imm Disassembly for all registers
// =============================================================================

test "disasm: MOV BX, 0x1234 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .BX, 0x1234));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV BX, 0x1234", getText(&r));
}

test "disasm: MOV CX, 0xABCD 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .CX, 0xABCD));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV CX, 0xABCD", getText(&r));
}

test "disasm: MOV DX, 0xFFFF 32-bit" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write32(&mem, 0, ISA.encode32(.MOV, .DX, 0xFFFF));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqualStrings("MOV DX, 0xFFFF", getText(&r));
}

// =============================================================================
// Additional PUSH/POP Disassembly
// =============================================================================

test "disasm: PUSH CX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodePushPop(.PUSH, .CX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("PUSH CX", getText(&r));
}

test "disasm: POP DX" {
    var mem: [4]u8 = std.mem.zeroes([4]u8);
    write16(&mem, 0, ISA.encodePushPop(.POP, .DX));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("POP DX", getText(&r));
}

// =============================================================================
// countCollapsed Boundary Cases
// =============================================================================

test "disasm: countCollapsed at end boundary" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.NOP, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(0, 2));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(2, 2));
}

test "disasm: countCollapsed single instruction" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encode16(.HLT, .AX, .AX, .RegReg));
    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(0, 2));
}

test "disasm: PUSH DX then POP CX not collapsed" {
    var mem: [256]u8 = std.mem.zeroes([256]u8);
    write16(&mem, 0, ISA.encodePushPop(.PUSH, .DX));
    write16(&mem, 2, ISA.encodePushPop(.POP, .CX));
    var dis = Disassembler.init(&mem);
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(0, 4));
    try std.testing.expectEqual(@as(u16, 1), dis.countCollapsed(2, 4));
}

test "disasm: MOV AX, [CX] 16-bit indirect" {
    var mem: [16]u8 = std.mem.zeroes([16]u8);
    write16(&mem, 0, ISA.encode16(.MOV, .AX, .CX, .Indirect));
    var dis = Disassembler.init(&mem);
    const r = dis.disassemble(0);
    try std.testing.expectEqual(@as(u8, 2), r.size);
    try std.testing.expectEqualStrings("MOV AX, [CX]", getText(&r));
}
