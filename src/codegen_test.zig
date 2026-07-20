const std = @import("std");
const ISA = @import("codegen");
const encode16 = ISA.encode16;
const encode32 = ISA.encode32;
const encodeAlu = ISA.encodeAlu;
const encodeAluImm = ISA.encodeAluImm;
const encodeCondJump = ISA.encodeCondJump;
const encodePushPop = ISA.encodePushPop;

// =============================================================================
// encode16 — 16-bit Instruction Encoding
// Format: [opcode:4][dst:2][src:2][mode:2][unused:6]
// =============================================================================

test "encode16 NOP" {
    const inst = encode16(.NOP, .AX, .AX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x0000), inst);
}

test "encode16 HLT" {
    const inst = encode16(.HLT, .AX, .AX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x7000), inst);
}

test "encode16 RET" {
    const inst = encode16(.RET, .AX, .AX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x4000), inst);
}

test "encode16 IRET" {
    const inst = encode16(.IRET, .AX, .AX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x6000), inst);
}

test "encode16 MOV AX, BX" {
    // opcode=1, dst=AX(0), src=BX(1), mode=RegReg(0)
    // 0001 00 01 00 000000 = 0x1100
    const inst = encode16(.MOV, .AX, .BX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x1100), inst);
}

test "encode16 MOV DX, CX" {
    // opcode=1, dst=DX(3), src=CX(2), mode=RegReg(0)
    // 0001 11 10 00 000000 = 0x1E00
    const inst = encode16(.MOV, .DX, .CX, .RegReg);
    try std.testing.expectEqual(@as(u16, 0x1E00), inst);
}

test "encode16 bit positions" {
    const inst = encode16(.MOV, .BX, .DX, .RegReg);
    const opcode: u4 = @intCast((inst >> 12) & 0xF);
    const dst: u2 = @intCast((inst >> 10) & 0x3);
    const src: u2 = @intCast((inst >> 8) & 0x3);
    const mode: u2 = @intCast((inst >> 6) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.MOV), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.BX), dst);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.DX), src);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.RegReg), mode);
}

// =============================================================================
// encode32 — 32-bit Instruction Encoding
// Format: [opcode:4][dst:2][mode=01:2][immediate:16][unused:8]
// =============================================================================

test "encode32 MOV AX, 0x00FF" {
    // opcode=1, dst=AX(0), mode=01, imm=0x00FF
    // 0001 00 01 00000000 11111111 00000000 = 0x1100FF00
    const inst = encode32(.MOV, .AX, 0x00FF);
    try std.testing.expectEqual(@as(u32, 0x1100FF00), inst);
}

test "encode32 MOV BX, 0x1234" {
    const inst = encode32(.MOV, .BX, 0x1234);
    try std.testing.expectEqual(@as(u32, 0x15123400), inst);
}

test "encode32 MOV CX, 0x0000" {
    const inst = encode32(.MOV, .CX, 0x0000);
    try std.testing.expectEqual(@as(u32, 0x19000000), inst);
}

test "encode32 MOV DX, 0xFFFF" {
    const inst = encode32(.MOV, .DX, 0xFFFF);
    try std.testing.expectEqual(@as(u32, 0x1DFFFF00), inst);
}

test "encode32 JMP 0x0010" {
    // opcode=JMP(2), dst=AX(0), mode=01, imm=0x0010
    // 0010 00 01 00000000 00010000 00000000 = 0x21001000
    const inst = encode32(.JMP, .AX, 0x0010);
    try std.testing.expectEqual(@as(u32, 0x21001000), inst);
}

test "encode32 CALL 0x0020" {
    // opcode=CALL(3), dst=AX(0), mode=01, imm=0x0020
    // 0011 00 01 00000000 00100000 00000000 = 0x31002000
    const inst = encode32(.CALL, .AX, 0x0020);
    try std.testing.expectEqual(@as(u32, 0x31002000), inst);
}

test "encode32 INT 0x0021" {
    // opcode=INT(5), dst=AX(0), mode=01, imm=0x0021
    // 0101 00 01 00000000 00100001 00000000 = 0x51002100
    const inst = encode32(.INT, .AX, 0x0021);
    try std.testing.expectEqual(@as(u32, 0x51002100), inst);
}

test "encode32 IN AX, 0x0022" {
    // opcode=IN(8), dst=AX(0), mode=01, imm=0x0022
    // 1000 00 01 00000000 00100010 00000000 = 0x81002200
    const inst = encode32(.IN, .AX, 0x0022);
    try std.testing.expectEqual(@as(u32, 0x81002200), inst);
}

