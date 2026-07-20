const std = @import("std");

// =============================================================================
// NovumOS-16bit ISA (Instruction Set Architecture) — Code Generation
// =============================================================================
//
// This file defines the instruction encoding for a custom 16-bit CPU designed
// by a friend using TTL NAND gates. The ISA supports both 16-bit and 32-bit
// instructions, with automatic size detection in hardware.
//
// Instruction formats:
//
//   16-bit: [opcode:4][dst:2][src:2][mode:2][unused:6]
//     - Opcode in bits 15:12
//     - Used for: register-register operations, PUSH/POP, RET, NOP, HLT
//
//   32-bit: [opcode:4][dst:2][mode=01:2][immediate:16][unused:8]
//     - Opcode in bits 31:28 (NOT bits 15:12)
//     - Mode is hardcoded to 01 (Imm) — this is how CPU detects 32-bit format
//     - Used for: immediate loads, jumps, calls, IN/OUT, conditional jumps
//
// The CPU detects instruction size by checking bits 25:24 of the raw 32-bit word.
// If mode == 01, it's a 32-bit instruction; otherwise 16-bit.
// This heuristic works because encode32() ALWAYS sets mode=01 at bits 25:24,
// while encode16() never uses mode=01 in that position.

// =============================================================================
// ISA Enums
// =============================================================================

/// Main opcodes — 4-bit, encoded in bits 15:12 (16-bit) or bits 31:28 (32-bit).
/// Each opcode identifies a major instruction category.
pub const Opcode = enum(u4) {
    NOP = 0x0,       // No operation — advance IP by 2
    MOV = 0x1,       // Move data between registers/memory/immediate
    JMP = 0x2,       // Unconditional jump
    CALL = 0x3,      // Call subroutine (push return address, jump)
    RET = 0x4,       // Return from subroutine (pop return address)
    INT = 0x5,       // Software interrupt (push FLAGS+IP, jump to handler)
    IRET = 0x6,      // Return from interrupt (pop IP+FLAGS)
    HLT = 0x7,       // Halt CPU — stops execution until reset
    IN = 0x8,        // Read from I/O port into register
    OUT = 0x9,       // Write register to I/O port
    ALU = 0xA,       // Arithmetic/logic unit operations (ADD, SUB, AND, etc.)
    CondJump = 0xB,  // Conditional jump (JZ, JNZ, JC, JNC, JS, JNS)
    PushPop = 0xC,   // Stack operations (PUSH, POP)
};

/// ALU sub-opcodes — encoded in bits 11:8 of 16-bit ALU instructions.
/// All ALU operations work on two registers (dst and src).
/// Result is stored in dst, except CMP and TEST which only set flags.
/// Physical TTL ALU encoding — matches the 16-operation TTL ALU chip design.
pub const AluOp = enum(u4) {
    ADD  = 0b0000,   // dst = dst + src, set Carry on overflow
    SUB  = 0b0001,   // dst = dst - src, set Carry on borrow
    CMP  = 0b0010,   // Compare (subtract without storing result)
    TEST = 0b0011,   // Bitwise AND (result discarded, flags only)
    ADC  = 0b0100,   // dst = dst + src + carry, set Carry on overflow
    SBB  = 0b0101,   // dst = dst - src - carry, set Carry on borrow
    AND  = 0b0110,   // dst = dst AND src
    OR   = 0b0111,   // dst = dst OR src
    XOR  = 0b1000,   // dst = dst XOR src
    SHL  = 0b1001,   // dst = dst << src (shift left)
    SHR  = 0b1010,   // dst = dst >> src (shift right)
    INC  = 0b1011,   // dst = dst + 1 (increment)
    DEC  = 0b1100,   // dst = dst - 1 (decrement)
    NOT  = 0b1101,   // dst = NOT dst (bitwise complement)
    NEG  = 0b1110,   // dst = 0 - dst (two's complement negate)
    XCHG = 0b1111,   // Exchange dst and src register values
};

