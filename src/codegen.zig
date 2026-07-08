const std = @import("std");

// ISA Encoding: Opcode [15:12] | Dst/Mode [11:10] | Src/Size [9:8] | Mode [7:6] | Unused [5:0]

// Main opcodes (4-bit)
pub const Opcode = enum(u4) {
    NOP = 0x0,
    MOV = 0x1,
    JMP = 0x2,
    CALL = 0x3,
    RET = 0x4,
    INT = 0x5,
    IRET = 0x6,
    HLT = 0x7,
    IN = 0x8,
    OUT = 0x9,
    ALU = 0xA,
    CondJump = 0xB,
    PushPop = 0xC,
};

// ALU sub-opcodes (Mode[11:10] + Size[9:8])
pub const AluOp = enum(u4) {
    ADD = 0b0000,
    SUB = 0b0001,
    CMP = 0b0010,
    TEST = 0b0011,
    ADC = 0b0100,
    SBB = 0b0101,
    AND = 0b0110,
    OR = 0b0111,
    XOR = 0b1000,
    SHL = 0b1001,
    SHR = 0b1010,
    INC = 0b1011,
    DEC = 0b1100,
    NOT = 0b1101,
    NEG = 0b1110,
    XCHG = 0b1111,
};

// Conditional jump sub-opcodes (Mode[11:10] + Size[9:8])
pub const CondJump = enum(u4) {
    JZ = 0b0000,
    JNZ = 0b0001,
    JC = 0b0010,
    JNC = 0b0011,
    JS = 0b0100,
    JNS = 0b0101,
};

// PUSH/POP mode (Mode[9:8])
pub const StackOp = enum(u2) {
    PUSH = 0b00,
    POP = 0b01,
};

// Registers (2-bit)
pub const Register = enum(u2) {
    AX = 0b00,
    BX = 0b01,
    CX = 0b10,
    DX = 0b11,
};

// Addressing modes (Mode[7:6])
pub const AddrMode = enum(u2) {
    RegReg = 0b00, // register to register
    Imm = 0b01, // immediate (32-bit format)
    Indirect = 0b10, // [reg]
    IndirectOff = 0b11, // [reg + offset]
};

// 16-bit instruction: [opcode:4][dst:2][src:2][mode:2][unused:6]
pub fn encode16(op: Opcode, dst: Register, src: Register, mode: AddrMode) u16 {
    return (@as(u16, @intFromEnum(op)) << 12) |
        (@as(u16, @intFromEnum(dst)) << 10) |
        (@as(u16, @intFromEnum(src)) << 8) |
        (@as(u16, @intFromEnum(mode)) << 6);
}

// 32-bit instruction: [opcode:4][dst:2][mode:2][immediate:16][unused:8]
pub fn encode32(op: Opcode, dst: Register, imm: u16) u32 {
    return (@as(u32, @intFromEnum(op)) << 28) |
        (@as(u32, @intFromEnum(dst)) << 26) |
        (@as(u32, @intFromEnum(AddrMode.Imm)) << 24) |
        (@as(u32, imm) << 8);
}

// ALU group: [opcode:4][Mode:2][Size:2][dst:2][src:2][unused:4]
// Mode+Size = AluOp (4 bits sub-opcode)
pub fn encodeAlu(alu: AluOp, dst: Register, src: Register) u16 {
    return (@as(u16, @intFromEnum(Opcode.ALU)) << 12) |
        (@as(u16, @intFromEnum(alu)) << 8) |
        (@as(u16, @intFromEnum(dst)) << 6) |
        (@as(u16, @intFromEnum(src)) << 4);
}

// ALU group with immediate: [opcode:4][Mode:2][Size:2][dst:2][immediate:16][unused:8]
pub fn encodeAluImm(alu: AluOp, dst: Register, imm: u16) u32 {
    return (@as(u32, @intFromEnum(Opcode.ALU)) << 28) |
        (@as(u32, @intFromEnum(alu)) << 24) |
        (@as(u32, @intFromEnum(dst)) << 22) |
        (@as(u32, imm) << 6);
}

// Conditional jump: [opcode:4][Mode:2][Size:2][immediate:16][unused:8]
pub fn encodeCondJump(cond: CondJump, target: u16) u32 {
    return (@as(u32, @intFromEnum(Opcode.CondJump)) << 28) |
        (@as(u32, @intFromEnum(cond)) << 24) |
        (@as(u32, target) << 8);
}