test "encode32 OUT 0x0000, AX" {
    // opcode=OUT(9), dst=AX(0), mode=01, imm=0x0000
    const inst = encode32(.OUT, .AX, 0x0000);
    try std.testing.expectEqual(@as(u32, 0x91000000), inst);
}

test "encode32 bit positions" {
    const inst = encode32(.MOV, .AX, 0x0042);
    const opcode: u4 = @intCast((inst >> 28) & 0xF);
    const dst: u2 = @intCast((inst >> 26) & 0x3);
    const mode: u2 = @intCast((inst >> 24) & 0x3);
    const imm: u16 = @intCast((inst >> 8) & 0xFFFF);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.MOV), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.AX), dst);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.Imm), mode);
    try std.testing.expectEqual(@as(u16, 0x0042), imm);
}

// =============================================================================
// encodeAlu — 16-bit ALU Instruction Encoding
// Format: [opcode=ALU:4][alu_op:4][dst:2][src:2][unused:4]
// =============================================================================

test "encodeAlu ADD AX, BX" {
    // ALU=0xA, ADD=0, dst=AX(0), src=BX(1)
    // 1010 0000 00 01 0000 = 0xA010
    const inst = encodeAlu(.ADD, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA010), inst);
}

test "encodeAlu ADC AX, BX" {
    // ALU=0xA, ADC=4, dst=AX(0), src=BX(1)
    // 1010 0100 00 01 0000 = 0xA410
    const inst = encodeAlu(.ADC, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA410), inst);
}

test "encodeAlu SUB BX, AX" {
    // ALU=0xA, SUB=1, dst=BX(1), src=AX(0)
    // 1010 0001 01 00 0000 = 0xA140
    const inst = encodeAlu(.SUB, .BX, .AX);
    try std.testing.expectEqual(@as(u16, 0xA140), inst);
}

test "encodeAlu SBB BX, AX" {
    // ALU=0xA, SBB=5, dst=BX(1), src=AX(0)
    // 1010 0101 01 00 0000 = 0xA540
    const inst = encodeAlu(.SBB, .BX, .AX);
    try std.testing.expectEqual(@as(u16, 0xA540), inst);
}

test "encodeAlu CMP AX, BX" {
    // ALU=0xA, CMP=2, dst=AX(0), src=BX(1)
    // 1010 0010 00 01 0000 = 0xA210
    const inst = encodeAlu(.CMP, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA210), inst);
}

test "encodeAlu TEST AX, BX" {
    // ALU=0xA, TEST=3, dst=AX(0), src=BX(1)
    // 1010 0011 00 01 0000 = 0xA310
    const inst = encodeAlu(.TEST, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA310), inst);
}

test "encodeAlu AND AX, BX" {
    // ALU=0xA, AND=6, dst=AX(0), src=BX(1)
    // 1010 0110 00 01 0000 = 0xA610
    const inst = encodeAlu(.AND, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA610), inst);
}

test "encodeAlu OR AX, BX" {
    // ALU=0xA, OR=7, dst=AX(0), src=BX(1)
    // 1010 0111 00 01 0000 = 0xA710
    const inst = encodeAlu(.OR, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA710), inst);
}

test "encodeAlu XOR AX, BX" {
    // ALU=0xA, XOR=8, dst=AX(0), src=BX(1)
    // 1010 1000 00 01 0000 = 0xA810
    const inst = encodeAlu(.XOR, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA810), inst);
}

test "encodeAlu SHL AX, BX" {
    // ALU=0xA, SHL=9, dst=AX(0), src=BX(1)
    // 1010 1001 00 01 0000 = 0xA910
    const inst = encodeAlu(.SHL, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xA910), inst);
}

test "encodeAlu SHR AX, BX" {
    // ALU=0xA, SHR=10, dst=AX(0), src=BX(1)
    // 1010 1010 00 01 0000 = 0xAA10
    const inst = encodeAlu(.SHR, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xAA10), inst);
}

test "encodeAlu INC AX" {
    // ALU=0xA, INC=11, dst=AX(0), src=AX(0)
    // 1010 1011 00 00 0000 = 0xAB00
    const inst = encodeAlu(.INC, .AX, .AX);
    try std.testing.expectEqual(@as(u16, 0xAB00), inst);
}