/// Conditional jump sub-opcodes — encoded in bits 11:8.
/// Each condition tests a specific flag in the FLAGS register.
pub const CondJump = enum(u4) {
    JZ = 0b0000,     // Jump if Zero flag set (result was zero)
    JNZ = 0b0001,    // Jump if Zero flag clear (result was non-zero)
    JC = 0b0010,     // Jump if Carry flag set (overflow/borrow)
    JNC = 0b0011,    // Jump if Carry flag clear
    JS = 0b0100,     // Jump if Sign flag set (result was negative)
    JNS = 0b0101,    // Jump if Sign flag clear (result was non-negative)
};

/// Stack operation mode — PUSH or POP.
pub const StackOp = enum(u2) {
    PUSH = 0b00,     // Push register value onto stack
    POP = 0b01,      // Pop stack value into register
};

/// General-purpose registers — 2-bit encoding.
pub const Register = enum(u2) {
    AX = 0b00,       // Accumulator — primary working register
    BX = 0b01,       // Base — base register for addressing
    CX = 0b10,       // Counter — loop counter and operation count
    DX = 0b11,       // Data — I/O and arithmetic data
};

/// Addressing modes — determines how operand is accessed.
pub const AddrMode = enum(u2) {
    RegReg = 0b00,   // Register-to-register (16-bit format)
    Imm = 0b01,      // Immediate value (32-bit format, mode=01 is key marker)
    Indirect = 0b10, // [reg] — indirect through register
    IndirectOff = 0b11, // [reg + offset] — indirect with offset
};

// =============================================================================
// Instruction Encoding Functions
// =============================================================================

/// Encode a 16-bit instruction.
///
/// Format: [opcode:4][dst:2][src:2][mode:2][unused:6]
///   bits 15:12 = opcode (instruction type)
///   bits 11:10 = dst (destination register)
///   bits  9:8  = src (source register)
///   bits  7:6  = mode (addressing mode)
///   bits  5:0  = unused (zero)
///
/// Used for: NOP, MOV reg,reg, ALU reg,reg, PUSH/POP, RET, HLT.
/// The mode field can be RegReg (00), Indirect (10), or IndirectOff (11).
pub fn encode16(op: Opcode, dst: Register, src: Register, mode: AddrMode) u16 {
    return (@as(u16, @intFromEnum(op)) << 12) |
        (@as(u16, @intFromEnum(dst)) << 10) |
        (@as(u16, @intFromEnum(src)) << 8) |
        (@as(u16, @intFromEnum(mode)) << 6);
}

/// Encode a 32-bit instruction with immediate value.
///
/// Format: [opcode:4][dst:2][mode=01:2][immediate:16][unused:8]
///   bits 31:28 = opcode (instruction type)
///   bits 27:26 = dst (destination register)
///   bits 25:24 = mode (MUST be 01 = Imm — this marks 32-bit format)
///   bits 23:8  = immediate (16-bit constant value)
///   bits  7:0  = unused (zero)
///
/// CRITICAL: mode is hardcoded to 01 (AddrMode.Imm). The CPU uses this
/// to distinguish 32-bit from 16-bit instructions during decode.
/// Used for: MOV reg,imm, JMP, CALL, IN, OUT, CondJump.
pub fn encode32(op: Opcode, dst: Register, imm: u16) u32 {
    return (@as(u32, @intFromEnum(op)) << 28) |
        (@as(u32, @intFromEnum(dst)) << 26) |
        (@as(u32, @intFromEnum(AddrMode.Imm)) << 24) |
        (@as(u32, imm) << 8);
}

