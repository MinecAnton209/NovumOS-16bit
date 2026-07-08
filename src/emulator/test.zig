const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const ISA = @import("codegen");

/// Write a 16-bit instruction into CPU memory at the given address (little-endian).
/// Used by tests to set up instruction sequences before stepping the CPU.
fn writeInstruction(memory: []u8, addr: u16, word: u16) void {
    memory[addr] = @intCast(word & 0xFF);
    memory[addr + 1] = @intCast((word >> 8) & 0xFF);
}

/// Write a 32-bit instruction into CPU memory at the given address (little-endian).
/// 32-bit instructions occupy 4 consecutive bytes (2 words).
fn writeInstruction32(memory: []u8, addr: u16, val: u32) void {
    memory[addr] = @intCast(val & 0xFF);
    memory[addr + 1] = @intCast((val >> 8) & 0xFF);
    memory[addr + 2] = @intCast((val >> 16) & 0xFF);
    memory[addr + 3] = @intCast((val >> 24) & 0xFF);
}

// =============================================================================
// CPU Reset Tests
// =============================================================================

// Verify that reset() clears all registers and sets SP to 0xFFFE.
test "CPU reset" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0x1234;
    cpu.ip = 0x0100;
    cpu.reset();

    try std.testing.expectEqual(@as(u16, 0), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0), cpu.bx);
    try std.testing.expectEqual(@as(u16, 0), cpu.ip);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// NOP Test
// =============================================================================

// NOP (opcode=0x0000) should advance IP by 2 with no side effects.
test "NOP" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, 0x0000);

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 2), cpu.ip);
}

// =============================================================================
// MOV Tests
// =============================================================================

// MOV AX, BX — 16-bit register-to-register move.
// Encoded: opcode=1(0001) dst=AX(00) src=BX(01) mode=RegReg(00)
test "MOV reg, reg" {
    var cpu = CPU{};
    cpu.bx = 0x1234;
    // MOV AX, BX: opcode=0001 dst=00 src=01 mode=00
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .BX, .RegReg));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
    try std.testing.expectEqual(@as(u16, 2), cpu.ip);
}

// MOV AX, 0x00FF — 32-bit immediate load.
// Encoded: opcode=1(0001) dst=AX(00) mode=Imm(01) imm=0x00FF
// CPU detects mode=01 at bits 25:24 → 32-bit instruction.
test "MOV reg, imm" {
    var cpu = CPU{};
    // MOV AX, 0x00FF
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x00FF));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax);
    try std.testing.expectEqual(@as(u16, 4), cpu.ip);
}

// =============================================================================
// ALU Arithmetic Tests
// =============================================================================

// ADD AX, BX — AX = AX + BX = 1 + 2 = 3
test "ADD reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0002;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADD, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0003), cpu.ax);
}

// SUB AX, BX — AX = AX - BX = 5 - 3 = 2
test "SUB reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0005;
    cpu.bx = 0x0003;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SUB, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
}

// =============================================================================
// CMP Tests (compare sets flags without storing result)
// =============================================================================

// CMP AX, BX when AX == BX → Zero flag set, Sign flag clear
test "CMP equal" {
    var cpu = CPU{};
    cpu.ax = 0x0005;
    cpu.bx = 0x0005;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.CMP, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(true, cpu.getZero());
    try std.testing.expectEqual(false, cpu.getSign());
}

// CMP AX, BX when AX < BX → Zero clear, Carry set (borrow)
test "CMP less" {
    var cpu = CPU{};
    cpu.ax = 0x0003;
    cpu.bx = 0x0005;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.CMP, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(false, cpu.getZero());
    try std.testing.expectEqual(true, cpu.getCarry());
}

// =============================================================================
// ALU Bitwise Tests
// =============================================================================

// AND AX, BX — 0x0F0F & 0xFF00 = 0x0F00
test "AND reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0F0F;
    cpu.bx = 0xFF00;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.AND, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0F00), cpu.ax);
}

// OR AX, BX — 0x0F00 | 0x00FF = 0x0FFF
test "OR reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0F00;
    cpu.bx = 0x00FF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.OR, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0FFF), cpu.ax);
}

// XOR AX, BX — 0xFF00 ^ 0x0FF0 = 0xF0F0
test "XOR reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0xFF00;
    cpu.bx = 0x0FF0;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xF0F0), cpu.ax);
}

// =============================================================================
// ALU Shift Tests
// =============================================================================

// SHL AX, BX — AX << 4 = 0x0001 << 4 = 0x0010
test "SHL reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0004;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ax);
}

// SHR AX, BX — AX >> 2 = 0x0010 >> 2 = 0x0004
test "SHR reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x0010;
    cpu.bx = 0x0002;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ax);
}

// =============================================================================
// ALU Increment/Decrement Tests
// =============================================================================

// INC AX — AX = 0x00FF + 1 = 0x0100
test "INC reg" {
    var cpu = CPU{};
    cpu.ax = 0x00FF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.INC, .AX, .AX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0100), cpu.ax);
}

// DEC AX — AX = 0x0100 - 1 = 0x00FF
test "DEC reg" {
    var cpu = CPU{};
    cpu.ax = 0x0100;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.DEC, .AX, .AX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax);
}

// =============================================================================
// ALU Bit Manipulation Tests
// =============================================================================

// NOT AX — ~0x00FF = 0xFF00 (bitwise complement)
test "NOT reg" {
    var cpu = CPU{};
    cpu.ax = 0x00FF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NOT, .AX, .AX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFF00), cpu.ax);
}

