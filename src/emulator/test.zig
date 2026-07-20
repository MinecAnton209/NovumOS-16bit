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
// ALU Carry Operations (ADC, SBB)
// =============================================================================

// ADC AX, BX — AX = AX + BX + carry = 5 + 3 + 0 = 8 (carry=0)
test "ADC reg, reg no carry" {
    var cpu = CPU{};
    cpu.ax = 0x0005;
    cpu.bx = 0x0003;
    cpu.setCarry(false);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADC, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0008), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

// ADC with carry in: 5 + 3 + 1 = 9
test "ADC reg, reg with carry" {
    var cpu = CPU{};
    cpu.ax = 0x0005;
    cpu.bx = 0x0003;
    cpu.setCarry(true);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADC, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0009), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

// ADC with overflow: 0xFFFF + 1 + 0 = 0x0000, Carry=1
test "ADC overflow" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0x0001;
    cpu.setCarry(false);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADC, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getZero());
}

// SBB AX, BX — AX = AX - BX - carry = 10 - 3 - 0 = 7 (carry=0)
test "SBB reg, reg no borrow" {
    var cpu = CPU{};
    cpu.ax = 0x000A;
    cpu.bx = 0x0003;
    cpu.setCarry(false);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SBB, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0007), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

// SBB with borrow in: 10 - 3 - 1 = 6
test "SBB reg, reg with borrow" {
    var cpu = CPU{};
    cpu.ax = 0x000A;
    cpu.bx = 0x0003;
    cpu.setCarry(true);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SBB, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0006), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

// SBB with borrow: 0 - 1 - 0 = 0xFFFF, Carry=1
test "SBB borrow" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0x0001;
    cpu.setCarry(false);
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SBB, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getCarry());
}

// =============================================================================
// ALU Exchange Test (XCHG)
// =============================================================================

// XCHG AX, BX — swap values between AX and BX
test "XCHG reg, reg" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.bx = 0xABCD;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XCHG, .AX, .BX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.bx);
}

// XCHG same register — no-op
test "XCHG same reg" {
    var cpu = CPU{};
    cpu.ax = 0x5555;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XCHG, .AX, .AX));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x5555), cpu.ax);
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
// Conditional Jump Tests — 32-bit format (6 conditions)
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
// CondJump 16-bit Format Tests
// =============================================================================

// 16-bit JZ: jump taken when Zero flag is set
test "JZ taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.ZERO_FLAG;
    // 16-bit CondJump: opcode=CondJump<<12 | cond=JZ<<8 | mode=Imm<<6
    const word = (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(ISA.CondJump.JZ)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
    writeInstruction(&cpu.memory, 0, word);
    writeInstruction(&cpu.memory, 2, 0x0010);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0010), cpu.ip);
}

// 16-bit JZ: jump NOT taken when Zero flag is clear
test "JZ not taken 16-bit" {
    var cpu = CPU{};
    cpu.flags &= ~CPU.ZERO_FLAG;
    const word = (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(ISA.CondJump.JZ)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
    writeInstruction(&cpu.memory, 0, word);
    writeInstruction(&cpu.memory, 2, 0x0010);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip); // skipped (IP+4)
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

// UART status (port 0x01) returns RX Ready bit when data is available.
test "UART status: RX Ready set when data available" {
    var cpu = CPU{};
    cpu.uart_rx[0] = 'A';
    cpu.uart_rx_head = 1;
    const status = cpu.readPort(0x01);
    try std.testing.expect(status & 0x0001 != 0);
}

// UART status (port 0x01) returns RX Ready = 0 when RX buffer is empty.
test "UART status: RX Ready clear when empty" {
    var cpu = CPU{};
    const status = cpu.readPort(0x01);
    try std.testing.expectEqual(@as(u16, 0), status & 0x0001);
}

// UART status (port 0x01) returns TX Empty bit when TX buffer is empty.
test "UART status: TX Empty set when no data pending" {
    var cpu = CPU{};
    const status = cpu.readPort(0x01);
    try std.testing.expect(status & 0x0002 != 0);
}

// UART status (port 0x01) returns TX Empty = 0 when TX buffer has data.
test "UART status: TX Empty clear when data pending" {
    var cpu = CPU{};
    cpu.uartWriteData('H');
    const status = cpu.readPort(0x01);
    try std.testing.expectEqual(@as(u16, 0), status & 0x0002);
}

// Timer reads cycle count (port 0x05).
test "Timer: read cycle count" {
    var cpu = CPU{};
    cpu.cycle_count = 0x1234;

    // IN AX, 0x05 — read timer
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0005));

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
    // We need Z=1, C=1, S=1 simultaneously. Use carry+sign trick:
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

// =============================================================================
// VGA Tests — direct calls to vgaPutChar / vgaControl / vgaScrollUp
// =============================================================================

// vgaPutChar with a printable character writes to the VGA buffer at cursor
// position, advances cursor column, and sets dirty flag.
test "VGA: putChar printable" {
    var cpu = CPU{};
    cpu.vgaPutChar('A');

    try std.testing.expectEqual(@as(u16, 0x0741), cpu.vga_buffer[0]);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 1), cpu.vga_cursor_col);
    try std.testing.expectEqual(true, cpu.vga_dirty);
}

// vgaPutChar with CR (0x0D) sets cursor column to 0.
test "VGA: putChar CR" {
    var cpu = CPU{};
    cpu.vga_cursor_col = 42;
    cpu.vgaPutChar(0x0D);

    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
}

// vgaPutChar with LF (0x0A) advances cursor row by 1.
test "VGA: putChar LF" {
    var cpu = CPU{};
    cpu.vgaPutChar(0x0A);

    try std.testing.expectEqual(@as(u16, 1), cpu.vga_cursor_row);
}

// vgaPutChar with Backspace (0x08) moves cursor back and clears the cell.
test "VGA: putChar Backspace" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741; // 'A' at row 0, col 0
    cpu.vga_cursor_col = 1;
    cpu.vgaPutChar(0x08);

    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[0]); // cleared to space
}

// When a printable character reaches column 80, it wraps to the next row.
test "VGA: printable wraps at col 80" {
    var cpu = CPU{};
    cpu.vga_cursor_col = 79;
    cpu.vgaPutChar('X');

    // 'X' should be at row 0, col 79
    try std.testing.expectEqual(@as(u16, 0x0758), cpu.vga_buffer[79]);
    // Cursor should now be at row 1, col 0
    try std.testing.expectEqual(@as(u16, 1), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
}

// vgaPutChar LF at the last row triggers a scroll.
test "VGA: LF scrolls at row 25" {
    var cpu = CPU{};
    cpu.vga_cursor_row = 24;
    // Put a char in row 0 so we can detect scrolling
    cpu.vga_buffer[0] = 0x0741; // 'A'

    cpu.vgaPutChar(0x0A);
    // Cursor row should be 24 (not 25, since scrolled)
    try std.testing.expectEqual(@as(u16, 24), cpu.vga_cursor_row);
    // Row 0 should now contain row 1's content (which is 0x0720 space)
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[0]);
}

// Direct call to vgaScrollUp shifts all rows up by 1 and clears the last row.
test "VGA: scrollUp shifts rows" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741; // Row 0, col 0 = 'A'
    cpu.vga_buffer[80] = 0x0742; // Row 1, col 0 = 'B'
    cpu.vgaScrollUp();

    // After scroll: row 0 should have what was in row 1
    try std.testing.expectEqual(@as(u16, 0x0742), cpu.vga_buffer[0]);
    // Last row should be cleared
    const last_start: usize = 24 * 80;
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[last_start]);
}

// vgaControl with 0x0001 clears the VGA buffer and resets cursor.
test "VGA: control clear" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741; // 'A'
    cpu.vga_buffer[100] = 0x0742; // some 'B' further in
    cpu.vga_cursor_row = 10;
    cpu.vga_cursor_col = 20;
    cpu.vgaControl(0x0001);

    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[0]);
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[100]);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
}

// vgaControl with 0x0002 sets dirty flag.
test "VGA: control flush sets dirty" {
    var cpu = CPU{};
    cpu.vga_dirty = false;
    cpu.vgaControl(0x0002);

    try std.testing.expectEqual(true, cpu.vga_dirty);
}

// VGA memory-mapped window at 0xE000: write to VGA buffer via writeWord.
test "VGA: memory-mapped write at 0xE000" {
    var cpu = CPU{};
    cpu.writeWord(0xE000, 0x0741); // 'A' with attr 0x07 at word 0
    try std.testing.expectEqual(@as(u16, 0x0741), cpu.vga_buffer[0]);
    try std.testing.expectEqual(true, cpu.vga_dirty);
}

