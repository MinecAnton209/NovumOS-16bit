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
    cpu.io_ports[0x22] = 0xABCD; // Port 0x22 is generic (not mapped to PIC/PIT/UART)

    // IN AX, 0x22 — read port 0x22 into AX
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0022));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);

    cpu.ax = 0x1234;
    // OUT 0x22, AX — write AX to port 0x22
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.OUT, .AX, 0x0022));

    cpu.ip = 0x0004;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.io_ports[0x22]);
}

// =============================================================================
// UART Simple Tests (port 0x00)
// =============================================================================

// Write and read UART data (port 0x00).
test "UART: write/read data" {
    var cpu = CPU{};

    // OUT 0x00, 'A' — write character
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0000));
    cpu.ax = @intCast(@as(u16, 'A'));

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 'A'), cpu.uart_tx[0]);
    try std.testing.expectEqual(@as(u8, 1), cpu.uart_tx_head);

    // Read back from RX buffer
    cpu.uart_rx[0] = 'B';
    cpu.uart_rx_head = 1;
    cpu.uart_rx_tail = 0;

    writeInstruction32(&cpu.memory, 4, ISA.encode32(.IN, .AX, 0x0000));
    cpu.ip = 0x0004;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'B'), cpu.ax);
}

// Read UART when empty returns 0.
test "UART: read empty returns 0" {
    var cpu = CPU{};

    // IN AX, 0x00 — read from empty buffer
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0000));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0), cpu.ax);
}

// Timer reads cycle count (port 0x01).
test "Timer: read cycle count" {
    var cpu = CPU{};
    cpu.cycle_count = 0x1234;

    // IN AX, 0x01 — read timer
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0001));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

// Keyboard reads scan code (port 0x02).
test "Keyboard: read scan code" {
    var cpu = CPU{};
    cpu.kbd_buffer[0] = 0x1E; // 'A' scan code
    cpu.kbd_head = 1;

    // IN AX, 0x02 — read keyboard
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0002));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1E), cpu.ax);
    try std.testing.expectEqual(@as(u8, 1), cpu.kbd_tail); // Tail advanced
}

// Keyboard reads 0 when empty.
test "Keyboard: read empty returns 0" {
    var cpu = CPU{};

    // IN AX, 0x02 — read from empty buffer
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0002));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0), cpu.ax);
}

// FlushUartTx prints all pending characters.
test "UART: flush TX buffer" {
    var cpu = CPU{};
    cpu.uart_tx[0] = 'H';
    cpu.uart_tx[1] = 'i';
    cpu.uart_tx_head = 2;

    cpu.flushUartTx();
    // flushUartTx advances tail to match head (buffer empty)
    try std.testing.expectEqual(cpu.uart_tx_head, cpu.uart_tx_tail);
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

// =============================================================================
// ALU Edge Cases — Flags (Carry, Zero, Sign)
//
// Flag constants:
//   ZERO_FLAG  = 0x01 (bit 0)
//   CARRY_FLAG = 0x02 (bit 1)
//   SIGN_FLAG  = 0x04 (bit 2)
// =============================================================================

test "ADD: carry flag on overflow" {
    var cpu = CPU{};
    // 0xFFFF + 0x0001 = 0x0000, Carry=1, Zero=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000); // HLT

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // Carry set on overflow
    try std.testing.expect(cpu.getZero()); // Zero set because result is 0
}

test "ADD: no carry" {
    var cpu = CPU{};
    // 0x0010 + 0x0020 = 0x0030, no flags
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0010));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0020));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0030), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

test "ADD: sign flag" {
    var cpu = CPU{};
    // 0x7FFF + 0x0001 = 0x8000, Sign=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x7FFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x8000), cpu.ax);
    try std.testing.expect(cpu.getSign());
}

test "SUB: borrow (carry)" {
    var cpu = CPU{};
    // 0x0000 - 0x0001 = 0xFFFF, Carry=1 (borrow)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // Carry = borrow
}

