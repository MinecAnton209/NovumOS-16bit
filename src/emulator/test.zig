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
// PIC 8259 Tests (ports 0x20-0x21)
// =============================================================================

// Write EOI command to PIC command register (0x20).
test "PIC: write EOI command" {
    var cpu = CPU{};
    cpu.pic_isr = 0x04; // IRQ2 pending in ISR
    cpu.pic_pending = true;

    // OUT 0x20, 0x20 — EOI command (bit 5 set)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0020));
    cpu.ax = 0x0020; // EOI = 0x20

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0), cpu.pic_isr);
    try std.testing.expectEqual(false, cpu.pic_pending);
}

// Write IMR to PIC data register (0x21).
test "PIC: write IMR" {
    var cpu = CPU{};

    // OUT 0x21, 0xFD — mask all except IRQ0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0021));
    cpu.ax = 0x00FD;

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0xFD), cpu.pic_imr);
}

// Read IMR from PIC data register (0x21).
test "PIC: read IMR" {
    var cpu = CPU{};
    cpu.pic_imr = 0xF1; // Mask IRQ1,4-7

    // IN AX, 0x21 — read IMR
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0021));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xF1), cpu.ax);
}

// Request IRQ and check pending state.
test "PIC: IRQ request" {
    var cpu = CPU{};
    cpu.pic_imr = 0xFC; // Mask IRQ2-7, allow IRQ0-1

    cpu.requestIrq(0); // Request IRQ0
    try std.testing.expectEqual(true, cpu.pic_pending);
    try std.testing.expectEqual(@as(u8, 0x01), cpu.pic_irr);

    cpu.requestIrq(1); // Request IRQ1
    try std.testing.expectEqual(@as(u8, 0x03), cpu.pic_irr);

    // Mask IRQ0 — should still be pending (IRQ1 unmasked)
    cpu.pic_imr = 0xFE; // Mask IRQ0 only
    cpu.picUpdatePending();
    try std.testing.expectEqual(true, cpu.pic_pending);
}

// IRQ masked — should not trigger pending.
test "PIC: masked IRQ" {
    var cpu = CPU{};
    cpu.pic_imr = 0xFF; // All masked

    cpu.requestIrq(0);
    try std.testing.expectEqual(false, cpu.pic_pending);
    try std.testing.expectEqual(@as(u8, 0x01), cpu.pic_irr); // IRR still set
}

// ISR blocks same-level IRQ.
test "PIC: ISR blocks IRQ" {
    var cpu = CPU{};
    cpu.pic_imr = 0xFE; // Allow IRQ0
    cpu.pic_isr = 0x01; // IRQ0 in service

    cpu.requestIrq(0);
    cpu.picUpdatePending();
    try std.testing.expectEqual(false, cpu.pic_pending); // Blocked by ISR
}

// =============================================================================
// PIT 8254 Tests (ports 0x40-0x43)
// =============================================================================

// Write mode register (0x43).
test "PIT: write mode" {
    var cpu = CPU{};

    // OUT 0x43, 0x36 — Channel 0, lobyte/hibyte, rate generator
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0043));
    cpu.ax = 0x0036;

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0x36), cpu.pit_mode);
}

// Write Channel 0 (0x40).
test "PIT: write channel 0" {
    var cpu = CPU{};

    // OUT 0x40, 0x3412 — write counter value
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0040));
    cpu.ax = 0x3412;

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x3412), cpu.pit_ch0);
}

// Write Channel 1 (0x41).
test "PIT: write channel 1" {
    var cpu = CPU{};

    // OUT 0x41, 0xABCD
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0041));
    cpu.ax = 0xABCD;

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0xABCD), cpu.pit_ch1);
}

// Write Channel 2 (0x42).
test "PIT: write channel 2" {
    var cpu = CPU{};

    // OUT 0x42, 0x00FF
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x0042));
    cpu.ax = 0x00FF;

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x00FF), cpu.pit_ch2);
}