// VGA memory-mapped window: read back from VGA buffer via readWord.
test "VGA: memory-mapped read at 0xE000" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741;
    const val = cpu.readWord(0xE000);
    try std.testing.expectEqual(@as(u16, 0x0741), val);
}

// VGA memory-mapped window: multiple words at different offsets.
test "VGA: memory-mapped write at offset 0x004" {
    var cpu = CPU{};
    cpu.writeWord(0xE004, 0x0742); // 'B' with attr 0x07 at word 2
    try std.testing.expectEqual(@as(u16, 0x0742), cpu.vga_buffer[2]);
}

// VGA memory-mapped window: last word (0xEF9E = 1999 words × 2).
test "VGA: memory-mapped last word" {
    var cpu = CPU{};
    cpu.writeWord(0xEF9E, 0x0758);
    try std.testing.expectEqual(@as(u16, 0x0758), cpu.vga_buffer[1999]);
}

// VGA memory-mapped window: RAM below 0xE000 is unaffected.
test "VGA: memory writes below window reach RAM" {
    var cpu = CPU{};
    cpu.writeWord(0xDFFE, 0x1234);
    try std.testing.expectEqual(@as(u8, 0x34), cpu.memory[0xDFFE]);
    try std.testing.expectEqual(@as(u8, 0x12), cpu.memory[0xDFFF]);
}

// VGA memory-mapped window: RAM above window still accessible.
test "VGA: memory writes above window reach RAM" {
    var cpu = CPU{};
    cpu.writeWord(0xEFA0, 0x5678);
    try std.testing.expectEqual(@as(u8, 0x78), cpu.memory[0xEFA0]);
    try std.testing.expectEqual(@as(u8, 0x56), cpu.memory[0xEFA1]);
}

// vgaPutChar mirrors every character to the UART TX buffer.
test "VGA: putChar UART mirror" {
    var cpu = CPU{};
    cpu.vgaPutChar('A');

    try std.testing.expectEqual(@as(u8, 'A'), cpu.uart_tx[0]);
    try std.testing.expectEqual(@as(u8, 1), cpu.uart_tx_head);
}

// vgaPutChar CR also mirrors to UART.
test "VGA: putChar CR mirrors to UART" {
    var cpu = CPU{};
    cpu.vgaPutChar(0x0D);

    try std.testing.expectEqual(@as(u8, 0x0D), cpu.uart_tx[0]);
}

// vgaPutChar LF also mirrors to UART.
test "VGA: putChar LF mirrors to UART" {
    var cpu = CPU{};
    cpu.vgaPutChar(0x0A);

    try std.testing.expectEqual(@as(u8, 0x0A), cpu.uart_tx[0]);
}

// =============================================================================
// Line Buffer Tests — putKey / parseCommand / cmd_id / ports 0x03/0x04
// =============================================================================

// putKey with a printable character adds it to the line buffer and echoes to VGA.
test "putKey: printable char goes to line_buf" {
    var cpu = CPU{};
    cpu.putKey('A');

    try std.testing.expectEqual(@as(u8, 'A'), cpu.line_buf[0]);
    try std.testing.expectEqual(@as(u8, 1), cpu.line_len);
    // VGA should also have 'A' at (0,0)
    try std.testing.expectEqual(@as(u16, 0x0741), cpu.vga_buffer[0]);
}

// putKey with multiple characters accumulates in the line buffer.
test "putKey: multiple chars accumulate" {
    var cpu = CPU{};
    cpu.putKey('h');
    cpu.putKey('e');
    cpu.putKey('l');
    cpu.putKey('p');

    try std.testing.expectEqual(@as(u8, 4), cpu.line_len);
    try std.testing.expectEqual(@as(u8, 'h'), cpu.line_buf[0]);
    try std.testing.expectEqual(@as(u8, 'e'), cpu.line_buf[1]);
    try std.testing.expectEqual(@as(u8, 'l'), cpu.line_buf[2]);
    try std.testing.expectEqual(@as(u8, 'p'), cpu.line_buf[3]);
}

// putKey with Backspace removes the last character from the line buffer.
test "putKey: Backspace removes last char" {
    var cpu = CPU{};
    cpu.putKey('A');
    cpu.putKey('B');
    cpu.putKey('C');
    try std.testing.expectEqual(@as(u8, 3), cpu.line_len);

    cpu.putKey(0x08); // Backspace
    try std.testing.expectEqual(@as(u8, 2), cpu.line_len);
    try std.testing.expectEqual(@as(u8, 'A'), cpu.line_buf[0]);
    try std.testing.expectEqual(@as(u8, 'B'), cpu.line_buf[1]);
}

// putKey Backspace on an empty buffer is a no-op.
test "putKey: Backspace on empty is no-op" {
    var cpu = CPU{};
    cpu.putKey(0x08);
    try std.testing.expectEqual(@as(u8, 0), cpu.line_len);
}

// putKey with Enter (0x0D) calls parseCommand and sets cmd_id, then clears the buffer.
test "putKey: Enter sets cmd_id and clears buffer" {
    var cpu = CPU{};
    cpu.putKey('h');
    cpu.putKey('e');
    cpu.putKey('l');
    cpu.putKey('p');
    cpu.putKey(0x0D); // Enter

    try std.testing.expectEqual(@as(u8, 1), cpu.cmd_id); // help=1
    try std.testing.expectEqual(@as(u8, 0), cpu.line_len); // buffer cleared
    try std.testing.expectEqual(@as(u8, 0), cpu.line_buf[0]); // zeroed
}

// putKey with Enter on empty line sets cmd_id=7 (unknown → kernel re-prompts).
test "putKey: Enter on empty sets cmd_id=7" {
    var cpu = CPU{};
    cpu.putKey(0x0D);

    try std.testing.expectEqual(@as(u8, 7), cpu.cmd_id);
}

// parseCommand sets cmd_id=1 for "help".
test "parseCommand: help" {
    var cpu = CPU{};
    cpu.line_buf[0..4].* = .{ 'h', 'e', 'l', 'p' };
    cpu.line_len = 4;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 1), cpu.cmd_id);
}

// parseCommand sets cmd_id=2 for "clear".
test "parseCommand: clear" {
    var cpu = CPU{};
    cpu.line_buf[0..5].* = .{ 'c', 'l', 'e', 'a', 'r' };
    cpu.line_len = 5;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 2), cpu.cmd_id);
}

// parseCommand sets cmd_id=3 for "reboot".
test "parseCommand: reboot" {
    var cpu = CPU{};
    cpu.line_buf[0..6].* = .{ 'r', 'e', 'b', 'o', 'o', 't' };
    cpu.line_len = 6;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 3), cpu.cmd_id);
}

// parseCommand sets cmd_id=4 for "info".
test "parseCommand: info" {
    var cpu = CPU{};
    cpu.line_buf[0..4].* = .{ 'i', 'n', 'f', 'o' };
    cpu.line_len = 4;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 4), cpu.cmd_id);
}

// parseCommand sets cmd_id=5 for "dump".
test "parseCommand: dump" {
    var cpu = CPU{};
    cpu.line_buf[0..4].* = .{ 'd', 'u', 'm', 'p' };
    cpu.line_len = 4;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 5), cpu.cmd_id);
}

// parseCommand sets cmd_id=6 for "halt".
test "parseCommand: halt" {
    var cpu = CPU{};
    cpu.line_buf[0..4].* = .{ 'h', 'a', 'l', 't' };
    cpu.line_len = 4;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 6), cpu.cmd_id);
}

// parseCommand with empty line sets cmd_id=7 (unknown / re-prompt).
test "parseCommand: empty returns 7" {
    var cpu = CPU{};
    cpu.line_len = 0;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 7), cpu.cmd_id);
}

// parseCommand with unknown string sets cmd_id=7.
test "parseCommand: unknown command returns 7" {
    var cpu = CPU{};
    cpu.line_buf[0..3].* = .{ 'f', 'o', 'o' };
    cpu.line_len = 3;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 7), cpu.cmd_id);
}

// parseCommand with leading spaces still matches correctly.
test "parseCommand: leading spaces" {
    var cpu = CPU{};
    cpu.line_buf[0..6].* = .{ ' ', ' ', 'h', 'e', 'l', 'p' };
    cpu.line_len = 6;
    cpu.parseCommand();

    try std.testing.expectEqual(@as(u8, 1), cpu.cmd_id);
}