// NEG AX — -1 = 0xFFFF (two's complement negate)
test "NEG reg" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NEG, .AX, .AX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
}

// =============================================================================
// ALU Exchange Test
// =============================================================================

// XCHG AX, BX — swap register values
test "XCHG reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.bx = 0x5678;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XCHG, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x5678), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.bx);
}

// =============================================================================
// ALU Add-with-Carry / Subtract-with-Borrow Tests
// =============================================================================

// ADC AX, BX — AX = AX + BX + Carry = 1 + 2 + 1 = 4
test "ADC with carry" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0002;
    cpu.flags |= CPU.CARRY_FLAG;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADC, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ax);
}

// SBB AX, BX — AX = AX - BX - Carry = 5 - 2 - 1 = 2
test "SBB with borrow" {
    var cpu = CPU{};
    cpu.ax = 0x0005;
    cpu.bx = 0x0002;
    cpu.flags |= CPU.CARRY_FLAG;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SBB, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
}

// =============================================================================
// Stack Tests (PUSH/POP)
// =============================================================================

// PUSH AX then POP BX — verify stack pointer movement and data transfer.
// PUSH: SP decreases by 2 (0xFFFE → 0xFFFC), value written to [SP].
// POP: SP increases by 2 (0xFFFC → 0xFFFE), value read from [SP-2].
test "PUSH/POP" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.sp = 0xFFFE;

    // PUSH AX — SP should decrease to 0xFFFC, value 0x1234 at [0xFFFC]
    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.readWord(0xFFFC));

    // POP BX — SP should increase back to 0xFFFE, BX gets 0x1234
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.POP, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.bx);
}

// =============================================================================
// Conditional Jump Tests (6 conditions)
// =============================================================================

// JZ — jump taken when Zero flag is set
test "JZ taken" {
    var cpu = CPU{};
    cpu.flags |= CPU.ZERO_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JZ, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// JZ — jump NOT taken when Zero flag is clear
test "JZ not taken" {
    var cpu = CPU{};
    cpu.flags &= ~CPU.ZERO_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JZ, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

// JNZ — jump taken when Zero flag is clear
test "JNZ taken" {
    var cpu = CPU{};
    cpu.flags &= ~CPU.ZERO_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JNZ, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// JC — jump taken when Carry flag is set
test "JC taken" {
    var cpu = CPU{};
    cpu.flags |= CPU.CARRY_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JC, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// JNC — jump taken when Carry flag is clear
test "JNC taken" {
    var cpu = CPU{};
    cpu.flags &= ~CPU.CARRY_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JNC, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// JS — jump taken when Sign flag is set (negative result)
test "JS taken" {
    var cpu = CPU{};
    cpu.flags |= CPU.SIGN_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JS, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// JNS — jump taken when Sign flag is clear (non-negative result)
test "JNS taken" {
    var cpu = CPU{};
    cpu.flags &= ~CPU.SIGN_FLAG;
    writeInstruction32(&cpu.memory, 0, ISA.encodeCondJump(.JNS, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// =============================================================================
// HLT Test
// =============================================================================

// HLT — halt the CPU (halted flag becomes true)
test "HLT" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, 0x7000); // HLT opcode=0111

    try cpu.step();
    try std.testing.expectEqual(true, cpu.halted);
}

// =============================================================================
// CALL/RET Test (subroutine call and return)
// =============================================================================

// CALL pushes return address (IP+4) onto stack, jumps to target.
// RET pops return address from stack back into IP.
test "CALL/RET" {
    var cpu = CPU{};
    cpu.sp = 0xFFFE;

    // CALL 0x0020 at address 0x0000
    // Return address pushed: 0x0000 + 4 = 0x0004
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.CALL, .AX, 0x0020));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0020), cpu.ip); // jumped to 0x0020
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.sp); // SP decreased by 2

    // RET at address 0x0020 — pops 0x0004 back into IP
    writeInstruction(&cpu.memory, 0x20, 0x4000); // RET opcode=0100

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip); // returned to 0x0004
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp); // SP restored
}

// =============================================================================
// IN/OUT Test (I/O port access)
// =============================================================================

// IN reads from I/O port into register.
// OUT writes from register to I/O port.
test "IN/OUT" {
    var cpu = CPU{};
    cpu.io_ports[0x42] = 0xABCD;

    // IN AX, 0x42 — read port 0x42 into AX
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0042));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);

    cpu.ax = 0x1234;
    // OUT 0x42, AX — write AX to port 0x42
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.OUT, .AX, 0x0042));

    cpu.ip = 0x0004;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.io_ports[0x42]);
}

// =============================================================================
// Full Program Integration Test
// =============================================================================

// Multi-instruction program: MOV AX,5 → MOV BX,3 → SUB AX,BX → HLT
// Verifies that the CPU executes a sequence and halts correctly.
// Expected result: AX = 5 - 3 = 2, halted after 4 cycles.
test "Full program: MOV, SUB, HLT" {
    var cpu = CPU{};

    // MOV AX, 5 — load immediate 5 into AX
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    // MOV BX, 3 — load immediate 3 into BX
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    // SUB AX, BX — AX = AX - BX = 5 - 3 = 2
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // HLT — halt CPU
    writeInstruction(&cpu.memory, 10, 0x7000);

    const cycles = try cpu.run(100);
    try std.testing.expectEqual(true, cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
    try std.testing.expect(cycles <= 4);
}