// PUSH/POP: [opcode:4][dst:2][Mode:2][unused:10]
pub fn encodePushPop(op: StackOp, reg: Register) u16 {
    return (@as(u16, @intFromEnum(Opcode.PushPop)) << 12) |
        (@as(u16, @intFromEnum(reg)) << 10) |
        (@as(u16, @intFromEnum(op)) << 8);
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

    // NOP
    w16(&b, &i, encode16(.NOP, .AX, .AX, .RegReg));

    // MOV AX, 0x00FF
    w32(&b, &i, encode32(.MOV, .AX, 0x00FF));

    // MOV BX, 0x000F
    w32(&b, &i, encode32(.MOV, .BX, 0x000F));

    // ADD AX, BX
    w16(&b, &i, encodeAlu(.ADD, .AX, .BX));

    // SUB CX, AX
    w16(&b, &i, encodeAlu(.SUB, .CX, .AX));

    // CMP DX, AX
    w16(&b, &i, encodeAlu(.CMP, .DX, .AX));

    // AND DX, AX
    w16(&b, &i, encodeAlu(.AND, .DX, .AX));

    // OR DX, BX
    w16(&b, &i, encodeAlu(.OR, .DX, .BX));

    // XOR AX, AX
    w16(&b, &i, encodeAlu(.XOR, .AX, .AX));

    // SHL BX, AX
    w16(&b, &i, encodeAlu(.SHL, .BX, .AX));

    // SHR CX, AX
    w16(&b, &i, encodeAlu(.SHR, .CX, .AX));

    // INC AX
    w16(&b, &i, encodeAlu(.INC, .AX, .AX));

    // DEC BX
    w16(&b, &i, encodeAlu(.DEC, .BX, .BX));

    // NOT CX
    w16(&b, &i, encodeAlu(.NOT, .CX, .CX));

    // NEG DX
    w16(&b, &i, encodeAlu(.NEG, .DX, .DX));

    // XCHG AX, BX
    w16(&b, &i, encodeAlu(.XCHG, .AX, .BX));

    // ADC AX, BX
    w16(&b, &i, encodeAlu(.ADC, .AX, .BX));

    // SBB AX, BX
    w16(&b, &i, encodeAlu(.SBB, .AX, .BX));

    // TEST AX, BX
    w16(&b, &i, encodeAlu(.TEST, .AX, .BX));

    // PUSH AX
    w16(&b, &i, encodePushPop(.PUSH, .AX));

    // POP BX
    w16(&b, &i, encodePushPop(.POP, .BX));

    // JMP 0x0000
    w32(&b, &i, encodeCondJump(.JZ, 0x0000));

    // JNZ 0x0010
    w32(&b, &i, encodeCondJump(.JNZ, 0x0010));

    // MOV AX, 0x1234
    w32(&b, &i, encode32(.MOV, .AX, 0x1234));

    // IN AX, 0x00
    w32(&b, &i, encode32(.IN, .AX, 0x00));

    // OUT 0x00, AX
    w32(&b, &i, encode32(.OUT, .AX, 0x00));

    // HLT
    w16(&b, &i, encode16(.HLT, .AX, .AX, .RegReg));

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

// Tests
test "encode16 NOP" {
    const inst = encode16(.NOP, .AX, .AX, .RegReg);
    // opcode=0000 dst=00 src=00 mode=00 unused=000000
    try std.testing.expectEqual(@as(u16, 0x0000), inst);
}

test "encode32 MOV AX, 0x00FF" {
    const inst = encode32(.MOV, .AX, 0x00FF);
    // opcode=0001 dst=00 mode=01 imm=0x00FF unused=0
    try std.testing.expectEqual(@as(u32, 0x1100FF00), inst);
}

test "encodeAlu ADD AX, BX" {
    const inst = encodeAlu(.ADD, .AX, .BX);
    // opcode=1010 sub_op=0000 dst=00 src=01 unused=0000
    try std.testing.expectEqual(@as(u16, 0xA010), inst);
}

test "encodeAlu SUB BX, AX" {
    const inst = encodeAlu(.SUB, .BX, .AX);
    // opcode=1010 sub_op=0001 dst=01 src=00 unused=0000
    try std.testing.expectEqual(@as(u16, 0xA140), inst);
}

test "encodePushPop PUSH AX" {
    const inst = encodePushPop(.PUSH, .AX);
    // opcode=1100 dst=00 mode=00
    try std.testing.expectEqual(@as(u16, 0xC000), inst);
}

test "encodePushPop POP BX" {
    const inst = encodePushPop(.POP, .BX);
    // opcode=1100 dst=01 mode=01
    try std.testing.expectEqual(@as(u16, 0xC500), inst);
}