// Reading port 0x03 returns the current cmd_id and clears it.
test "Port 0x03: returns cmd_id and clears" {
    var cpu = CPU{};
    cpu.cmd_id = 5; // dump

    const id = cpu.readPort(0x03);
    try std.testing.expectEqual(@as(u16, 5), id);
    try std.testing.expectEqual(@as(u8, 0), cpu.cmd_id); // cleared after read
}

// Port 0x03 returns 0 when no command is pending.
test "Port 0x03: returns 0 when idle" {
    var cpu = CPU{};
    const id = cpu.readPort(0x03);
    try std.testing.expectEqual(@as(u16, 0), id);
}

// Reading port 0x04 returns bytes from the line buffer, one at a time.
test "Port 0x04: reads line buffer bytes" {
    var cpu = CPU{};
    cpu.line_buf[0] = 'h';
    cpu.line_buf[1] = 'i';
    cpu.line_len = 2;
    cpu.line_read_pos = 0;

    try std.testing.expectEqual(@as(u16, 'h'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 'i'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x04)); // exhausted
}

// Port 0x04 returns 0 when the line buffer is empty.
test "Port 0x04: returns 0 when empty" {
    var cpu = CPU{};
    cpu.line_len = 0;
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x04));
}

// =============================================================================
// I/O Port Integration Tests — via IN/OUT instructions
// =============================================================================

// OUT 0x10 with a character writes to VGA via instruction.
test "I/O: OUT 0x10 writes to VGA" {
    var cpu = CPU{};
    cpu.ax = 'Z';
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0010));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x075A), cpu.vga_buffer[0]); // 'Z'
    try std.testing.expectEqual(@as(u16, 1), cpu.vga_cursor_col);
}

// OUT 0x11 with 0x0001 clears VGA via instruction.
test "I/O: OUT 0x11 clear screen" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741; // 'A'
    cpu.vga_cursor_row = 10;
    cpu.vga_cursor_col = 20;
    cpu.ax = 0x0001;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0011));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[0]);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
}

// IN from port 0x03 after putKey Enter returns the command ID.
test "I/O: IN 0x03 after command" {
    var cpu = CPU{};
    cpu.putKey('h');
    cpu.putKey('e');
    cpu.putKey('l');
    cpu.putKey('p');
    cpu.putKey(0x0D); // Enter → cmd_id=1

    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0003));
    try cpu.step();

    try std.testing.expectEqual(@as(u16, 1), cpu.ax);
    try std.testing.expectEqual(@as(u8, 0), cpu.cmd_id); // cleared on read
}

// IN from port 0x04 after typing returns the buffer contents.
test "I/O: IN 0x04 reads typed line" {
    var cpu = CPU{};
    cpu.putKey('d');
    cpu.putKey('u');
    cpu.putKey('m');
    cpu.putKey('p');

    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0004));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'd'), cpu.ax);

    writeInstruction32(&cpu.memory, 4, ISA.encode32(.IN, .AX, 0x0004));
    cpu.ip = 4;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'u'), cpu.ax);

    writeInstruction32(&cpu.memory, 8, ISA.encode32(.IN, .AX, 0x0004));
    cpu.ip = 8;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'm'), cpu.ax);

    writeInstruction32(&cpu.memory, 12, ISA.encode32(.IN, .AX, 0x0004));
    cpu.ip = 12;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'p'), cpu.ax);
}

// Full workflow: type "help" + Enter, read cmd_id from port 0x03, dispatch.
test "I/O: full command workflow" {
    var cpu = CPU{};

    // Type "help" + Enter
    cpu.putKey('h');
    cpu.putKey('e');
    cpu.putKey('l');
    cpu.putKey('p');
    cpu.putKey(0x0D);

    // Read cmd_id from port 0x03
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0003));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 1), cpu.ax); // help=1
    try std.testing.expectEqual(@as(u8, 0), cpu.cmd_id); // cleared
}

// =============================================================================
// JMP Tests
// =============================================================================

// JMP immediate (32-bit) — jump to target address
test "JMP immediate 32-bit" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.JMP, .AX, 0x0050));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0050), cpu.ip);
}

// JMP register (16-bit) — jump to address in register
test "JMP register 16-bit" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .BX, 0x0030));
    writeInstruction(&cpu.memory, 4, ISA.encode16(.JMP, .AX, .BX, .RegReg));
    try cpu.step(); // MOV BX, 0x0030
    try cpu.step(); // JMP BX
    try std.testing.expectEqual(@as(u16, 0x0030), cpu.ip);
}

// =============================================================================
// MOV Addressing Mode Tests (16-bit)
// =============================================================================

// MOV AX, [BX] (16-bit Indirect) — load from memory address in BX
test "MOV indirect 16-bit" {
    var cpu = CPU{};
    cpu.bx = 0x0100;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .BX, .Indirect));
    cpu.memory[0x0100] = 0xCD;
    cpu.memory[0x0101] = 0xAB;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
    try std.testing.expectEqual(@as(u16, 2), cpu.ip);
}

// MOV AX, [BX+0x0004] (16-bit IndirectOff) — load with offset
test "MOV indirect-offset 16-bit" {
    var cpu = CPU{};
    cpu.bx = 0x0100;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .BX, .IndirectOff));
    writeInstruction(&cpu.memory, 2, 0x0004);
    cpu.memory[0x0104] = 0x34;
    cpu.memory[0x0105] = 0x12;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
    try std.testing.expectEqual(@as(u16, 4), cpu.ip);
}

// MOV AX, 0x1234 (16-bit Imm)
test "MOV immediate 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x1234);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
    try std.testing.expectEqual(@as(u16, 4), cpu.ip);
}

// =============================================================================
// CALL/INT/IN/OUT 16-bit Format Tests
// =============================================================================

// CALL 0x0050 (16-bit) — push return address, jump
test "CALL 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encode16(.CALL, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x0050);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0050), cpu.ip);
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.popStack());
}

// INT 0x0002 (16-bit) — push flags and return address, jump to vector*4
test "INT 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encode16(.INT, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x0002);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0008), cpu.ip);
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.popStack());
}

// IN AX, 0x22 (16-bit)
test "IN 16-bit" {
    var cpu = CPU{};
    cpu.io_ports[0x22] = 0x1234;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.IN, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x0022);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
    try std.testing.expectEqual(@as(u16, 4), cpu.ip);
}

// OUT 0x22, AX (16-bit)
test "OUT 16-bit" {
    var cpu = CPU{};
    cpu.ax = 0x5678;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.OUT, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x0022);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x5678), cpu.io_ports[0x22]);
    try std.testing.expectEqual(@as(u16, 4), cpu.ip);
}

// =============================================================================
// TEST ALU Operation (flags only, no result stored)
// =============================================================================

test "TEST: zero result sets Z" {
    var cpu = CPU{};
    cpu.ax = 0x00FF;
    cpu.bx = 0xFF00;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.TEST, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax); // AX unchanged
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

test "TEST: non-zero result clears Z" {
    var cpu = CPU{};
    cpu.ax = 0x00FF;
    cpu.bx = 0x00FF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.TEST, .AX, .BX));
    try cpu.step();
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

test "TEST: sign flag from bit 15" {
    var cpu = CPU{};
    cpu.ax = 0x8000;
    cpu.bx = 0x8000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.TEST, .AX, .BX));
    try cpu.step();
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(cpu.getSign());
}

// =============================================================================
// SHL/SHR Carry Flag Tests
// =============================================================================

// SHL carry should be the last bit shifted out (bit 15 when shifting by 1)
test "SHL: carry from bit 15" {
    var cpu = CPU{};
    cpu.ax = 0x8001;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // bit 15 = 1
}

test "SHL: no carry when top bit is 0" {
    var cpu = CPU{};
    cpu.ax = 0x4000;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x8000), cpu.ax);
    try std.testing.expect(!cpu.getCarry()); // bit 15 was 0
}

// SHR carry should be the last bit shifted out (bit 0 when shifting by 1)
test "SHR: carry from bit 0" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // bit 0 = 1
}

test "SHR: carry from bit 7 when shifting by 8" {
    var cpu = CPU{};
    cpu.ax = 0xFF00;
    cpu.bx = 0x0008;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.ax);
    try std.testing.expect(!cpu.getCarry()); // bit 7 was 1, not bit 0
}

// =============================================================================
// PUSH/POP — all 4 registers
// =============================================================================