/// Encode a 16-bit ALU (arithmetic/logic) instruction.
///
/// Format: [opcode=ALU:4][alu_op:4][dst:2][src:2][unused:4]
///   bits 15:12 = opcode (always 0xA = ALU)
///   bits 11:8  = alu_op (ALU operation: ADD, SUB, AND, etc.)
///   bits  7:6  = dst (destination register — also source 1)
///   bits  5:4  = src (source register — also source 2)
///   bits  3:0  = unused (zero)
///
/// All ALU operations read dst and src, compute result, store in dst.
/// Exception: CMP and TEST only set flags (result discarded).
pub fn encodeAlu(alu: AluOp, dst: Register, src: Register) u16 {
    return (@as(u16, @intFromEnum(Opcode.ALU)) << 12) |
        (@as(u16, @intFromEnum(alu)) << 8) |
        (@as(u16, @intFromEnum(dst)) << 6) |
        (@as(u16, @intFromEnum(src)) << 4);
}

/// Encode a 32-bit ALU instruction with immediate operand.
///
/// Format: [opcode=ALU:4][alu_op:4][dst:2][immediate:16][unused:6]
///   bits 31:28 = opcode (always 0xA = ALU)
///   bits 27:24 = alu_op (ALU operation)
///   bits 23:22 = dst (destination register)
///   bits 21:6  = immediate (16-bit constant)
///   bits  5:0  = unused (zero)
///
/// Used for ALU operations with immediate values (not yet implemented in CPU).
pub fn encodeAluImm(alu: AluOp, dst: Register, imm: u16) u32 {
    return (@as(u32, @intFromEnum(Opcode.ALU)) << 28) |
        (@as(u32, @intFromEnum(alu)) << 24) |
        (@as(u32, @intFromEnum(dst)) << 22) |
        (@as(u32, imm) << 6);
}

/// Encode a 32-bit conditional jump instruction.
///
/// Format: [opcode=CondJump:4][mode=01:2][cond:4][target:16][unused:4]
///   bits 31:28 = opcode (always 0xB = CondJump)
///   bits 27:24 = mode (hardcoded to 01 for 32-bit detection)
///   bits 23:20 = cond (condition code: JZ, JNZ, JC, etc.)
///   bits 19:4  = target (16-bit jump target address)
///   bits  3:0  = unused (zero)
///
/// Mode=01 at bits 25:24 is critical for CPU instruction size detection.
pub fn encodeCondJump(cond: CondJump, target: u16) u32 {
    return (@as(u32, @intFromEnum(Opcode.CondJump)) << 28) |
        (@as(u32, 0b01) << 24) | // mode=01 (Imm) for 32-bit detection
        (@as(u32, @intFromEnum(cond)) << 20) |
        (@as(u32, target) << 4);
}

/// Encode a 16-bit PUSH/POP instruction.
///
/// Format: [opcode=PushPop:4][reg:2][stack_op:2][unused:8]
///   bits 15:12 = opcode (always 0xC = PushPop)
///   bits 11:10 = reg (register to push/pop)
///   bits  9:8  = stack_op (00=PUSH, 01=POP)
///   bits  7:0  = unused (zero)
pub fn encodePushPop(op: StackOp, reg: Register) u16 {
    return (@as(u16, @intFromEnum(Opcode.PushPop)) << 12) |
        (@as(u16, @intFromEnum(reg)) << 10) |
        (@as(u16, @intFromEnum(op)) << 8);
}

// =============================================================================
// Firmware Binary Generator
// =============================================================================

const MEM = 256; // Firmware size in 16-bit words (512 bytes)

/// Write a 16-bit value to the firmware buffer in little-endian byte order.
fn w16(buf: *[MEM * 4]u8, p: *usize, v: u16) void {
    buf[p.*] = @intCast(v & 0xFF);
    buf[p.* + 1] = @intCast((v >> 8) & 0xFF);
    p.* += 2;
}

/// Write a 32-bit value to the firmware buffer in little-endian byte order.
/// The 32-bit value is written as two consecutive 16-bit words (lo first).
fn w32(buf: *[MEM * 4]u8, p: *usize, v: u32) void {
    buf[p.*] = @intCast(v & 0xFF);
    buf[p.* + 1] = @intCast((v >> 8) & 0xFF);
    buf[p.* + 2] = @intCast((v >> 16) & 0xFF);
    buf[p.* + 3] = @intCast((v >> 24) & 0xFF);
    p.* += 4;
}