test "encodeAlu DEC BX" {
    // ALU=0xA, DEC=12, dst=BX(1), src=AX(0)
    // 1010 1100 01 00 0000 = 0xAC40
    const inst = encodeAlu(.DEC, .BX, .AX);
    try std.testing.expectEqual(@as(u16, 0xAC40), inst);
}

test "encodeAlu NOT CX" {
    // ALU=0xA, NOT=13, dst=CX(2), src=CX(2)
    // 1010 1101 10 10 0000 = 0xADA0
    const inst = encodeAlu(.NOT, .CX, .CX);
    try std.testing.expectEqual(@as(u16, 0xADA0), inst);
}

test "encodeAlu NEG DX" {
    // ALU=0xA, NEG=14, dst=DX(3), src=DX(3)
    // 1010 1110 11 11 0000 = 0xAEF0
    const inst = encodeAlu(.NEG, .DX, .DX);
    try std.testing.expectEqual(@as(u16, 0xAEF0), inst);
}

test "encodeAlu XCHG AX, BX" {
    // ALU=0xA, XCHG=15, dst=AX(0), src=BX(1)
    // 1010 1111 00 01 0000 = 0xAF10
    const inst = encodeAlu(.XCHG, .AX, .BX);
    try std.testing.expectEqual(@as(u16, 0xAF10), inst);
}

test "encodeAlu bit positions" {
    // ADD CX, DX: opcode=1010, alu_op=0000, dst=10, src=11
    const inst = encodeAlu(.ADD, .CX, .DX);
    const opcode: u4 = @intCast((inst >> 12) & 0xF);
    const alu_op: u4 = @intCast((inst >> 8) & 0xF);
    const dst: u2 = @intCast((inst >> 6) & 0x3);
    const src: u2 = @intCast((inst >> 4) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.ALU), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.AluOp.ADD), alu_op);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.CX), dst);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.DX), src);
}

// =============================================================================
// encodePushPop — 16-bit Stack Operation Encoding
// Format: [opcode=PushPop:4][reg:2][stack_op:2][unused:8]
// =============================================================================

test "encodePushPop PUSH AX" {
    // PushPop=0xC, reg=AX(0), stack_op=PUSH(0)
    // 1100 00 00 00000000 = 0xC000
    const inst = encodePushPop(.PUSH, .AX);
    try std.testing.expectEqual(@as(u16, 0xC000), inst);
}

test "encodePushPop POP BX" {
    // PushPop=0xC, reg=BX(1), stack_op=POP(1)
    // 1100 01 01 00000000 = 0xC500
    const inst = encodePushPop(.POP, .BX);
    try std.testing.expectEqual(@as(u16, 0xC500), inst);
}

test "encodePushPop PUSH CX" {
    // PushPop=0xC, reg=CX(2), stack_op=PUSH(0)
    // 1100 10 00 00000000 = 0xC800
    const inst = encodePushPop(.PUSH, .CX);
    try std.testing.expectEqual(@as(u16, 0xC800), inst);
}

test "encodePushPop POP DX" {
    // PushPop=0xC, reg=DX(3), stack_op=POP(1)
    // 1100 11 01 00000000 = 0xCD00
    const inst = encodePushPop(.POP, .DX);
    try std.testing.expectEqual(@as(u16, 0xCD00), inst);
}

test "encodePushPop bit positions" {
    // PUSH BX: opcode=1100, dst=01, stack_op=00
    const inst = encodePushPop(.PUSH, .BX);
    const opcode: u4 = @intCast((inst >> 12) & 0xF);
    const reg: u2 = @intCast((inst >> 10) & 0x3);
    const stack_op: u2 = @intCast((inst >> 8) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.PushPop), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.BX), reg);
    try std.testing.expectEqual(@intFromEnum(ISA.StackOp.PUSH), stack_op);
}

// =============================================================================
// encodeCondJump — 32-bit Conditional Jump Encoding
// Format: [opcode=CondJump:4][mode=01:2][cond:4][target:16][unused:4]
// =============================================================================

test "encodeCondJump JZ 0x0040" {
    // CondJump=0xB, mode=01, JZ=0, target=0x0040
    // 1011 01 0000 0000000001000000 0000 = 0xB1000400
    const inst = encodeCondJump(.JZ, 0x0040);
    try std.testing.expectEqual(@as(u32, 0xB1000400), inst);
}

