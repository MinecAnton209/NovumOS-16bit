const std = @import("std");

// ISA Encoding: Opcode [15:12] | Dst [11:10] | Src [9:8] | Mode [7:6] | Unused [5:0]

pub const Opcode = enum(u4) {
    NOP = 0x0,
    MOV = 0x1,
    ADD = 0x2,
    SUB = 0x3,
    AND = 0x4,
    OR = 0x5,
    XOR = 0x6,
    SHL = 0x7,
    SHR = 0x8,
    JMP = 0x9,
    JZ = 0xA,
    JNZ = 0xB,
    IN = 0xC,
    OUT = 0xD,
    HLT = 0xE,
    INT = 0xF,
};

pub const Register = enum(u2) {
    AX = 0b00,
    BX = 0b01,
    CX = 0b10,
    DX = 0b11,
};

// 16-bit instruction: [opcode:4][dst:2][src:2][mode:2][unused:6]
pub fn encode16(op: Opcode, dst: Register, src: Register, mode: u2) u16 {
    return (@as(u16, @intFromEnum(op)) << 12) |
        (@as(u16, @intFromEnum(dst)) << 10) |
        (@as(u16, @intFromEnum(src)) << 8) |
        (@as(u16, mode) << 6);
}

// 32-bit instruction: [opcode:4][dst:2][mode:2][immediate:16][unused:8]
pub fn encode32(op: Opcode, dst: Register, imm: u16) u32 {
    return (@as(u32, @intFromEnum(op)) << 28) |
        (@as(u32, @intFromEnum(dst)) << 26) |
        (@as(u32, 0b01) << 24) |
        (@as(u32, imm) << 8);
}

const MEM = 256;

// Write 16-bit value in little-endian
fn w16(buf: *[MEM * 4]u8, p: *usize, v: u16) void {
    buf[p.*] = @intCast(v & 0xFF);
    buf[p.* + 1] = @intCast((v >> 8) & 0xFF);
    p.* += 2;
}

// Write 32-bit value in little-endian
fn w32(buf: *[MEM * 4]u8, p: *usize, v: u32) void {
    buf[p.*] = @intCast(v & 0xFF);
    buf[p.* + 1] = @intCast((v >> 8) & 0xFF);
    buf[p.* + 2] = @intCast((v >> 16) & 0xFF);
    buf[p.* + 3] = @intCast((v >> 24) & 0xFF);
    p.* += 4;
}

pub const firmware: [MEM * 4]u8 = generateFirmware();

// Comptime firmware generation
fn generateFirmware() [MEM * 4]u8 {
    var b: [MEM * 4]u8 = std.mem.zeroes([MEM * 4]u8);
    var i: usize = 0;

    w16(&b, &i, encode16(.NOP, .AX, .AX, 0));
    w32(&b, &i, encode32(.MOV, .AX, 0x00FF));
    w32(&b, &i, encode32(.MOV, .BX, 0x000F));
    w16(&b, &i, encode16(.ADD, .AX, .BX, 0));
    w16(&b, &i, encode16(.SUB, .CX, .AX, 0));
    w16(&b, &i, encode16(.AND, .DX, .AX, 0));
    w16(&b, &i, encode16(.OR, .DX, .BX, 0));
    w16(&b, &i, encode16(.XOR, .AX, .AX, 0));
    w16(&b, &i, encode16(.SHL, .BX, .AX, 1));
    w16(&b, &i, encode16(.SHR, .CX, .AX, 1));
    w32(&b, &i, encode32(.JMP, .AX, 0x0000));
    w16(&b, &i, encode16(.HLT, .AX, .AX, 0));

    return b;
}

// Write firmware.bin to build/
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const dir = std.Io.Dir.cwd();
    try dir.createDirPath(io, "build");
    const file = try dir.createFile(io, "build/firmware.bin", .{});
    defer file.close(io);

    try file.writeStreamingAll(io, &firmware);
    std.debug.print("Firmware: build/firmware.bin ({d} bytes)\n", .{firmware.len});
}