/// Comptime-generated firmware binary (1024 bytes = 512 words).
/// This is the default firmware used by the emulator when no file is loaded.
pub const firmware: [MEM * 4]u8 = generateFirmware();

/// Generate the default firmware binary at compile time.
///
/// This test firmware exercises most of the ISA and ends with HLT:
///   0x00: NOP — verify no-op works
///   0x02: MOV AX, 0x00FF — load immediate (255)
///   0x06: MOV BX, 0x000F — load immediate (15)
///   0x0A: ADD AX, BX — addition (0xFF + 0x0F = 0x108)
///   0x0C: SUB CX, AX — subtraction
///   0x0E: CMP DX, AX — compare (sets flags only)
///   0x10: AND DX, AX — bitwise AND
///   0x12: OR DX, BX — bitwise OR
///   0x14: XOR AX, AX — clear register (AX = 0)
///   0x16: SHL BX, AX — shift left by 0
///   0x18: SHR BX, AX — shift right by 0
///   0x1A: INC DX — increment
///   0x1C: DEC CX — decrement
///   0x1E: SHR CX, AX — shift right by 0
///   0x20: INC AX — increment (AX = 1)
///   0x22: DEC BX — decrement
///   0x24: NOT CX — bitwise complement
///   0x26: NEG DX — two's complement negate
///   0x28: PUSH AX — push to stack
///   0x32: POP BX — pop from stack
///   0x34: MOV AX, 0x1234 — load test value
///   0x38: IN AX, 0x22 — read I/O port 0x22
///   0x3C: OUT 0x22, AX — write I/O port 0x22
///   0x40: MOV AX, 0x00FF — final value check
///   0x44: HLT — halt CPU
fn generateFirmware() [MEM * 4]u8 {
    var b: [MEM * 4]u8 = std.mem.zeroes([MEM * 4]u8);
    var i: usize = 0;

    // [0x00] NOP — no operation, just advance IP
    w16(&b, &i, encode16(.NOP, .AX, .AX, .RegReg));

    // [0x02] MOV AX, 0x00FF — load 255 into AX
    w32(&b, &i, encode32(.MOV, .AX, 0x00FF));

    // [0x06] MOV BX, 0x000F — load 15 into BX
    w32(&b, &i, encode32(.MOV, .BX, 0x000F));

    // [0x0A] ADD AX, BX — AX = 0xFF + 0x0F = 0x0108 (Carry set)
    w16(&b, &i, encodeAlu(.ADD, .AX, .BX));

    // [0x0C] SUB CX, AX — CX = 0 - 0x0108 = 0xFF00 (Carry set, borrow)
    w16(&b, &i, encodeAlu(.SUB, .CX, .AX));

    // [0x0E] CMP DX, AX — compare DX (0) with AX (0x0108), sets flags only
    w16(&b, &i, encodeAlu(.CMP, .DX, .AX));

    // [0x10] AND DX, AX — DX = 0 AND 0x0108 = 0
    w16(&b, &i, encodeAlu(.AND, .DX, .AX));

    // [0x12] OR DX, BX — DX = 0 OR 0x0F = 0x0F
    w16(&b, &i, encodeAlu(.OR, .DX, .BX));

    // [0x14] XOR AX, AX — AX = 0 XOR 0 = 0 (clear AX)
    w16(&b, &i, encodeAlu(.XOR, .AX, .AX));

    // [0x16] SHL BX, AX — BX << 0 = BX unchanged (shift by 0)
    w16(&b, &i, encodeAlu(.SHL, .BX, .AX));

    // [0x18] SHR BX, AX — BX >> 0 = BX unchanged (shift by 0)
    w16(&b, &i, encodeAlu(.SHR, .BX, .AX));

    // [0x1A] INC DX — DX = 0x0F + 1 = 0x10
    w16(&b, &i, encodeAlu(.INC, .DX, .AX));

    // [0x1C] DEC CX — CX = 0xFF00 - 1 = 0xFEFF
    w16(&b, &i, encodeAlu(.DEC, .CX, .AX));

    // [0x1E] SHR CX, AX — CX >> 0 = CX unchanged (shift by 0)
    w16(&b, &i, encodeAlu(.SHR, .CX, .AX));

    // [0x20] INC AX — AX = 0 + 1 = 1
    w16(&b, &i, encodeAlu(.INC, .AX, .AX));

    // [0x22] DEC BX — BX = 0x0F - 1 = 0x0E
    w16(&b, &i, encodeAlu(.DEC, .BX, .BX));

    // [0x24] NOT CX — CX = NOT 0xFEFF = 0x0100
    w16(&b, &i, encodeAlu(.NOT, .CX, .CX));

    // [0x26] NEG DX — DX = 0 - 0x10 = 0xFFF0
    w16(&b, &i, encodeAlu(.NEG, .DX, .DX));

    // [0x28] TEST AX, BX — AX AND BX (flags only, result discarded)
    w16(&b, &i, encodeAlu(.TEST, .AX, .BX));

    // [0x2A] PUSH AX — push AX onto stack
    w16(&b, &i, encodePushPop(.PUSH, .AX));

    // [0x2C] POP BX — pop stack value into BX
    w16(&b, &i, encodePushPop(.POP, .BX));

    // [0x34] MOV AX, 0x1234 — load test value for IN/OUT
    w32(&b, &i, encode32(.MOV, .AX, 0x1234));

    // [0x38] IN AX, 0x22 — read from generic I/O port 0x22 into AX
    w32(&b, &i, encode32(.IN, .AX, 0x0022));

    // [0x3C] OUT 0x22, AX — write AX to generic I/O port 0x22
    w32(&b, &i, encode32(.OUT, .AX, 0x0022));

    // [0x40] MOV AX, 0x00FF — load 255 into AX (test MOV imm works)
    w32(&b, &i, encode32(.MOV, .AX, 0x00FF));

    // [0x44] HLT — halt CPU (end of test firmware)
    w16(&b, &i, encode16(.HLT, .AX, .AX, .RegReg));

    return b;
}