test "PUSH/POP all 4 registers" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0002;
    cpu.cx = 0x0003;
    cpu.dx = 0x0004;
    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.PUSH, .BX));
    writeInstruction(&cpu.memory, 4, ISA.encodePushPop(.PUSH, .CX));
    writeInstruction(&cpu.memory, 6, ISA.encodePushPop(.PUSH, .DX));
    writeInstruction(&cpu.memory, 8, ISA.encodePushPop(.POP, .DX));
    writeInstruction(&cpu.memory, 10, ISA.encodePushPop(.POP, .CX));
    writeInstruction(&cpu.memory, 12, ISA.encodePushPop(.POP, .BX));
    writeInstruction(&cpu.memory, 14, ISA.encodePushPop(.POP, .AX));

    try cpu.step(); try cpu.step(); try cpu.step(); try cpu.step();
    try cpu.step(); try cpu.step(); try cpu.step(); try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0001), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.bx);
    try std.testing.expectEqual(@as(u16, 0x0003), cpu.cx);
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.dx);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// System-level Tests
// =============================================================================

test "loadProgram: basic" {
    var cpu = CPU{};
    const program = [_]u8{ 0x00, 0x70 };
    cpu.loadProgram(&program, 0x0100);
    try std.testing.expectEqual(@as(u8, 0x00), cpu.memory[0x0100]);
    try std.testing.expectEqual(@as(u8, 0x70), cpu.memory[0x0101]);
}

test "loadProgram: wraps at 64K boundary" {
    var cpu = CPU{};
    var large: [100]u8 = undefined;
    for (&large, 0..) |*b, i| b.* = @intCast(i & 0xFF);
    cpu.loadProgram(&large, 0xFFC0);
    try std.testing.expectEqual(@as(u8, 0x00), cpu.memory[0xFFC0]);
    try std.testing.expectEqual(@as(u8, 0x3F), cpu.memory[0xFFFF]);
    try std.testing.expectEqual(@as(u8, 0x40), cpu.memory[0x0000]);
}

test "readWord wraps at 0xFFFF" {
    var cpu = CPU{};
    cpu.memory[0xFFFF] = 0x34;
    cpu.memory[0x0000] = 0x12;
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.readWord(0xFFFF));
}

test "writeWord wraps at 0xFFFF" {
    var cpu = CPU{};
    cpu.writeWord(0xFFFF, 0x1234);
    try std.testing.expectEqual(@as(u8, 0x34), cpu.memory[0xFFFF]);
    try std.testing.expectEqual(@as(u8, 0x12), cpu.memory[0x0000]);
}

test "pushStack/popStack direct" {
    var cpu = CPU{};
    cpu.pushStack(0xABCD);
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.readWord(0xFFFC));
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.popStack());
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// Edge Cases — Stack Overflow/Underflow
// =============================================================================

test "PUSH wraps SP from 0x0000 to 0xFFFE (full wrap)" {
    var cpu = CPU{};
    cpu.sp = 0x0000;
    cpu.ax = 0xBEEF;

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    // SP = 0x0000 - 2 = 0xFFFE (wraps around u16)
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0xBEEF), cpu.readWord(0xFFFE));
}

test "POP wraps SP from 0xFFFE to 0x0000 (stack underflow)" {
    var cpu = CPU{};
    // Manually set SP to 0xFFFE with data at 0xFFFE, then POP
    // POP reads [SP] then SP += 2, so SP goes 0xFFFE → 0x0000
    cpu.sp = 0xFFFE;
    cpu.memory[0xFFFE] = 0x34;
    cpu.memory[0xFFFF] = 0x12;

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.POP, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.sp);
}

// =============================================================================
// Edge Cases — Nested CALL/RET
// =============================================================================

test "nested CALL/RET: two levels" {
    var cpu = CPU{};
    cpu.sp = 0xFFFE;

    // addr 0x0000: CALL func1 → pushes 0x0004, jumps to 0x0020
    writeInstruction32(&cpu.memory, 0x0000, ISA.encode32(.CALL, .AX, 0x0020));
    // addr 0x0004: HLT (return here after both CALLs)
    writeInstruction(&cpu.memory, 0x0004, 0x7000);

    // addr 0x0020: func1 — CALL func2 → pushes 0x0024, jumps to 0x0040
    writeInstruction32(&cpu.memory, 0x0020, ISA.encode32(.CALL, .AX, 0x0040));
    // addr 0x0024: RET (return to 0x0004)
    // NOP guard after RET to prevent raw32 lookahead misidentification
    writeInstruction(&cpu.memory, 0x0024, 0x4000);
    writeInstruction(&cpu.memory, 0x0026, 0x0000); // NOP guard

    // addr 0x0040: func2 — MOV AX, 0x1111, RET (return to 0x0024)
    // Using 0x1111 instead of 0xAAAA because 0xAAAA's lo16 has 0xA in bits 15:12,
    // which triggers the is_16bit_alu misidentification guard.
    writeInstruction32(&cpu.memory, 0x0040, ISA.encode32(.MOV, .AX, 0x1111));
    writeInstruction(&cpu.memory, 0x0044, 0x4000);
    writeInstruction(&cpu.memory, 0x0046, 0x0000); // NOP guard

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1111), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp); // stack fully restored
}

test "nested CALL/RET: three levels" {
    var cpu = CPU{};
    cpu.sp = 0xFFFE;

    // Level 0: CALL level1 at 0x0030
    writeInstruction32(&cpu.memory, 0x0000, ISA.encode32(.CALL, .AX, 0x0030));
    writeInstruction32(&cpu.memory, 0x0004, ISA.encode32(.MOV, .AX, 0x0001)); // after all returns
    writeInstruction(&cpu.memory, 0x0008, 0x7000);

    // Level 1 at 0x0030: CALL level2, then MOV BX, 0x0002, RET
    writeInstruction32(&cpu.memory, 0x0030, ISA.encode32(.CALL, .AX, 0x0050));
    writeInstruction32(&cpu.memory, 0x0034, ISA.encode32(.MOV, .BX, 0x0002));
    writeInstruction(&cpu.memory, 0x0038, 0x4000);
    writeInstruction(&cpu.memory, 0x003A, 0x0000); // NOP guard

    // Level 2 at 0x0050: MOV CX, 0x0003, RET
    writeInstruction32(&cpu.memory, 0x0050, ISA.encode32(.MOV, .CX, 0x0003));
    writeInstruction(&cpu.memory, 0x0054, 0x4000);
    writeInstruction(&cpu.memory, 0x0056, 0x0000); // NOP guard

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0001), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.bx);
    try std.testing.expectEqual(@as(u16, 0x0003), cpu.cx);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// Edge Cases — ADD overflow / extreme values
// =============================================================================

test "ADD 0xFFFF + 0xFFFF = 0xFFFE, C=1" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0xFFFF));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // 0x1FFFE → carry out
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(cpu.getSign()); // bit 15 set
}

test "ADD 0 + 0 = 0, Z=1 C=0 S=0" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0000));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

// =============================================================================
// Edge Cases — SUB extreme values
// =============================================================================

test "SUB 0x0001 - 0xFFFF = 0x0002, C=1 (borrow)" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0xFFFF));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0002), cpu.ax); // 0x10001 - 0xFFFF = 0x2
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(!cpu.getSign()); // result is positive
}

test "SUB 0x8000 - 0x0001 = 0x7FFF, no borrow" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x8000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x7FFF), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign()); // bit 15 clear
}

// =============================================================================
// Edge Cases — SHL/SHR count masking (count is u4, so 0-15 only)
// =============================================================================

test "SHL by 16 masked to 0 — no change" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0010)); // 16, masked to 0
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax); // unchanged
}

test "SHR by 16 masked to 0 — no change" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0010));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

test "SHL 0xFFFF by 1 = 0xFFFE, carry=1" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // bit 15 shifted out
}

test "SHR 0x0001 by 1 = 0x0000, carry=1" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x0001));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x0001));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry()); // bit 0 shifted out
}

// =============================================================================
// Edge Cases — MOV indirect memory wrapping
// =============================================================================

test "MOV [BX] reads across 0xFFFF wrap" {
    var cpu = CPU{};
    cpu.bx = 0xFFFF;
    cpu.memory[0xFFFF] = 0xCD;
    cpu.memory[0x0000] = 0xAB; // wraps around

    writeInstruction(&cpu.memory, 0x0010, ISA.encode16(.MOV, .AX, .BX, .Indirect));
    cpu.ip = 0x0010;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

// =============================================================================
// Edge Cases — Timer counting across multiple steps
// =============================================================================

test "Timer: increments each step" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, 0x0000); // NOP
    writeInstruction(&cpu.memory, 2, 0x0000); // NOP
    writeInstruction(&cpu.memory, 4, 0x7000); // HLT

    const cycles = try cpu.run(100);
    try std.testing.expectEqual(@as(u32, 3), cpu.cycle_count);
    try std.testing.expect(cycles == 3);
}