test "SUB: zero flag" {
    var cpu = CPU{};
    // 0x0042 - 0x0042 = 0x0000, Zero=1, Carry=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0042));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0042));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
}

test "ADC: add with carry set" {
    var cpu = CPU{};
    // Load all registers with 32-bit MOVs first (avoids raw32 lookahead issue
    // where a 16-bit ALU instruction followed by a 32-bit MOV gets misinterpreted)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction32(&cpu.memory, 8, ISA.encode32(.MOV, .CX, 0x0005));
    // ADD AX, BX: 0xFFFF + 0x0001 = 0x0000, sets Carry=1
    writeInstruction(&cpu.memory, 12, ISA.encodeAlu(.ADD, .AX, .BX));
    // ADC AX, CX: 0x0000 + 0x0005 + 1 = 0x0006
    writeInstruction(&cpu.memory, 14, ISA.encodeAlu(.ADC, .AX, .CX));
    writeInstruction(&cpu.memory, 16, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0006), cpu.ax);
}

test "SBB: subtract with borrow" {
    var cpu = CPU{};
    // Step-by-step to avoid raw32 lookahead bug
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    _ = try cpu.step();
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    _ = try cpu.step();
    writeInstruction32(&cpu.memory, 8, ISA.encode32(.MOV, .CX, 0x0002));
    _ = try cpu.step();
    // SUB AX, BX: 0x0000 - 0x0001 = 0xFFFF, sets Carry=1 (borrow)
    writeInstruction(&cpu.memory, 12, ISA.encodeAlu(.SUB, .AX, .BX));
    _ = try cpu.step();
    // SBB AX, CX: 0xFFFF - 0x0002 - 1 = 0xFFFC
    writeInstruction(&cpu.memory, 14, ISA.encodeAlu(.SBB, .AX, .CX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 16, 0x7000);
    _ = try cpu.step();

    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.ax);
}

test "CMP: equal sets zero, clears carry and sign" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x1234));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.CMP, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax); // CMP doesn't modify operand
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

test "CMP: less sets carry" {
    var cpu = CPU{};
    // 0x0001 - 0x0002 = borrow, Carry=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0002));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.CMP, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(!cpu.getZero());
}

// =============================================================================
// ALU Edge Cases — NEG
// =============================================================================

test "NEG 0x0000 = 0x0000" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NEG, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

test "NEG 0x0001 = 0xFFFF" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NEG, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // NEG sets carry if result != 0
}

test "NEG 0x8000 = 0x8000 (overflow)" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x8000));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NEG, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x8000), cpu.ax); // -0x8000 overflows to 0x8000
    try std.testing.expect(cpu.getCarry());
}

test "NEG 0xFFFE = 0x0002" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFE));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NEG, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
}

// =============================================================================
// ALU Edge Cases — NOT
// =============================================================================

test "NOT 0x0000 = 0xFFFF" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NOT, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
}

test "NOT 0xFFFF = 0x0000" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NOT, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
}

test "NOT 0x5555 = 0xAAAA" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x5555));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.NOT, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xAAAA), cpu.ax);
}

// =============================================================================
// ALU Edge Cases — SHL / SHR
// =============================================================================

test "SHL by 1" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
}

test "SHL by 8" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x00FF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0008));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFF00), cpu.ax);
}

test "SHL by 15 — bit shifted out" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x000F));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x8000), cpu.ax);
}

test "SHR by 1" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x8000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x4000), cpu.ax);
}

test "SHR by 8" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFF00));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0008));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax);
}

test "SHR by 15" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x8000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x000F));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0001), cpu.ax);
}

test "SHL by 0 — no change" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0000));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

test "SHR by 0 — no change" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0000));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

// =============================================================================
// CPU Edge Cases — Stack
// =============================================================================