test "encodeCondJump JNZ 0x0080" {
    // CondJump=0xB, mode=01, JNZ=1, target=0x0080
    // 1011 01 0001 0000000010000000 0000 = 0xB1100800
    const inst = encodeCondJump(.JNZ, 0x0080);
    try std.testing.expectEqual(@as(u32, 0xB1100800), inst);
}

test "encodeCondJump JC 0x0100" {
    // CondJump=0xB, mode=01, JC=2, target=0x0100
    // 1011 01 0010 0000000100000000 0000 = 0xB1201000
    const inst = encodeCondJump(.JC, 0x0100);
    try std.testing.expectEqual(@as(u32, 0xB1201000), inst);
}

test "encodeCondJump JNC 0x0200" {
    // CondJump=0xB, mode=01, JNC=3, target=0x0200
    // 1011 01 0011 0000001000000000 0000 = 0xB1302000
    const inst = encodeCondJump(.JNC, 0x0200);
    try std.testing.expectEqual(@as(u32, 0xB1302000), inst);
}

test "encodeCondJump JS 0x0400" {
    // CondJump=0xB, mode=01, JS=4, target=0x0400
    // 1011 01 0100 0000010000000000 0000 = 0xB1404000
    const inst = encodeCondJump(.JS, 0x0400);
    try std.testing.expectEqual(@as(u32, 0xB1404000), inst);
}

test "encodeCondJump JNS 0x0800" {
    // CondJump=0xB, mode=01, JNS=5, target=0x0800
    // 1011 01 0101 0000100000000000 0000 = 0xB1508000
    const inst = encodeCondJump(.JNS, 0x0800);
    try std.testing.expectEqual(@as(u32, 0xB1508000), inst);
}

test "encodeCondJump bit positions" {
    // JC 0x0100: opcode=1011, mode=01 (at bits 27:24), cond=0010, target=0x0100
    const inst = encodeCondJump(.JC, 0x0100);
    const opcode: u4 = @intCast((inst >> 28) & 0xF);
    const mode: u2 = @intCast((inst >> 24) & 0x3);
    const cond: u4 = @intCast((inst >> 20) & 0xF);
    const target: u16 = @intCast((inst >> 4) & 0xFFFF);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.CondJump), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.Imm), mode);
    try std.testing.expectEqual(@intFromEnum(ISA.CondJump.JC), cond);
    try std.testing.expectEqual(@as(u16, 0x0100), target);
}

// =============================================================================
// Roundtrip: encode → decode → verify
// =============================================================================

test "roundtrip: encode32 MOV → bit fields match" {
    const inst = encode32(.MOV, .AX, 0x1234);
    const opcode: u4 = @intCast((inst >> 28) & 0xF);
    const dst: u2 = @intCast((inst >> 26) & 0x3);
    const mode: u2 = @intCast((inst >> 24) & 0x3);
    const imm: u16 = @intCast((inst >> 8) & 0xFFFF);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.MOV), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.AX), dst);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.Imm), mode);
    try std.testing.expectEqual(@as(u16, 0x1234), imm);
}

test "roundtrip: encodeAlu ADD → bit fields match" {
    const inst = encodeAlu(.ADD, .AX, .BX);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.ALU), @as(u4, @intCast((inst >> 12) & 0xF)));
    try std.testing.expectEqual(@intFromEnum(ISA.AluOp.ADD), @as(u4, @intCast((inst >> 8) & 0xF)));
    try std.testing.expectEqual(@intFromEnum(ISA.Register.AX), @as(u2, @intCast((inst >> 6) & 0x3)));
    try std.testing.expectEqual(@intFromEnum(ISA.Register.BX), @as(u2, @intCast((inst >> 4) & 0x3)));
}

// =============================================================================
// encodeAluImm — 32-bit ALU with Immediate Encoding
// =============================================================================

test "encodeAluImm ADD AX, 0x0042" {
    const inst = encodeAluImm(.ADD, .AX, 0x0042);
    const opcode: u4 = @intCast((inst >> 28) & 0xF);
    const alu_op: u4 = @intCast((inst >> 24) & 0xF);
    const dst: u2 = @intCast((inst >> 22) & 0x3);
    const imm: u16 = @intCast((inst >> 6) & 0xFFFF);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.ALU), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.AluOp.ADD), alu_op);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.AX), dst);
    try std.testing.expectEqual(@as(u16, 0x0042), imm);
}