// =============================================================================
// Edge Cases — INC/DEC wrapping
// =============================================================================

test "INC 0xFFFF wraps to 0x0000, Z=1" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.INC, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry()); // INC doesn't affect carry
}

test "DEC 0x0000 wraps to 0xFFFF, S=1" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.DEC, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getSign()); // bit 15 set
    try std.testing.expect(!cpu.getCarry()); // DEC doesn't affect carry
}

// =============================================================================
// Edge Cases — SUB equal large values
// =============================================================================

test "SUB 0xFFFF - 0xFFFF = 0, Z=1 C=0" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0xFFFF));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0xFFFF));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.SUB, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

// =============================================================================
// Edge Cases — NOT/NEG on boundary values
// =============================================================================

test "NOT 0x0001 = 0xFFFE" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NOT, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.ax);
}

test "NEG 0x7FFF = 0x8001" {
    var cpu = CPU{};
    cpu.ax = 0x7FFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NEG, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x8001), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getSign());
}

// =============================================================================
// Edge Cases — AND/OR/XOR boundary values
// =============================================================================

test "AND 0xFFFF & 0xFFFF = 0xFFFF, S=1" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0xFFFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.AND, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(cpu.getSign());
}

test "OR 0x0000 | 0x0000 = 0, Z=1" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.OR, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

test "XOR 0xFFFF & 0x0000 = 0xFFFF, S=1" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getSign());
}

// =============================================================================
// Edge Cases — CMP boundary comparisons
// =============================================================================

test "CMP 0x0000 vs 0x0000 — equal, Z=1 C=0 S=0" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.CMP, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax); // CMP doesn't modify
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

test "CMP 0xFFFF vs 0x0001 — greater, Z=0 C=0 S=1" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.CMP, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    // 0xFFFF - 0x0001 = 0xFFFE → S=1, Z=0, C=0
    try std.testing.expect(!cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(cpu.getSign());
}

// =============================================================================
// Edge Cases — Nested INT/IRET
// =============================================================================

test "INT/IRET: nested interrupts" {
    var cpu = CPU{};
    cpu.sp = 0xFFFE;

    // addr 0x0000: INT 0x0001 → jumps to ISR1 at 0x0004
    writeInstruction32(&cpu.memory, 0x0000, ISA.encode32(.INT, .AX, 0x0001));
    // addr 0x0004: after INT return → HLT
    writeInstruction(&cpu.memory, 0x0004, 0x7000);

    // ISR1 at 0x0004*1=0x0004... wait, vector 1 → 1*4 = 0x0004
    // That's the return address too. Let me use vector 2 instead.
    // INT 0x0002 → jumps to 0x0008
    writeInstruction32(&cpu.memory, 0x0000, ISA.encode32(.INT, .AX, 0x0002));

    // ISR at 0x0008: MOV AX, 0x1111, IRET
    writeInstruction32(&cpu.memory, 0x0008, ISA.encode32(.MOV, .AX, 0x1111));
    writeInstruction(&cpu.memory, 0x000C, 0x6000); // IRET

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1111), cpu.ax);
    // After IRET: flags restored, IP restored, SP back to 0xFFFE
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip); // returned to IP after INT
}

test "INT preserves FLAGS through IRET" {
    var cpu = CPU{};
    cpu.flags = CPU.CARRY_FLAG; // Set carry before INT
    cpu.sp = 0xFFFE;

    // INT 0x0003 → ISR at 0x000C
    writeInstruction32(&cpu.memory, 0x0000, ISA.encode32(.INT, .AX, 0x0003));
    writeInstruction(&cpu.memory, 0x0004, 0x7000); // HLT after IRET

    // ISR at 0x000C: clear flags, then IRET (should restore original flags)
    writeInstruction32(&cpu.memory, 0x000C, ISA.encode32(.MOV, .AX, 0x0000));
    writeInstruction(&cpu.memory, 0x0010, ISA.encodeAlu(.XOR, .AX, .AX)); // clears flags
    writeInstruction(&cpu.memory, 0x0012, 0x6000); // IRET

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    // Flags should be restored to CARRY_FLAG (0x02)
    try std.testing.expectEqual(@as(u16, CPU.CARRY_FLAG), cpu.flags);
}

// =============================================================================
// Edge Cases — SHL/SHR all-ones / all-zeros
// =============================================================================

test "SHL 0x0000 by 1 = 0x0000, no carry" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

test "SHR 0x0000 by 1 = 0x0000, no carry" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
}

// =============================================================================
// Edge Cases — run() max_cycles limit
// =============================================================================

test "run: respects max_cycles limit" {
    var cpu = CPU{};
    // NOPs forever — should stop at max_cycles
    writeInstruction(&cpu.memory, 0, 0x0000);
    writeInstruction(&cpu.memory, 2, 0x0000);
    writeInstruction(&cpu.memory, 4, 0x0000);
    writeInstruction(&cpu.memory, 6, 0x7000); // HLT

    const cycles = try cpu.run(2);
    try std.testing.expectEqual(@as(u32, 2), cycles);
    try std.testing.expect(!cpu.halted); // HLT wasn't reached
}

test "run: stops early on HLT" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, 0x7000); // HLT immediately

    const cycles = try cpu.run(1000);
    try std.testing.expectEqual(@as(u32, 1), cycles);
    try std.testing.expect(cpu.halted);
}

// =============================================================================
// Edge Cases — TEST boundary values
// =============================================================================

test "TEST 0x0000 & 0xFFFF = 0, Z=1" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    cpu.bx = 0xFFFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.TEST, .AX, .BX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax); // TEST doesn't modify
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(!cpu.getSign());
}

// =============================================================================
// Edge Cases — VGA backspace at row 0, col 0 (no-op)
// =============================================================================

test "VGA: backspace at row 0 col 0 is no-op" {
    var cpu = CPU{};
    cpu.vga_cursor_row = 0;
    cpu.vga_cursor_col = 0;

    cpu.vgaPutChar(0x08); // Backspace
    // Should not go negative — cursor stays at (0,0)
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_col);
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[0]); // cell cleared
}

// =============================================================================
// Edge Cases — UART buffer circular wrap
// =============================================================================

test "UART: TX buffer wraps around 256" {
    var cpu = CPU{};
    cpu.uart_tx_head = 255;
    cpu.uart_tx[255] = 'X';

    cpu.uartWriteData('Y');
    try std.testing.expectEqual(@as(u8, 'Y'), cpu.uart_tx[255]); // written at head=255
    try std.testing.expectEqual(@as(u8, 0), cpu.uart_tx_head); // head wrapped to 0
}

test "UART: RX buffer wraps around 256" {
    var cpu = CPU{};
    // Simulate: wrote one byte at index 255, then head wrapped past 255 to 0
    cpu.uart_rx_head = 0;  // wrapped around
    cpu.uart_rx_tail = 255; // last byte at index 255
    cpu.uart_rx[255] = 'A';

    const val = cpu.readPort(0x00);
    try std.testing.expectEqual(@as(u16, 'A'), val);
    try std.testing.expectEqual(@as(u8, 0), cpu.uart_rx_tail); // tail wrapped to 0
}

// =============================================================================
// Edge Cases — Key buffer circular wrap
// =============================================================================

test "Keyboard: buffer wraps around 256" {
    var cpu = CPU{};
    // Simulate: wrote one byte at index 255, then head wrapped past 255 to 0
    cpu.kbd_buffer[255] = 0x42;
    cpu.kbd_tail = 255;
    cpu.kbd_head = 0; // wrapped — one byte available at index 255

    try std.testing.expect(cpu.hasKey());
    const val = cpu.readPort(0x02);
    try std.testing.expectEqual(@as(u16, 0x42), val);
    try std.testing.expectEqual(@as(u8, 0), cpu.kbd_tail); // tail wrapped to 0
}

// =============================================================================
// Edge Cases — Line buffer full (127 chars max)
// =============================================================================