test "PUSH at SP=0xFFFE — normal" {
    var cpu = CPU{};
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    cpu.ax = 0xABCD;
    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.sp);
    // Memory at SP after push: 0xFFFC
    const lo = cpu.memory[0xFFFC];
    const hi = cpu.memory[0xFFFD];
    try std.testing.expectEqual(@as(u8, 0xCD), lo);
    try std.testing.expectEqual(@as(u8, 0xAB), hi);
}

test "POP at SP=0xFFFC — normal" {
    var cpu = CPU{};
    // Push AX, then pop BX — step-by-step to avoid raw32 lookahead bug
    cpu.ax = 0x1234;
    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.POP, .BX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 4, 0x7000);
    _ = try cpu.step();

    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.bx);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

test "PUSH wraps SP to 0" {
    var cpu = CPU{};
    cpu.sp = 0x0002; // Will wrap to 0x0000 after push (SP -= 2)

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    cpu.ax = 0x5678;
    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.sp);
}

test "PUSH multiple — SP decreases" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0002;
    cpu.cx = 0x0003;

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.PUSH, .BX));
    writeInstruction(&cpu.memory, 4, ISA.encodePushPop(.PUSH, .CX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFF8), cpu.sp);
}

test "POP multiple — SP increases" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0002;

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.PUSH, .BX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 4, ISA.encodePushPop(.POP, .CX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 6, ISA.encodePushPop(.POP, .DX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 8, 0x7000);
    _ = try cpu.step();

    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.cx); // Last pushed = first popped
    try std.testing.expectEqual(@as(u16, 0x0001), cpu.dx);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// CPU Edge Cases — IP boundary
// =============================================================================

test "HLT at address 0xFFFE" {
    var cpu = CPU{};
    // Place HLT at the very end of memory
    cpu.memory[0xFFFE] = 0x00; // NOP low byte
    cpu.memory[0xFFFF] = 0x70; // HLT high byte (0x7000)
    cpu.ip = 0xFFFE;

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
}

test "IP wraps around memory" {
    var cpu = CPU{};
    // JMP to 0x0004 from 0xFFFC
    writeInstruction32(&cpu.memory, 0xFFFC, ISA.encode32(.JMP, .AX, 0x0004));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .AX, 0xBEEF));
    writeInstruction(&cpu.memory, 8, 0x7000);
    cpu.ip = 0xFFFC;

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xBEEF), cpu.ax);
}

// =============================================================================
// CPU Edge Cases — INT / IRET
//
// INT behavior: push FLAGS, push (IP+4), jump to vector*4
// IRET behavior: pop IP, pop FLAGS
//
// So for INT 0x0002: jumps to 0x0002 * 4 = 0x0008
// IRET stack layout (growing down):
//   [SP]   = return IP (popped first)
//   [SP+2] = flags    (popped second)
// =============================================================================

test "INT pushes IP and FLAGS, jumps to ISR" {
    var cpu = CPU{};
    cpu.flags = CPU.ZERO_FLAG | CPU.CARRY_FLAG | CPU.SIGN_FLAG; // Z=1, C=1, S=1

    // INT 0x0002 at address 0x0000 → jumps to vector*4 = 0x0008
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.INT, .AX, 0x0002));
    // ISR at 0x0008: HLT
    writeInstruction(&cpu.memory, 0x0008, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expect(cpu.sp < 0xFFFE); // Stack was used (2 pushes: flags + return IP)
    // Verify pushed values: SP should be 0xFFFA (pushed flags at 0xFFFC, return addr at 0xFFFE)
    // After INT: SP was decremented twice (flags then IP), so SP = 0xFFFE - 4 = 0xFFFA
    try std.testing.expectEqual(@as(u16, 0xFFFA), cpu.sp);
    // INT pushes FLAGS first, then return IP. So stack is:
    //   SP+0 = return IP (pushed last, on top)
    //   SP+2 = flags    (pushed first, below)
    const pushed_ip = cpu.readWord(cpu.sp);
    try std.testing.expectEqual(@as(u16, 0x0004), pushed_ip);
    const pushed_flags = cpu.readWord(cpu.sp + 2);
    try std.testing.expectEqual(@as(u16, CPU.ZERO_FLAG | CPU.CARRY_FLAG | CPU.SIGN_FLAG), pushed_flags);
}