test "encodeAluImm SUB BX, 0x0010" {
    const inst = encodeAluImm(.SUB, .BX, 0x0010);
    const opcode: u4 = @intCast((inst >> 28) & 0xF);
    const alu_op: u4 = @intCast((inst >> 24) & 0xF);
    const dst: u2 = @intCast((inst >> 22) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.ALU), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.AluOp.SUB), alu_op);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.BX), dst);
}

// =============================================================================
// Additional encodePushPop Tests
// =============================================================================

test "encodePushPop PUSH DX" {
    const inst = encodePushPop(.PUSH, .DX);
    const opcode: u4 = @intCast((inst >> 12) & 0xF);
    const reg: u2 = @intCast((inst >> 10) & 0x3);
    const stack_op: u2 = @intCast((inst >> 8) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.PushPop), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.DX), reg);
    try std.testing.expectEqual(@intFromEnum(ISA.StackOp.PUSH), stack_op);
}

test "encodePushPop POP CX" {
    const inst = encodePushPop(.POP, .CX);
    // opcode=PushPop(0xC)<<12 | reg=CX(2)<<10 | stack_op=POP(1)<<8
    try std.testing.expectEqual(@as(u16, 0xC900), inst);
}

// =============================================================================
// Additional encode16 Tests
// =============================================================================

test "encode16 MOV indirect CX, AX" {
    const inst = encode16(.MOV, .CX, .AX, .Indirect);
    const opcode: u4 = @intCast((inst >> 12) & 0xF);
    const dst: u2 = @intCast((inst >> 10) & 0x3);
    const src: u2 = @intCast((inst >> 8) & 0x3);
    const mode: u2 = @intCast((inst >> 6) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.Opcode.MOV), opcode);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.CX), dst);
    try std.testing.expectEqual(@intFromEnum(ISA.Register.AX), src);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.Indirect), mode);
}

test "encode16 MOV indirect-offset BX, DX" {
    const inst = encode16(.MOV, .BX, .DX, .IndirectOff);
    const mode: u2 = @intCast((inst >> 6) & 0x3);
    try std.testing.expectEqual(@intFromEnum(ISA.AddrMode.IndirectOff), mode);
}

// =============================================================================
// Firmware Generator Smoke Test
// =============================================================================

test "firmware starts with NOP" {
    const fw = ISA.firmware;
    // First word should be NOP (0x0000)
    try std.testing.expectEqual(@as(u8, 0x00), fw[0]);
    try std.testing.expectEqual(@as(u8, 0x00), fw[1]);
}

test "firmware ends with HLT" {
    const fw = ISA.firmware;
    try std.testing.expectEqual(@as(u8, 0x00), fw[62]);
    try std.testing.expectEqual(@as(u8, 0x70), fw[63]);
}

test "firmware: first 4 words are NOP + MOV AX 0xFF + MOV BX 0xF" {
    const fw = ISA.firmware;
    try std.testing.expectEqual(@as(u16, 0x0000), std.mem.readInt(u16, fw[0..][0..2], .little));
    try std.testing.expectEqual(@as(u16, 0xFF00), std.mem.readInt(u16, fw[2..][0..2], .little));
    try std.testing.expectEqual(@as(u16, 0x1100), std.mem.readInt(u16, fw[4..][0..2], .little));
    try std.testing.expectEqual(@as(u16, 0x0F00), std.mem.readInt(u16, fw[6..][0..2], .little));
    try std.testing.expectEqual(@as(u16, 0x1500), std.mem.readInt(u16, fw[8..][0..2], .little));
}

test "firmware: contains ALU ADD instruction" {
    const fw = ISA.firmware;
    try std.testing.expect(std.mem.indexOf(u8, fw[0..], &.{ 0x10, 0xA0 }) != null);
}

test "firmware: contains PUSH/POP pair" {
    const fw = ISA.firmware;
    try std.testing.expect(std.mem.indexOf(u8, fw[0..], &.{ 0x00, 0xC0 }) != null);
    try std.testing.expect(std.mem.indexOf(u8, fw[0..], &.{ 0x00, 0xC5 }) != null);
}

test "firmware: size is 1024 bytes" {
    const fw = ISA.firmware;
    try std.testing.expectEqual(@as(usize, 1024), fw.len);
}

test "firmware: contains HLT" {
    const fw = ISA.firmware;
    try std.testing.expect(std.mem.indexOf(u8, fw[0..], &.{ 0x00, 0x70 }) != null);
}