test "putKey: line buffer max length" {
    var cpu = CPU{};
    // Fill to 127 chars
    for (0..127) |_| {
        cpu.putKey('A');
    }
    try std.testing.expectEqual(@as(u8, 127), cpu.line_len);

    // 128th char should be rejected
    cpu.putKey('B');
    try std.testing.expectEqual(@as(u8, 127), cpu.line_len);
    try std.testing.expectEqual(@as(u8, 'A'), cpu.line_buf[126]); // last is still 'A'
}

// =============================================================================
// Edge Cases — MOV self (AX = AX)
// =============================================================================

test "MOV AX, AX — no change" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .RegReg));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

// =============================================================================
// Edge Cases — XOR self clears register
// =============================================================================

test "XOR reg, same_reg = 0, Z=1" {
    var cpu = CPU{};
    cpu.ax = 0xABCD;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

// =============================================================================
// Edge Cases — AND self = identity
// =============================================================================

test "AND reg, same_reg = unchanged" {
    var cpu = CPU{};
    cpu.ax = 0xABCD;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.AND, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

// =============================================================================
// Edge Cases — OR self = identity
// =============================================================================

test "OR reg, same_reg = unchanged" {
    var cpu = CPU{};
    cpu.ax = 0xABCD;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.OR, .AX, .AX));
    writeInstruction(&cpu.memory, 2, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

// =============================================================================
// Edge Cases — PUSH then immediate POP (LIFO order)
// =============================================================================

test "PUSH AX, PUSH BX, POP BX, POP AX — LIFO order preserved" {
    var cpu = CPU{};
    cpu.ax = 0xAAAA;
    cpu.bx = 0xBBBB;

    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .AX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.PUSH, .BX));
    _ = try cpu.step();

    // Pop into different registers to verify order
    writeInstruction(&cpu.memory, 4, ISA.encodePushPop(.POP, .CX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 6, ISA.encodePushPop(.POP, .DX));
    _ = try cpu.step();

    try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.cx); // BX was pushed last
    try std.testing.expectEqual(@as(u16, 0xAAAA), cpu.dx); // AX was pushed first
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// Edge Cases — Multiple flags set simultaneously
// =============================================================================

test "ADD 0x8000 + 0x8000 = 0x0000, Z=1 C=1 S=0" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .AX, 0x8000));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.MOV, .BX, 0x8000));
    writeInstruction(&cpu.memory, 8, ISA.encodeAlu(.ADD, .AX, .BX));
    writeInstruction(&cpu.memory, 10, 0x7000);

    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero()); // result is 0
    try std.testing.expect(cpu.getCarry()); // 0x10000 overflow
    try std.testing.expect(!cpu.getSign()); // result bit 15 is 0
}

test "run: max_cycles timeout" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, 0x0000);
    const cycles = try cpu.run(10);
    try std.testing.expectEqual(@as(u32, 10), cycles);
    try std.testing.expectEqual(false, cpu.halted);
}

test "reset clears all state" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.bx = 0x5678;
    cpu.cx = 0x9ABC;
    cpu.dx = 0xDEF0;
    cpu.ip = 0x0100;
    cpu.sp = 0xFF00;
    cpu.flags = 0x07;
    cpu.halted = true;
    cpu.reset();
    try std.testing.expectEqual(@as(u16, 0), cpu.ax);
    try std.testing.expectEqual(@as(u16, 0), cpu.bx);
    try std.testing.expectEqual(@as(u16, 0), cpu.cx);
    try std.testing.expectEqual(@as(u16, 0), cpu.dx);
    try std.testing.expectEqual(@as(u16, 0), cpu.ip);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0), cpu.flags);
    try std.testing.expectEqual(false, cpu.halted);
}

// =============================================================================
// ALU Additional Edge Cases
// =============================================================================

test "ADD 0xFFFF + 0x0001 step" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADD, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getZero());
}

test "SUB 0 - 0 step" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SUB, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
}

test "AND 0xFFFF & 0xFFFF" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    cpu.bx = 0xFFFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.AND, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(!cpu.getZero());
}

test "OR value with zero" {
    var cpu = CPU{};
    cpu.ax = 0xABCD;
    cpu.bx = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.OR, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

test "XOR with zero" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.bx = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

test "XOR with self step" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
}

test "SHL 0x8000 by 1 — carry and overflow" {
    var cpu = CPU{};
    cpu.ax = 0x8000;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry());
}

test "SHR 0x0001 by 1 — carry and zero" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getZero());
}

test "SHL by 0x10 — masked to 0" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    cpu.bx = 0x0010;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
}

test "SHL by 0x1F — masked to 15" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    cpu.bx = 0x001F;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x8000), cpu.ax);
}

test "INC 0xFFFF step" {
    var cpu = CPU{};
    cpu.ax = 0xFFFF;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.INC, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(cpu.getZero());
}

test "DEC 0x0000 step" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.DEC, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(!cpu.getCarry());
    try std.testing.expect(cpu.getSign());
}

test "NEG 0 — zero and no carry" {
    var cpu = CPU{};
    cpu.ax = 0x0000;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NEG, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    try std.testing.expect(cpu.getZero());
    try std.testing.expect(!cpu.getCarry());
}

test "NEG 1 — flags" {
    var cpu = CPU{};
    cpu.ax = 0x0001;
    writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NEG, .AX, .AX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
    try std.testing.expect(cpu.getCarry());
    try std.testing.expect(cpu.getSign());
    try std.testing.expect(!cpu.getZero());
}

// =============================================================================
// MOV Additional Tests (16-bit and 32-bit)
// =============================================================================

test "MOV BX 32-bit imm" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .BX, 0x1234));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.bx);
}

test "MOV CX 32-bit imm" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .CX, 0xABCD));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.cx);
}

test "MOV DX 32-bit imm" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .DX, 0xFFFF));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.dx);
}

test "MOV AX→CX 16-bit" {
    var cpu = CPU{};
    cpu.ax = 0x5678;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .CX, .AX, .RegReg));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x5678), cpu.cx);
}

test "MOV BX→DX 16-bit" {
    var cpu = CPU{};
    cpu.bx = 0x9ABC;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .DX, .BX, .RegReg));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x9ABC), cpu.dx);
}

test "MOV indirect [CX] 16-bit" {
    var cpu = CPU{};
    cpu.cx = 0x0200;
    cpu.memory[0x0200] = 0xCD;
    cpu.memory[0x0201] = 0xAB;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .CX, .Indirect));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

test "MOV indirect-offset [CX+off] 16-bit" {
    var cpu = CPU{};
    cpu.cx = 0x0100;
    writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .CX, .IndirectOff));
    writeInstruction(&cpu.memory, 2, 0x0006);
    cpu.memory[0x0106] = 0x78;
    cpu.memory[0x0107] = 0x56;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x5678), cpu.ax);
}

// =============================================================================
// 16-bit CondJump — All Conditions (taken and not taken)
// =============================================================================

fn condWord16(cond: ISA.CondJump) u16 {
    return (@as(u16, @intFromEnum(ISA.Opcode.CondJump)) << 12) |
        (@as(u16, @intFromEnum(cond)) << 8) |
        (@as(u16, @intFromEnum(ISA.AddrMode.Imm)) << 6);
}

test "JNZ taken 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, condWord16(.JNZ));
    writeInstruction(&cpu.memory, 2, 0x0020);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0020), cpu.ip);
}

test "JNZ not taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.ZERO_FLAG;
    writeInstruction(&cpu.memory, 0, condWord16(.JNZ));
    writeInstruction(&cpu.memory, 2, 0x0020);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

test "JC taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.CARRY_FLAG;
    writeInstruction(&cpu.memory, 0, condWord16(.JC));
    writeInstruction(&cpu.memory, 2, 0x0030);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0030), cpu.ip);
}

test "JC not taken 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, condWord16(.JC));
    writeInstruction(&cpu.memory, 2, 0x0030);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

test "JNC taken 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, condWord16(.JNC));
    writeInstruction(&cpu.memory, 2, 0x0040);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0040), cpu.ip);
}

test "JNC not taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.CARRY_FLAG;
    writeInstruction(&cpu.memory, 0, condWord16(.JNC));
    writeInstruction(&cpu.memory, 2, 0x0040);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

test "JS taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.SIGN_FLAG;
    writeInstruction(&cpu.memory, 0, condWord16(.JS));
    writeInstruction(&cpu.memory, 2, 0x0050);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0050), cpu.ip);
}

test "JS not taken 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, condWord16(.JS));
    writeInstruction(&cpu.memory, 2, 0x0050);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

test "JNS taken 16-bit" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, condWord16(.JNS));
    writeInstruction(&cpu.memory, 2, 0x0060);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0060), cpu.ip);
}