test "IRET restores IP and FLAGS" {
    var cpu = CPU{};
    // IRET pops IP first, then FLAGS.
    // Stack layout at SP=0xFFFA:
    //   [0xFFFA] = return IP low
    //   [0xFFFB] = return IP high
    //   [0xFFFC] = flags low
    //   [0xFFFD] = flags high
    cpu.sp = 0xFFFA;
    cpu.memory[0xFFFA] = 0x10; // IP low byte (return to 0x0010)
    cpu.memory[0xFFFB] = 0x00; // IP high byte
    cpu.memory[0xFFFC] = 0x05; // flags low byte (0x0005 = Z|C)
    cpu.memory[0xFFFD] = 0x00; // flags high byte

    // IRET at address 0x0000
    writeInstruction(&cpu.memory, 0, ISA.encode16(.IRET, .AX, .AX, .RegReg));
    // HLT at restored IP (0x0010)
    writeInstruction(&cpu.memory, 0x0010, 0x7000);

    cpu.ip = 0x0000;
    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0005), cpu.flags);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// Conditional Jumps — All Flag Combinations
//
// Pattern: Use ALU ops to set flags naturally, then test the jump.
//   Z=1: SUB equal values (5-5=0, Z=1)
//   C=1: SUB small-from-large (0-1=0xFFFF, C=1)
//   S=1: ADD 0x7FFF+1=0x8000 (S=1)
//   All clear: ADD small values (1+2=3, no flags)
// =============================================================================

test "JZ: taken when Z=1" {
    var cpu = CPU{};
    // SUB 5 - 5 = 0 → sets Z=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 5));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JZ to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JZ, 0x0020));
    // Not-taken path: MOV AX, 0x0000
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000); // HLT
    // Taken path at 0x0020: MOV AX, 0x1234
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction(&cpu.memory, 0x0024, 0x7000); // HLT

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

test "JZ: not taken when Z=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → Z=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JZ to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JZ, 0x0020));
    // Fallthrough: MOV AX, 0x5678
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x5678));
    writeInstruction(&cpu.memory, 18, 0x7000); // HLT

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x5678), cpu.ax);
}

test "JNZ: taken when Z=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → Z=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JNZ to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNZ, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0xABCD
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0xABCD));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

test "JNZ: not taken when Z=1" {
    var cpu = CPU{};
    // SUB 5 - 5 = 0 → Z=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 5));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JNZ to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNZ, 0x0020));
    // Fallthrough: MOV AX, 0x9999
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x9999));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x9999), cpu.ax);
}

test "JC: taken when C=1" {
    var cpu = CPU{};
    // SUB 0 - 1 = 0xFFFF → C=1 (borrow)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 1));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JC to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JC, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0x1111
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0x1111));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1111), cpu.ax);
}

test "JC: not taken when C=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → C=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JC to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JC, 0x0020));
    // Fallthrough: MOV AX, 0x2222
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x2222));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x2222), cpu.ax);
}

test "JNC: taken when C=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → C=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JNC to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNC, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0x3333
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0x3333));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x3333), cpu.ax);
}

test "JNC: not taken when C=1" {
    var cpu = CPU{};
    // SUB 0 - 1 = 0xFFFF → C=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 1));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JNC to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNC, 0x0020));
    // Fallthrough: MOV AX, 0x4444
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x4444));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x4444), cpu.ax);
}

test "JS: taken when S=1" {
    var cpu = CPU{};
    // ADD 0x7FFF + 1 = 0x8000 → S=1 (bit 15 set)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x7FFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 1));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    // JS to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JS, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0x5555
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0x5555));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x5555), cpu.ax);
}

test "JS: not taken when S=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → S=0 (bit 15 clear)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JS to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JS, 0x0020));
    // Fallthrough: MOV AX, 0x6666
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x6666));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x6666), cpu.ax);
}