/// Write the firmware binary to build/firmware.bin.
/// This is the entry point for the `zig build firmware` build step.
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const dir = std.Io.Dir.cwd();
    try dir.createDirPath(io, "build");
    const file = try dir.createFile(io, "build/firmware.bin", .{});
    defer file.close(io);

    try file.writeStreamingAll(io, &firmware);
    std.debug.print("Firmware: build/firmware.bin ({d} bytes)\n", .{firmware.len});
}

// =============================================================================
// Unit Tests for ISA Encoding
// =============================================================================

// Test 16-bit NOP encoding: all zeros (opcode=0, dst=AX, src=AX, mode=RegReg)
test "encode16 NOP" {
    const inst = encode16(.NOP, .AX, .AX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x0000), inst);
}

// Test 32-bit MOV AX, 0x00FF encoding: loads immediate 255 into AX.
test "encode32 MOV AX, 0x00FF" {
    const inst = encode32(.MOV, .AX, 0x00FF);
    try std.testing.expectEqual(@as(u32, 0x1100FF00), inst);
}

// Test ALU ADD AX, BX encoding: adds BX to AX.
test "encodeAlu ADD AX, BX" {
    const inst = encodeAlu(.ADD, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA010), inst);
}

// Test ALU SUB BX, AX encoding: subtracts AX from BX.
test "encodeAlu SUB BX, AX" {
    const inst = encodeAlu(.SUB, .BX, .AX);
    try std.testing.expectEqual(@as(u16, 0xA140), inst);
}

// Test PUSH AX encoding: push AX onto stack.
test "encodePushPop PUSH AX" {
    const inst = encodePushPop(.PUSH, .AX);
    try std.testing.expectEqual(@as(u16, 0xC000), inst);
}

// Test POP BX encoding: pop stack value into BX.
test "encodePushPop POP BX" {
    const inst = encodePushPop(.POP, .BX);
    try std.testing.expectEqual(@as(u16, 0xC500), inst);
}