test "JNS not taken 16-bit" {
    var cpu = CPU{};
    cpu.flags |= CPU.SIGN_FLAG;
    writeInstruction(&cpu.memory, 0, condWord16(.JNS));
    writeInstruction(&cpu.memory, 2, 0x0060);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.ip);
}

// =============================================================================
// CondJump 16-bit — Comprehensive flag-based test (all 6 conditions)
// =============================================================================

test "CondJump 16-bit all conditions taken/not-taken" {
    var cpu = CPU{};

    // === JZ taken (Z=1 via SUB AX, AX) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SUB, .AX, .AX));
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, 0x0000);
        writeInstruction(&cpu.memory, 6, condWord16(.JZ));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JZ not taken (Z=0 from reset) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, 0x0000);
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, 0x0000);
        writeInstruction(&cpu.memory, 6, condWord16(.JZ));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }

    // === JNZ taken (Z=0 via MOV 2 + ADD) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 2, 0x0002);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.ADD, .AX, .AX));
        writeInstruction(&cpu.memory, 6, condWord16(.JNZ));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JNZ not taken (Z=1 via SUB AX, AX; 3rd slot = SUB AX,BX to avoid hi_mode=01 bug) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SUB, .AX, .AX));
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.SUB, .AX, .BX));
        writeInstruction(&cpu.memory, 6, condWord16(.JNZ));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }

    // === JC taken (C=1 via MOV 0xFFFF + ADD) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 2, 0xFFFF);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.ADD, .AX, .AX));
        writeInstruction(&cpu.memory, 6, condWord16(.JC));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JC not taken (C=0 from reset) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, 0x0000);
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, 0x0000);
        writeInstruction(&cpu.memory, 6, condWord16(.JC));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }

    // === JNC taken (C=0 from reset) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, 0x0000);
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, 0x0000);
        writeInstruction(&cpu.memory, 6, condWord16(.JNC));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JNC not taken (C=1 via MOV+ADD) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 2, 0xFFFF);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.ADD, .AX, .AX));
        writeInstruction(&cpu.memory, 6, condWord16(.JNC));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }

    // === JS taken (S=1 via MOV 0xFFFF + ADD → result=0xFFFE) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 2, 0xFFFF);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.ADD, .AX, .AX));
        writeInstruction(&cpu.memory, 6, condWord16(.JS));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JS not taken (S=0 from reset) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, 0x0000);
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, 0x0000);
        writeInstruction(&cpu.memory, 6, condWord16(.JS));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }

    // === JNS taken (S=0 from reset; 3rd slot = SUB AX,BX to avoid hi_mode=01 bug) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, 0x0000);
        writeInstruction(&cpu.memory, 2, 0x0000);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.SUB, .AX, .BX));
        writeInstruction(&cpu.memory, 6, condWord16(.JNS));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xBBBB), cpu.ax);
    }

    // === JNS not taken (S=1 via MOV+ADD) ===
    {
        cpu.reset();
        writeInstruction(&cpu.memory, 0, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 2, 0xFFFF);
        writeInstruction(&cpu.memory, 4, ISA.encodeAlu(.ADD, .AX, .AX));
        writeInstruction(&cpu.memory, 6, condWord16(.JNS));
        writeInstruction(&cpu.memory, 8, 0x0010);
        writeInstruction(&cpu.memory, 10, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 12, 0x0000);
        writeInstruction(&cpu.memory, 14, 0x7000);
        writeInstruction(&cpu.memory, 16, ISA.encode16(.MOV, .AX, .AX, .Imm));
        writeInstruction(&cpu.memory, 18, 0xBBBB);
        writeInstruction(&cpu.memory, 20, 0x7000);
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        _ = try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
    }
}

// =============================================================================
// PUSH/POP Additional Tests
// =============================================================================

test "PUSH DX 16-bit" {
    var cpu = CPU{};
    cpu.dx = 0xDEAD;
    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .DX));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xFFFC), cpu.sp);
    try std.testing.expectEqual(@as(u16, 0xDEAD), cpu.readWord(0xFFFC));
}

test "POP CX 16-bit after PUSH" {
    var cpu = CPU{};
    cpu.cx = 0xCAFE;
    writeInstruction(&cpu.memory, 0, ISA.encodePushPop(.PUSH, .CX));
    _ = try cpu.step();
    writeInstruction(&cpu.memory, 2, ISA.encodePushPop(.POP, .DX));
    _ = try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xCAFE), cpu.dx);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// INT/IRET Additional Tests
// =============================================================================

test "INT vector 0x0000" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.INT, .AX, 0x0000));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0000), cpu.ip);
}

test "INT 0x0002 16-bit step" {
    var cpu = CPU{};
    writeInstruction(&cpu.memory, 0, ISA.encode16(.INT, .AX, .AX, .Imm));
    writeInstruction(&cpu.memory, 2, 0x0002);
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0008), cpu.ip);
    try std.testing.expectEqual(@as(u16, 0x0004), cpu.popStack());
}

test "INT then IRET restores flags" {
    var cpu = CPU{};
    cpu.flags = CPU.ZERO_FLAG | CPU.CARRY_FLAG;
    // INT at 0x00, return IP = 0x04, jumps to vector*4 = 0x08
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.INT, .AX, 0x0002));
    // HLT at return address (0x04)
    writeInstruction(&cpu.memory, 4, 0x7000);
    // IRET at ISR address (0x08)
    writeInstruction(&cpu.memory, 8, ISA.encode16(.IRET, .AX, .AX, .RegReg));
    _ = try cpu.run(100);
    try std.testing.expect(cpu.halted);
    try std.testing.expectEqual(@as(u16, CPU.ZERO_FLAG | CPU.CARRY_FLAG), cpu.flags);
    try std.testing.expectEqual(@as(u16, 0xFFFE), cpu.sp);
}

// =============================================================================
// Peripheral Edge Cases
// =============================================================================

test "UART: putUartRx fills and wraps" {
    var cpu = CPU{};
    for (0..255) |i| cpu.putUartRx(@intCast(i & 0xFF));
    for (0..255) |i| {
        const ch = cpu.readPort(0x00);
        try std.testing.expectEqual(@as(u16, @intCast(i & 0xFF)), ch);
    }
}

test "UART: hasUartRx" {
    var cpu = CPU{};
    try std.testing.expectEqual(false, cpu.hasUartRx());
    cpu.putUartRx('A');
    try std.testing.expectEqual(true, cpu.hasUartRx());
    _ = cpu.readPort(0x00);
    try std.testing.expectEqual(false, cpu.hasUartRx());
}

test "Keyboard: hasKey" {
    var cpu = CPU{};
    try std.testing.expectEqual(false, cpu.hasKey());
    cpu.kbd_buffer[0] = 0x1E;
    cpu.kbd_head = 1;
    try std.testing.expectEqual(true, cpu.hasKey());
}

test "Keyboard: fill and drain buffer" {
    var cpu = CPU{};
    for (0..100) |i| {
        cpu.kbd_buffer[cpu.kbd_head] = @intCast(i & 0xFF);
        cpu.kbd_head +%= 1;
    }
    try std.testing.expectEqual(@as(u8, 100), cpu.kbd_head);
    for (0..100) |i| {
        try std.testing.expectEqual(@as(u16, @intCast(i & 0xFF)), cpu.readPort(0x02));
    }
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x02));
}

test "VGA: backspace at col 0 wraps row" {
    var cpu = CPU{};
    cpu.vga_cursor_row = 1;
    cpu.vga_cursor_col = 0;
    cpu.vga_buffer[79] = 0x0741;
    cpu.vgaPutChar(0x08);
    try std.testing.expectEqual(@as(u16, 0), cpu.vga_cursor_row);
    try std.testing.expectEqual(@as(u16, 79), cpu.vga_cursor_col);
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[79]);
}

test "VGA: scroll multiple times" {
    var cpu = CPU{};
    for (0..30) |_| cpu.vgaPutChar(0x0A);
    try std.testing.expectEqual(@as(u16, 24), cpu.vga_cursor_row);
}

test "VGA: vgaControl unsupported no-op" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741;
    cpu.vgaControl(0x0000);
    try std.testing.expectEqual(@as(u16, 0x0741), cpu.vga_buffer[0]);
}

test "putKey: non-printable ignored" {
    var cpu = CPU{};
    cpu.putKey(0x01);
    try std.testing.expectEqual(@as(u8, 0), cpu.line_len);
}