// Read Channel 0 low byte.
test "PIT: read channel 0 low" {
    var cpu = CPU{};
    cpu.pit_ch0 = 0x1234;

    // IN AX, 0x40 — read low byte of channel 0
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x0040));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x34), cpu.ax); // Low byte only
}

// =============================================================================
// UART 16550 Tests (ports 0x3F8-0x3FF)
// =============================================================================

// Write and read data register (0x3F8).
test "UART: write/read data" {
    var cpu = CPU{};

    // OUT 0x3F8, 'A' — write character
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x3F8));
    cpu.ax = @intCast(@as(u16, 'A'));

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 'A'), cpu.uart_tx[0]);
    try std.testing.expectEqual(@as(u8, 1), cpu.uart_tx_head);

    // Read back from RX buffer
    cpu.uart_rx[0] = 'B';
    cpu.uart_rx_head = 1;
    cpu.uart_rx_tail = 0;

    writeInstruction32(&cpu.memory, 4, ISA.encode32(.IN, .AX, 0x3F8));
    cpu.ip = 0x0004;
    try cpu.step();
    try std.testing.expectEqual(@as(u16, 'B'), cpu.ax);
}

// Read LSR (0x3FD) — TX empty + THR empty.
test "UART: read LSR idle" {
    var cpu = CPU{};

    // IN AX, 0x3FD — read LSR
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x3FD));

    try cpu.step();
    // Bit 5 (THR empty) + Bit 6 (TX empty) = 0x60
    try std.testing.expectEqual(@as(u16, 0x60), cpu.ax);
}

// Read LSR with data ready.
test "UART: read LSR data ready" {
    var cpu = CPU{};
    cpu.uart_rx[0] = 0x41;
    cpu.uart_rx_head = 1;

    // IN AX, 0x3FD — read LSR
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x3FD));

    try cpu.step();
    // Bit 0 (Data Ready) + Bit 5 (THR empty) + Bit 6 (TX empty) = 0x61
    try std.testing.expectEqual(@as(u16, 0x61), cpu.ax);
}

// Read IIR (0x3FA) — no interrupt pending.
test "UART: read IIR no interrupt" {
    var cpu = CPU{};

    // IN AX, 0x3FA — read IIR
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x3FA));

    try cpu.step();
    // Bit 0 = 1 (no interrupt pending)
    try std.testing.expectEqual(@as(u16, 0x01), cpu.ax);
}

// Read IIR with data ready — interrupt pending.
test "UART: read IIR data ready" {
    var cpu = CPU{};
    cpu.uart_rx[0] = 0x41;
    cpu.uart_rx_head = 1;

    // IN AX, 0x3FA — read IIR
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x3FA));

    try cpu.step();
    // Bits 1-3 = 010 (Receiver data ready), Bit 0 = 0 (interrupt pending)
    try std.testing.expectEqual(@as(u16, 0x04), cpu.ax);
}

// Write IER (0x3F9).
test "UART: write IER" {
    var cpu = CPU{};

    // OUT 0x3F9, 0x01 — enable RX interrupt
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x3F9));
    cpu.ax = 0x0001;

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0x01), cpu.uart_ier);
}

// Write LCR (0x3FB).
test "UART: write LCR" {
    var cpu = CPU{};

    // OUT 0x3FB, 0x80 — enable DLAB (divisor latch access)
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x3FB));
    cpu.ax = 0x0080;

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0x80), cpu.uart_lcr);
}

// Write SCR (0x3FF) — scratch register.
test "UART: write scratch" {
    var cpu = CPU{};

    // OUT 0x3FF, 0xAA
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.OUT, .AX, 0x3FF));
    cpu.ax = 0x00AA;

    try cpu.step();
    try std.testing.expectEqual(@as(u8, 0xAA), cpu.uart_scr);
}

// Read SCR (0x3FF).
test "UART: read scratch" {
    var cpu = CPU{};
    cpu.uart_scr = 0x55;

    // IN AX, 0x3FF
    writeInstruction32(&cpu.memory, 0, ISA.encode32(.IN, .AX, 0x3FF));

    try cpu.step();
    try std.testing.expectEqual(@as(u16, 0x55), cpu.ax);
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