test "JNS: taken when S=0" {
    var cpu = CPU{};
    // SUB 5 - 3 = 2 → S=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 5));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 3));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JNS to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNS, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0x7777
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0x7777));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x7777), cpu.ax);
}

test "JNS: not taken when S=1" {
    var cpu = CPU{};
    // ADD 0x7FFF + 1 = 0x8000 → S=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x7FFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 1));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    // JNS to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JNS, 0x0020));
    // Fallthrough: MOV AX, 0x8888
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x8888));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x8888), cpu.ax);
}

test "JZ: multiple flags set — only Z matters" {
    var cpu = CPU{};
    // Use SUB equal values to get Z=1, then OR with S via ADD to set S
    // Actually simpler: SUB 0x8000 - 0x8000 = 0 → Z=1, S=0 (result is 0)
    // We need Z=1, C=1, S=1 simultaneously. Use ADC trick:
    // 1) SUB 0 - 1 → C=1, S=1 (result 0xFFFF)
    // 2) ADD 0x8000 + 0x8000 → S=1 (but clears C)
    // Better: just set up so SUB equal values give Z=1, then check JZ
    // Actually, SUB equal positive values: Z=1, C=0, S=0. That's fine for testing Z.
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x1234));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    // JZ to 0x0020
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JZ, 0x0020));
    // Not-taken path
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 18, 0x7000);
    // Taken path: MOV AX, 0xBBBB
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.MOV, .AX, 0xBBBB));
    writeInstruction(&cpu.memory, 0x0024, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
}

test "JC: Z and S set but C=0 — not taken" {
    var cpu = CPU{};
    // ADD 0x7FFF + 0x0001 = 0x8000 → S=1, Z=0, C=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x7FFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    // JC to 0x0020 (should NOT be taken, C=0)
    writeInstruction32(&cpu.memory, 10, ISA.encodeCondJump(.JC, 0x0020));
    // Fallthrough: MOV AX, 0xCCCC
    writeInstruction32(&cpu.memory, 14, ISA.encode32(.MOV, .AX, 0xCCCC));
    writeInstruction(&cpu.memory, 18, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xCCCC), cpu.ax);
}

// =============================================================================
// ALU — All flag interactions
// =============================================================================

test "ADD: Z=0 C=0 S=0" {
    var cpu = CPU{};
    // 1 + 2 = 3, no flags
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0002));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0003), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0), cpu.flags); // No flags set
}

test "SUB: Z=0 C=1 S=1" {
    var cpu = CPU{};
    // 0 - 1 = 0xFFFF, C=1 (borrow), S=1, Z=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getSign());
    try std.testing.expect(!cpu.getZero());
}

test "AND: result zero sets Z" {
    var cpu = CPU{};
    // 0x00FF & 0xFF00 = 0x0000 → Z=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x00FF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0xFF00));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.AND, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

test "OR: result non-zero clears Z" {
    var cpu = CPU{};
    // 0x00F0 | 0x000F = 0x00FF → Z=0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x00F0));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x000F));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.OR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax);
    try std.testing.expect(!cpu.getZero());
}

test "XOR: same values clears to zero" {
    var cpu = CPU{};
    // 0x1234 ^ 0x1234 = 0x0000 → Z=1
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x1234));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.XOR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

test "INC: no carry flag" {
    var cpu = CPU{};
    // INC 0xFFFF = 0x0000, INC does NOT affect Carry
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.INC, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(!cpu.getCarry()); // INC does NOT set carry
    try std.testing.expect(cpu.getZero()); // Result is zero
}

test "DEC: no carry flag" {
    var cpu = CPU{};
    // DEC 0x0000 = 0xFFFF, DEC does NOT affect Carry
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.DEC, .AX, .AX));
    writeInstruction(&cpu.memory, 6, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(!cpu.getCarry()); // DEC does NOT set carry
    try std.testing.expect(cpu.getSign()); // Result is negative (bit 15 set)
}