test "parseCommand: trailing spaces" {
    var cpu = CPU{};
    cpu.line_buf[0..8].* = .{ 'h', 'e', 'l', 'p', ' ', ' ', ' ', ' ' };
    cpu.line_len = 8;
    cpu.parseCommand();
    try std.testing.expectEqual(@as(u8, 1), cpu.cmd_id);
}

test "parseCommand: case sensitive" {
    var cpu = CPU{};
    cpu.line_buf[0..4].* = .{ 'H', 'E', 'L', 'P' };
    cpu.line_len = 4;
    cpu.parseCommand();
    try std.testing.expectEqual(@as(u8, 7), cpu.cmd_id);
}

test "parseCommand: mixed spaces" {
    var cpu = CPU{};
    cpu.line_buf[0..10].* = .{ ' ', ' ', 'h', 'e', 'l', 'p', ' ', ' ', ' ', ' ' };
    cpu.line_len = 10;
    cpu.parseCommand();
    try std.testing.expectEqual(@as(u8, 1), cpu.cmd_id);
}

// =============================================================================
// I/O Port Edge Cases
// =============================================================================

test "readPort port > 0xFF returns 0" {
    var cpu = CPU{};
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x100));
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0xFFFF));
}

test "writePort port > 0xFF is no-op" {
    var cpu = CPU{};
    cpu.writePort(0x100, 0x1234);
    cpu.writePort(0xFFFF, 0x5678);
}

test "IN from timer port via step" {
    var cpu = CPU{};
    cpu.cycle_count = 0xABCD;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0005));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.ax);
}

test "OUT to timer port ignored" {
    var cpu = CPU{};
    cpu.ax = 0x1234;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0005));
    try cpu.step();
}

test "IN from keyboard via step" {
    var cpu = CPU{};
    cpu.kbd_buffer[0] = 0x1E;
    cpu.kbd_head = 1;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0002));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x1E), cpu.ax);
}

test "OUT to keyboard port ignored" {
    var cpu = CPU{};
    cpu.ax = 0x5678;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0002));
    try cpu.step();
}

test "UART status via IN instruction" {
    var cpu = CPU{};
    // TX should be empty initially
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0001));
    try cpu.step();
    try std.testing.expect(cpu.ax & 0x0002 != 0); // TX Empty
    try std.testing.expectEqual(@as(u16, 0), cpu.ax & 0x0001); // RX empty
}

test "OUT 0x11 with unsupported value" {
    var cpu = CPU{};
    cpu.vga_buffer[0] = 0x0741;
    cpu.ax = 0xFFFF;
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0011));
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x0741), cpu.vga_buffer[0]);
}

// =============================================================================
// UART Helper Tests
// =============================================================================

test "getUartTx: empty returns null" {
    var cpu = CPU{};
    try std.testing.expectEqual(@as(?u8, null), cpu.getUartTx());
}

test "getUartTx: returns byte and advances" {
    var cpu = CPU{};
    cpu.uart_tx[0] = 'A';
    cpu.uart_tx_head = 1;
    try std.testing.expectEqual(@as(u8, 'A'), cpu.getUartTx().?);
    try std.testing.expectEqual(@as(?u8, null), cpu.getUartTx());
}

test "flushUartTx: empty buffer no crash" {
    var cpu = CPU{};
    cpu.flushUartTx();
}

test "flushUartTx: CRLF sequence" {
    var cpu = CPU{};
    cpu.uart_tx[0] = 'H';
    cpu.uart_tx[1] = 'i';
    cpu.uart_tx[2] = 0x0D;
    cpu.uart_tx[3] = 0x0A;
    cpu.uart_tx_head = 4;
    cpu.flushUartTx();
    try std.testing.expectEqual(cpu.uart_tx_head, cpu.uart_tx_tail);
}

// =============================================================================
// Additional Peripheral Edge Case Tests
// =============================================================================

test "Generic I/O port 0x06: write then read" {
    var cpu = CPU{};
    cpu.writePort(6, 0xABCD);
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.readPort(6));
}

test "Generic I/O port 0xFF: boundary" {
    var cpu = CPU{};
    cpu.writePort(0xFF, 0x1234);
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.readPort(0xFF));
}

test "Timer: IN reads cycle_count" {
    var cpu = CPU{};
    try cpu.step();
    try cpu.step();
    try cpu.step();
    try std.testing.expectEqual(@as(u16, @truncate(cpu.cycle_count & 0xFFFF)), cpu.readPort(0x05));
}

test "Timer: read via IN instruction" {
    var cpu = CPU{};
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.MOV, .BX, 0x1234));
    writeInstruction32(&cpu.memory, 4, ISA.encode32(.IN, .AX, 0x0005));
    try cpu.step();
    try cpu.step();
    try std.testing.expectEqual(@as(u16, @truncate(cpu.cycle_count & 0xFFFF)), cpu.ax);
}

test "Keyboard: OUT is no-op (no crash)" {
    var cpu = CPU{};
    cpu.writePort(2, 0xFFFF);
    try std.testing.expectEqual(@as(u8, 0), cpu.kbd_head);
    try std.testing.expectEqual(@as(u8, 0), cpu.kbd_tail);
}

test "VGA: multiple writes" {
    var cpu = CPU{};
    cpu.writePort(0x10, 'H');
    cpu.writePort(0x10, 'e');
    cpu.writePort(0x10, 'l');
    cpu.writePort(0x10, 'l');
    cpu.writePort(0x10, 'o');
    try std.testing.expectEqual(@as(u16, 0x0700 | 'H'), cpu.vga_buffer[0]);
    try std.testing.expectEqual(@as(u16, 0x0700 | 'e'), cpu.vga_buffer[1]);
    try std.testing.expectEqual(@as(u16, 0x0700 | 'l'), cpu.vga_buffer[2]);
    try std.testing.expectEqual(@as(u16, 0x0700 | 'l'), cpu.vga_buffer[3]);
    try std.testing.expectEqual(@as(u16, 0x0700 | 'o'), cpu.vga_buffer[4]);
}

test "VGA: control clear then write" {
    var cpu = CPU{};
    cpu.writePort(0x11, 0x0001);
    cpu.writePort(0x10, 'A');
    try std.testing.expectEqual(@as(u16, 0x0700 | 'A'), cpu.vga_buffer[0]);
    try std.testing.expectEqual(@as(u16, 0x0720), cpu.vga_buffer[1]);
}

test "Port 0x03: clear-on-read" {
    var cpu = CPU{};
    cpu.cmd_id = 5;
    try std.testing.expectEqual(@as(u16, 5), cpu.readPort(0x03));
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x03));
}

test "Port 0x04: read line buffer bytes sequentially" {
    var cpu = CPU{};
    cpu.line_buf[0..5].* = .{ 'H', 'e', 'l', 'l', 'o' };
    cpu.line_len = 5;
    try std.testing.expectEqual(@as(u16, 'H'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 'e'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 'l'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 'l'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 'o'), cpu.readPort(0x04));
    try std.testing.expectEqual(@as(u16, 0), cpu.readPort(0x04));
}

// =============================================================================
// ALU All Ops Roundtrip
// =============================================================================

test "ALU all ops roundtrip" {
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.ADD, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x1243), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getCarry());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SUB, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x1225), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getCarry());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.CMP, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getCarry());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.TEST, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x1234), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.AND, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0004), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.OR, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x123F), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        cpu.bx = 0x000F;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.XOR, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x123B), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x8000;
        cpu.bx = 0x0001;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHL, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
        try std.testing.expect(cpu.getZero());
        try std.testing.expect(cpu.getCarry());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x0001;
        cpu.bx = 0x0001;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.SHR, .AX, .BX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
        try std.testing.expect(cpu.getZero());
        try std.testing.expect(cpu.getCarry());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0xFFFF;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.INC, .AX, .AX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
        try std.testing.expect(cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x0001;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.DEC, .AX, .AX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0x0000), cpu.ax);
        try std.testing.expect(cpu.getZero());
        try std.testing.expectEqual(false, cpu.getSign());
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x1234;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NOT, .AX, .AX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xEDCB), cpu.ax);
    }
    {
        var cpu = CPU{};
        cpu.ax = 0x0001;
        writeInstruction(&cpu.memory, 0, ISA.encodeAlu(.NEG, .AX, .AX));
        try cpu.step();
        try std.testing.expectEqual(@as(u16, 0xFFFF), cpu.ax);
        try std.testing.expectEqual(false, cpu.getZero());
        try std.testing.expect(cpu.getCarry());
        try std.testing.expect(cpu.getSign());
    }
}


