const std = @import("std");
const ISA = @import("codegen");

/// CPU emulator for NovumOS-16bit.
///
/// Architecture:
/// - 4x 16-bit general-purpose registers: AX, BX, CX, DX
/// - Special registers: IP (instruction pointer), SP (stack pointer), FLAGS
/// - Flags: Z (Zero), C (Carry), S (Sign)
/// - 64 KB addressable memory, little-endian
/// - Stack grows downward (PUSH: SP-=2, POP: SP+=2)
///
/// Instruction formats:
/// - 16-bit: [opcode:4][dst:2][src:2][mode:2][unused:6]
///   Opcode in bits 15:12 identifies the instruction type.
///   Mode in bits 7:6 selects addressing mode (RegReg/Imm/Indirect/IndirectOff).
///   Used for: NOP, MOV reg,reg, ALU reg,reg, PUSH/POP, RET, HLT.
///
/// - 32-bit: [opcode:4][dst:2][mode=01:2][immediate:16][unused:8]
///   Mode is hardcoded to 01 (Imm) at bits 25:24 — this is how the CPU
///   distinguishes 32-bit from 16-bit instructions.
///   Opcode in bits 31:28 (NOT bits 15:12 like in 16-bit format).
///   Used for: MOV reg,imm, JMP imm, CALL imm, IN, OUT, CondJump.
///
/// Instruction size detection:
///   CPU reads bits 25:24 of the raw 32-bit word.
///   If mode == 01 → 32-bit instruction, decode opcode from bits 31:28.
///   Otherwise → 16-bit instruction, decode opcode from lo16 bits 15:12.
///   This works because encode32 ALWAYS sets mode=01 at bits 25:24,
///   while encode16 never uses mode=01 in that position.
pub const CPU = struct {
    // =========================================================================
    // CPU Registers
    // =========================================================================

    ax: u16 = 0,   // Accumulator — primary working register, ALU results
    bx: u16 = 0,   // Base — base register for indexed addressing
    cx: u16 = 0,   // Counter — loop counters, shift counts
    dx: u16 = 0,   // Data — I/O port addresses, multiply/divide operands
    ip: u16 = 0,   // Instruction Pointer — address of NEXT instruction to fetch
    sp: u16 = 0xFFFE, // Stack Pointer — top of stack, grows DOWNWARD
    flags: u16 = 0,    // Flags register — bit 0=Z, bit 1=C, bit 2=S
    memory: [65536]u8 = std.mem.zeroes([65536]u8), // 64 KB RAM (byte-addressable)
    halted: bool = false, // Halt flag — true after HLT instruction
    io_ports: [256]u16 = std.mem.zeroes([256]u16), // 256 x 16-bit I/O ports

    // =========================================================================
    // Peripherals
    // =========================================================================

    /// Cycle counter — incremented each step(), acts as a simple timer.
    cycle_count: u32 = 0,

    // --- VGA (port 0x10 output, port 0x11 control) ---

    /// VGA text buffer: 80 columns x 25 rows, each cell = 2 bytes (char + attr).
    /// Emulator renders this to the terminal via ANSI escape codes.
    vga_cols: u16 = 80,
    vga_rows: u16 = 25,
    vga_buffer: [2000]u16 = blk: {
        @setEvalBranchQuota(10000);
        var buf: [2000]u16 = undefined;
        for (&buf) |*cell| cell.* = 0x0720;
        break :blk buf;
    },
    vga_cursor_row: u16 = 0,
    vga_cursor_col: u16 = 0,
    vga_dirty: bool = true,
    vga_prev: [2000]u16 = blk: {
        @setEvalBranchQuota(10000);
        var buf: [2000]u16 = undefined;
        for (&buf) |*cell| cell.* = 0x0720;
        break :blk buf;
    },

    // --- UART (port 0x00) — legacy terminal I/O ---

    /// UART transmit buffer (output to terminal).
    uart_tx: [256]u8 = std.mem.zeroes([256]u8),
    uart_tx_head: u8 = 0,
    uart_tx_tail: u8 = 0,

    /// UART receive buffer (input from terminal).
    uart_rx: [256]u8 = std.mem.zeroes([256]u8),
    uart_rx_head: u8 = 0,
    uart_rx_tail: u8 = 0,

    // --- Keyboard (port 0x02) ---

    /// Keyboard ring buffer (emulator writes, CPU reads via IN).
    kbd_buffer: [256]u8 = std.mem.zeroes([256]u8),
    kbd_head: u8 = 0,
    kbd_tail: u8 = 0,

    // --- Line buffer (ports 0x03/0x04) ---

    /// Line buffer for command input (emulator handles editing).
    line_buf: [128]u8 = std.mem.zeroes([128]u8),
    line_len: u8 = 0,
    line_read_pos: u8 = 0,
    cmd_id: u8 = 0, // 0=none, 1=help, 2=clear, 3=reboot, 4=info, 5=dump, 6=halt, 7=unknown

    // =========================================================================
    // I/O Port Map
    // =========================================================================
    //
    // Port | Peripheral | Direction | Description
    // -----+------------+-----------+----------------------------------
    // 0x00 | UART       | R/W       | Terminal I/O (legacy, IN=rx, OUT=tx)
    // 0x01 | Timer      | Read      | Cycle counter (low 16 bits)
    // 0x02 | Keyboard   | Read      | Scan code (0 if empty, legacy)
    // 0x03 | Line stat  | Read      | Command ID (0=none, 1-6=cmd, 7=unknown)
    // 0x04 | Line read  | Read      | Next byte from line buffer (0=empty)
    // 0x10 | VGA        | Write     | Character output (char in low byte)
    // 0x11 | VGA ctrl   | Write     | Control: 0x0001=clear, 0x0002=flush

    // =========================================================================
    // Flag Bitmasks
    // =========================================================================

    pub const ZERO_FLAG: u16 = 1 << 0;   // Z — set when ALU result == 0
    pub const CARRY_FLAG: u16 = 1 << 1;  // C — set on unsigned overflow/borrow
    pub const SIGN_FLAG: u16 = 1 << 2;   // S — mirror of result bit 15 (negative)

    // =========================================================================
    // Register Access
    // =========================================================================

    /// Reset all registers to power-on defaults.
    /// IP=0x0000 (boot vector), SP=0xFFFE (top of stack), flags=0, halted=false.
    pub fn reset(self: *CPU) void {
        self.ax = 0;
        self.bx = 0;
        self.cx = 0;
        self.dx = 0;
        self.ip = 0;
        self.sp = 0xFFFE;
        self.flags = 0;
        self.halted = false;
    }

    /// Read a 16-bit word from memory (little-endian byte order).
    /// addr = address of the low byte; high byte is at addr+1.
    /// Address wraps around modulo 64K (addr+1 & 0xFFFF).
    pub fn readWord(self: *CPU, addr: u16) u16 {
        const lo: u16 = self.memory[addr];
        const hi: u16 = self.memory[@intCast(@as(u32, addr) +% 1 & 0xFFFF)];
        return lo | (hi << 8);
    }

    /// Write a 16-bit word to memory (little-endian byte order).
    pub fn writeWord(self: *CPU, addr: u16, value: u16) void {
        self.memory[addr] = @intCast(value & 0xFF);
        self.memory[@intCast(@as(u32, addr) +% 1 & 0xFFFF)] = @intCast((value >> 8) & 0xFF);
    }

    /// Read register value by register index (AX=0, BX=1, CX=2, DX=3).
    /// Used by all instruction decoders to resolve register fields.
    pub fn getReg(self: *CPU, reg: ISA.Register) u16 {
        return switch (reg) {
            .AX => self.ax,
            .BX => self.bx,
            .CX => self.cx,
            .DX => self.dx,
        };
    }

    /// Write value to register by register index.
    pub fn setReg(self: *CPU, reg: ISA.Register, value: u16) void {
        switch (reg) {
            .AX => self.ax = value,
            .BX => self.bx = value,
            .CX => self.cx = value,
            .DX => self.dx = value,
        }
    }

    // =========================================================================
    // Flag Management
    // =========================================================================

    /// Update Z (Zero) and S (Sign) flags based on ALU result.
    /// C (Carry) is set separately by each ALU operation — NOT touched here.
    ///
    /// Z flag: set if result == 0 (used by JZ, JNZ, CMP, TEST).
    /// S flag: set if bit 15 of result is 1 (used by JS, JNS).
    pub fn updateFlags(self: *CPU, result: u16) void {
        self.flags &= ~(ZERO_FLAG | SIGN_FLAG);
        if (result == 0) self.flags |= ZERO_FLAG;
        if (result & 0x8000 != 0) self.flags |= SIGN_FLAG;
    }

    /// Set or clear the Carry (C) flag.
    /// Used by ADD, SUB, INC, DEC, NEG, SHL, SHR, CMP.
    pub fn setCarry(self: *CPU, carry: bool) void {
        if (carry) {
            self.flags |= CARRY_FLAG;
        } else {
            self.flags &= ~CARRY_FLAG;
        }
    }

    /// Read the Carry (C) flag — used by JC, JNC.
    pub fn getCarry(self: *CPU) bool {
        return self.flags & CARRY_FLAG != 0;
    }

    /// Read the Zero (Z) flag — used by JZ, JNZ.
    pub fn getZero(self: *CPU) bool {
        return self.flags & ZERO_FLAG != 0;
    }

    /// Read the Sign (S) flag — used by JS, JNS.
    pub fn getSign(self: *CPU) bool {
        return self.flags & SIGN_FLAG != 0;
    }

    // =========================================================================
    // Stack Operations
    // =========================================================================

    /// PUSH — push a 16-bit value onto the stack.
    /// Stack grows DOWNWARD: SP is decremented by 2 BEFORE writing.
    /// Memory layout: [0x0000 ... SP ... 0xFFFE] (stack at top of address space).
    /// Example: PUSH 0x1234 when SP=0xFFFE → SP=0xFFFC, mem[0xFFFC]=0x34, mem[0xFFFD]=0x12
    pub fn pushStack(self: *CPU, value: u16) void {
        self.sp = self.sp -% 2;
        self.writeWord(self.sp, value);
    }

    /// POP — pop a 16-bit value from the stack.
    /// SP is incremented by 2 AFTER reading.
    /// Returns the value that was at the top of the stack.
    pub fn popStack(self: *CPU) u16 {
        const value = self.readWord(self.sp);
        self.sp = self.sp +% 2;
        return value;
    }

    // =========================================================================
    // Peripheral Interface
    // =========================================================================

    /// Put a key into the keyboard buffer (scan code).
    /// Called by the debugger or host system when a key is pressed.
    pub fn putKey(self: *CPU, scancode: u8) void {
        if (scancode == 0x0D) {
            // Enter — null-terminate, parse, reset for next line
            self.line_buf[self.line_len] = 0;
            self.parseCommand();
            self.line_read_pos = 0;
            self.line_len = 0;
            @memset(&self.line_buf, 0);
            self.vgaPutChar(0x0D); // carriage return
            self.vgaPutChar(0x0A); // newline
        } else if (scancode == 0x08) {
            // Backspace — remove last char
            if (self.line_len > 0) {
                self.line_len -= 1;
                self.line_buf[self.line_len] = 0;
                // erase on VGA: move back, write space, move back
                if (self.vga_cursor_col > 0) {
                    self.vga_cursor_col -= 1;
                } else if (self.vga_cursor_row > 0) {
                    self.vga_cursor_row -= 1;
                    self.vga_cursor_col = self.vga_cols - 1;
                }
                const idx = @as(u32, self.vga_cursor_row) * self.vga_cols + self.vga_cursor_col;
                if (idx < self.vga_buffer.len) {
                    self.vga_buffer[idx] = 0x0720; // space
                }
                self.vga_dirty = true;
                self.uartWriteData(0x08);
                self.uartWriteData(0x20);
                self.uartWriteData(0x08);
            }
        } else if (scancode >= 0x20 and scancode < 0x7F) {
            // Printable char — add to line buffer, echo to VGA
            if (self.line_len < 127) {
                self.line_buf[self.line_len] = scancode;
                self.line_len += 1;
                self.vgaPutChar(scancode);
            }
        }
    }

    /// Parse the line buffer and set cmd_id.
    pub fn parseCommand(self: *CPU) void {
        self.cmd_id = 0;
        if (self.line_len == 0) {
            self.cmd_id = 7; // treat empty as unknown → kernel re-prompts
            return;
        }

        // Skip leading spaces
        var start: u8 = 0;
        while (start < self.line_len and self.line_buf[start] == ' ') : (start += 1) {}
        if (start == self.line_len) return;

        // Find end of first word
        var end = start;
        while (end < self.line_len and self.line_buf[end] != ' ') : (end += 1) {}
        const cmd_len = end - start;

        // Match commands
        if (cmd_len == 4 and std.mem.eql(u8, self.line_buf[start..][0..4], "help")) {
            self.cmd_id = 1;
        } else if (cmd_len == 5 and std.mem.eql(u8, self.line_buf[start..][0..5], "clear")) {
            self.cmd_id = 2;
        } else if (cmd_len == 6 and std.mem.eql(u8, self.line_buf[start..][0..6], "reboot")) {
            self.cmd_id = 3;
        } else if (cmd_len == 4 and std.mem.eql(u8, self.line_buf[start..][0..4], "info")) {
            self.cmd_id = 4;
        } else if (cmd_len == 4 and std.mem.eql(u8, self.line_buf[start..][0..4], "dump")) {
            self.cmd_id = 5;
        } else if (cmd_len == 4 and std.mem.eql(u8, self.line_buf[start..][0..4], "halt")) {
            self.cmd_id = 6;
        } else {
            self.cmd_id = 7; // unknown
        }
    }

    /// Put a byte into the UART receive buffer.
    /// Called by the debugger or host system when serial data arrives.
    pub fn putUartRx(self: *CPU, byte: u8) void {
        self.uart_rx[self.uart_rx_head] = byte;
        self.uart_rx_head +%= 1;
    }

    /// Get the next byte from the UART transmit buffer.
    /// Returns null if buffer is empty.
    pub fn getUartTx(self: *CPU) ?u8 {
        if (self.uart_tx_head == self.uart_tx_tail) return null;
        const byte = self.uart_tx[self.uart_tx_tail];
        self.uart_tx_tail +%= 1;
        return byte;
    }

    /// Flush all pending bytes from UART TX buffer and print to stderr.
    /// Buffers all output and prints in one call to avoid garbled display.
    pub fn flushUartTx(self: *CPU) void {
        var buf: [512]u8 = undefined;
        var len: usize = 0;
        while (self.getUartTx()) |byte| {
            if (byte == '\n') {
                if (len + 1 <= buf.len) {
                    buf[len] = '\n';
                    len += 1;
                }
            } else if (byte == '\r') {
                // skip — \n already handles terminal line breaks
            } else if (byte == 0x08) {
                // backspace: move cursor back, space, back again
                if (len + 3 <= buf.len) {
                    buf[len] = 0x08;
                    buf[len + 1] = ' ';
                    buf[len + 2] = 0x08;
                    len += 3;
                }
            } else if (byte >= 0x20 and byte < 0x7F) {
                if (len < buf.len) {
                    buf[len] = byte;
                    len += 1;
                }
            } else {
                // non-printable: skip (or format as hex if needed)
            }
        }
        if (len > 0) {
            std.debug.print("{s}", .{buf[0..len]});
        }
    }

    /// Check if there's a key in the keyboard buffer.
    pub fn hasKey(self: *CPU) bool {
        return self.kbd_head != self.kbd_tail;
    }

    /// Check if there's data in the UART receive buffer.
    pub fn hasUartRx(self: *CPU) bool {
        return self.uart_rx_head != self.uart_rx_tail;
    }

    // =========================================================================
    // I/O Port Read/Write (with peripheral support)
    // =========================================================================

    /// Read a 16-bit value from an I/O port.
    /// Routes to special peripheral ports or generic io_ports[].
    pub fn readPort(self: *CPU, port: u16) u16 {
        return switch (port) {
            // --- UART (port 0x00) — read char from terminal input buffer ---
            0x00 => if (self.uart_rx_head != self.uart_rx_tail) blk: {
                const ch = self.uart_rx[self.uart_rx_tail];
                self.uart_rx_tail +%= 1;
                break :blk @intCast(ch);
            } else 0,

            // --- Timer (port 0x01) — read current tick counter ---
            0x01 => @truncate(self.cycle_count & 0xFFFF),

            // --- Keyboard (port 0x02) — read scan code ---
            0x02 => if (self.kbd_head != self.kbd_tail) blk: {
                const scancode = self.kbd_buffer[self.kbd_tail];
                self.kbd_tail +%= 1;
                break :blk @intCast(scancode);
            } else 0,

            // --- Line status (port 0x03) — read command ID, clears on read ---
            0x03 => blk: {
                const id = self.cmd_id;
                self.cmd_id = 0;
                break :blk id;
            },

            // --- Line read (port 0x04) — read next byte from line buffer ---
            0x04 => if (self.line_read_pos < self.line_len) blk: {
                const ch = self.line_buf[self.line_read_pos];
                self.line_read_pos += 1;
                break :blk ch;
            } else 0,

            // Generic I/O port (0-255)
            else => if (port <= 0xFF) self.io_ports[port] else 0,
        };
    }

    /// Write a 16-bit value to an I/O port.
    /// Routes to special peripheral ports or generic io_ports[].
    pub fn writePort(self: *CPU, port: u16, value: u16) void {
        switch (port) {
            // --- UART (port 0x00) — write char to terminal output buffer ---
            0x00 => self.uartWriteData(@intCast(value & 0xFF)),

            // --- VGA char output (port 0x10) ---
            0x10 => self.vgaPutChar(@intCast(value & 0xFF)),

            // --- VGA control (port 0x11) ---
            0x11 => self.vgaControl(value),

            // Timer and Keyboard are read-only — writes ignored

            // Generic I/O port (0-255)
            else => {
                if (port <= 0xFF) self.io_ports[port] = value;
            },
        }
    }

    // =========================================================================
    // UART 16550 Helper Functions
    // =========================================================================

    /// Write a byte to UART transmit buffer.
    pub fn uartWriteData(self: *CPU, byte: u8) void {
        self.uart_tx[self.uart_tx_head] = byte;
        self.uart_tx_head +%= 1;
    }

    // =========================================================================
    // VGA Helper Functions
    // =========================================================================

    /// Put a character to the VGA text buffer at the current cursor position.
    /// Also mirrors to UART TX buffer so the emulator can print to stdout.
    /// Handles CR (0x0D), LF (0x0A), printable chars, and scrolling.
    pub fn vgaPutChar(self: *CPU, byte: u8) void {
        // Mirror every VGA char to UART TX for terminal output
        self.uartWriteData(byte);

        switch (byte) {
            0x0D => {
                self.vga_cursor_col = 0;
            },
            0x0A => {
                self.vga_cursor_row += 1;
                if (self.vga_cursor_row >= self.vga_rows) {
                    self.vgaScrollUp();
                    self.vga_cursor_row = self.vga_rows - 1;
                }
            },
            0x08 => {
                // Backspace: move cursor back, clear character
                if (self.vga_cursor_col > 0) {
                    self.vga_cursor_col -= 1;
                } else if (self.vga_cursor_row > 0) {
                    self.vga_cursor_row -= 1;
                    self.vga_cursor_col = self.vga_cols - 1;
                }
                const idx = @as(u32, self.vga_cursor_row) * self.vga_cols + self.vga_cursor_col;
                if (idx < self.vga_buffer.len) {
                    self.vga_buffer[idx] = 0x0720; // space
                }
            },
            else => {
                const idx = @as(u32, self.vga_cursor_row) * self.vga_cols + self.vga_cursor_col;
                if (idx < self.vga_buffer.len) {
                    self.vga_buffer[idx] = 0x0700 | @as(u16, byte);
                }
                self.vga_cursor_col += 1;
                if (self.vga_cursor_col >= self.vga_cols) {
                    self.vga_cursor_col = 0;
                    self.vga_cursor_row += 1;
                    if (self.vga_cursor_row >= self.vga_rows) {
                        self.vgaScrollUp();
                        self.vga_cursor_row = self.vga_rows - 1;
                    }
                }
            },
        }
        self.vga_dirty = true;
    }

    /// Handle VGA control commands.
    pub fn vgaControl(self: *CPU, cmd: u16) void {
        switch (cmd) {
            0x0001 => {
                // Clear screen: fill buffer with spaces, reset cursor
                for (&self.vga_buffer) |*cell| cell.* = 0x0720;
                self.vga_cursor_row = 0;
                self.vga_cursor_col = 0;
            },
            0x0002 => {
                // Flush: mark dirty so emulator re-renders
                self.vga_dirty = true;
            },
            else => {},
        }
    }

    /// Scroll VGA buffer up by one row (row 1→0, row 2→1, ..., clear last row).
    pub fn vgaScrollUp(self: *CPU) void {
        const cols = self.vga_cols;
        const rows = self.vga_rows;
        const row_bytes: usize = cols;
        // Move rows 1..N-1 to 0..N-2
        var row: u16 = 1;
        while (row < rows) : (row += 1) {
            const src_start = @as(u32, row) * cols;
            const dst_start = @as(u32, row - 1) * cols;
            var col: u16 = 0;
            while (col < cols) : (col += 1) {
                _ = row_bytes;
                self.vga_buffer[dst_start + col] = self.vga_buffer[src_start + col];
            }
        }
        // Clear last row
        const last_start = @as(u32, rows - 1) * cols;
        var col: u16 = 0;
        while (col < cols) : (col += 1) {
            self.vga_buffer[last_start + col] = 0x0720;
        }
        self.vga_dirty = true;
    }

    // =========================================================================
    // Instruction Execution
    // =========================================================================

    /// Execute one instruction cycle: fetch, decode, execute.
    ///
    /// Fetch: always read 4 bytes (2 words) from IP to form raw32.
    ///   Even for 16-bit instructions, we speculatively read 32 bits
    ///   because we don't know the size yet.
    ///
    /// Decode: check bits 25:24 of raw32.
    ///   mode=01 means encode32 was used → 32-bit instruction.
    ///   Otherwise → 16-bit instruction.
    ///
    /// Execute: dispatch based on opcode and mode, advance IP accordingly.
    pub fn step(self: *CPU) !void {
        // Fetch raw 32 bits from IP (2 consecutive 16-bit words)
        const lo16 = self.readWord(self.ip);
        const hi16 = self.readWord(self.ip +% 2);
        const raw32: u32 = @as(u32, lo16) | (@as(u32, hi16) << 16);

        // Decode instruction size and opcode.
        // Bits 25:24 = mode field. In encode32, mode is always 01 (Imm).
        // In encode16, bits 7:6 are mode but bits 25:24 are undefined/zero.
        //
        // BUG: When a 16-bit ALU instruction is followed by a 32-bit one,
        // bits 25:24 of raw32 come from the NEXT instruction's bytes 10-11.
        // All 32-bit instructions have mode=01 at bits 25:24, so the 16-bit
        // ALU instruction gets misidentified as 32-bit.
        //
        // Fix: 16-bit ALU instructions always have opcode 0xA at bits 15:12.
        // 32-bit instructions have their opcode at bits 31:28, and bits 15:12
        // are part of the immediate field (never 0xA in practice for this ISA).
        // So if bits 15:12 == 0xA, it's definitely a 16-bit ALU instruction.
        //
        // Note: other 16-bit-only opcodes (NOP=0, RET=4, HLT=6, IRET=7, PushPop=0xC)
        // DON'T need special handling because when followed by a 32-bit instruction,
        // the next instruction's byte at addr+3 always has bits 25:24 = 0 (not 01),
        // so hi_mode == 0 and they're correctly detected as 16-bit.
        const hi_mode: u2 = @intCast((raw32 >> 24) & 0x3);
        const lo_opcode: u4 = @intCast((lo16 >> 12) & 0xF);
        const hi_opcode: u4 = @intCast((raw32 >> 28) & 0xF);
        // 16-bit ALU instructions have opcode 0xA at bits 15:12.
        // When a 16-bit ALU follows a 32-bit instruction, hi16 contains
        // bytes from the NEXT 32-bit instruction, which has hi_mode == 01
        // and hi_opcode matching a known 32-bit opcode. Without this check,
        // the ALU would be misidentified as 32-bit.
        const is_16bit_alu = (lo_opcode == 0xA);
        // 16-bit PushPop (opcode 0xC at bits 15:12) can also be misidentified
        // when followed by another PushPop whose byte at addr+3 has
        // hi_mode == 01 (e.g. PUSH DX=0xCC00 followed by POP DX=0xCD00).
        // Cross-check hi_opcode: if hi_opcode at bits 31:28 is a known
        // 32-bit-format opcode then lo_opcode may be a false positive
        // from the immediate field (e.g. MOV AX, 0xABCD has lo_opcode=0xC).
        // If hi_opcode is NOT in the 32-bit-format set, it's true 16-bit PushPop.
        const is_16bit_pushpop = (lo_opcode == 0xC) and switch (hi_opcode) {
            1, 2, 3, 5, 8, 9, 0xB => false,
            else => true,
        };
        const is_32bit = if (is_16bit_alu or is_16bit_pushpop) false else (hi_mode == 0b01);

        // Opcode extraction depends on instruction format:
        //   32-bit: bits 31:28 of raw32
        //   16-bit: bits 15:12 of lo16
        const opcode_raw: u4 = if (is_32bit) @intCast((raw32 >> 28) & 0xF) else @intCast((lo16 >> 12) & 0xF);
        const opcode: ISA.Opcode = @enumFromInt(opcode_raw);

        // 32-bit: work with raw32 for field extraction.
        // 16-bit: work with lo16 for field extraction.
        const inst16 = lo16;
        const inst32 = raw32;

        switch (opcode) {
            .NOP => {
                // No operation. Just advance IP by 2 bytes.
                self.ip +%= 2;
            },
            .MOV => {
                if (is_32bit) {
                    // 32-bit MOV: [opcode:4][dst:2][mode:2][imm/src:16][unused:8]
                    //   dst  = bits 27:26 (register to load/store)
                    //   mode = bits 25:24 (00=RegReg, 01=Imm, 10=Indirect, 11=IndirectOff)
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 26) & 0x3)));
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst32 >> 24) & 0x3)));
                    switch (mode) {
                        .RegReg => {
                            // MOV dst, src (register-to-register)
                            // src = bits 21:20, IP advances by 2
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 20) & 0x3)));
                            self.setReg(dst, self.getReg(src));
                            self.ip +%= 2;
                        },
                        .Imm => {
                            // MOV dst, #immediate (load 16-bit constant)
                            // immediate = bits 23:8, IP advances by 4
                            const imm: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                            self.setReg(dst, imm);
                            self.ip +%= 4;
                        },
                        .Indirect => {
                            // MOV dst, [src] (load word from address in src register)
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 20) & 0x3)));
                            const addr = self.getReg(src);
                            self.setReg(dst, self.readWord(addr));
                            self.ip +%= 2;
                        },
                        .IndirectOff => {
                            // MOV dst, [src + offset] (load with base+offset addressing)
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 20) & 0x3)));
                            const offset: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                            const addr = self.getReg(src) +% offset;
                            self.setReg(dst, self.readWord(addr));
                            self.ip +%= 4;
                        },
                    }
                } else {
                    // 16-bit MOV: [opcode:4][dst:2][src:2][mode:2][unused:6]
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 10) & 0x3)));
                    const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 8) & 0x3)));
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst16 >> 6) & 0x3)));
                    switch (mode) {
                        .RegReg => {
                            // MOV dst, src (16-bit register-to-register)
                            self.setReg(dst, self.getReg(src));
                            self.ip +%= 2;
                        },
                        .Imm => {
                            // MOV dst, #immediate (16-bit inline immediate)
                            // Immediate is the next word after the instruction
                            const imm = self.readWord(self.ip +% 2);
                            self.setReg(dst, imm);
                            self.ip +%= 4;
                        },
                        .Indirect => {
                            // MOV dst, [src] (16-bit indirect load)
                            const addr = self.getReg(src);
                            self.setReg(dst, self.readWord(addr));
                            self.ip +%= 2;
                        },
                        .IndirectOff => {
                            // MOV dst, [src + offset] (16-bit indirect with offset)
                            // Offset is the next word after the instruction
                            const offset = self.readWord(self.ip +% 2);
                            const addr = self.getReg(src) +% offset;
                            self.setReg(dst, self.readWord(addr));
                            self.ip +%= 4;
                        },
                    }
                }
            },
            .JMP => {
                // Unconditional jump — sets IP to target address.
                if (is_32bit) {
                    // 32-bit JMP: target is in bits 23:8 (inline immediate)
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst32 >> 24) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            // JMP #address — direct absolute jump
                            const target: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                            self.ip = target;
                        },
                        .RegReg => {
                            // JMP reg — jump to address stored in register
                            // Bits 21:20 encode the register (mode field reused for reg)
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 24) & 0x3)));
                            self.ip = self.getReg(src);
                        },
                        else => {
                            self.ip +%= 2;
                        },
                    }
                } else {
                    // 16-bit JMP: target is the next word (inline immediate)
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst16 >> 6) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            const target = self.readWord(self.ip +% 2);
                            self.ip = target;
                        },
                        .RegReg => {
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 8) & 0x3)));
                            self.ip = self.getReg(src);
                        },
                        else => {
                            self.ip +%= 2;
                        },
                    }
                }
            },
            .CALL => {
                // CALL — push return address onto stack, then jump to target.
                // Return address = IP + 4 (instruction after the CALL).
                if (is_32bit) {
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst32 >> 24) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            // CALL #address — push next IP, jump to immediate address
                            const target: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                            self.pushStack(self.ip +% 4);
                            self.ip = target;
                        },
                        else => {
                            self.ip +%= 2;
                        },
                    }
                } else {
                    // 16-bit CALL: target is the next word (inline immediate)
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((inst16 >> 6) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            const target = self.readWord(self.ip +% 2);
                            self.pushStack(self.ip +% 4);
                            self.ip = target;
                        },
                        else => {
                            self.ip +%= 2;
                        },
                    }
                }
            },
            .RET => {
                // Return from subroutine — pop return address from stack into IP.
                self.ip = self.popStack();
            },
            .INT => {
                // Software interrupt — push FLAGS and return address, jump to handler.
                // Handler address = vector * 4 (4 bytes per IVT entry).
                if (is_32bit) {
                    const vector: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                    self.pushStack(self.flags);
                    self.pushStack(self.ip +% 4);
                    self.ip = vector * 4;
                } else {
                    const vector = self.readWord(self.ip +% 2);
                    self.pushStack(self.flags);
                    self.pushStack(self.ip +% 4);
                    self.ip = vector * 4;
                }
            },
            .IRET => {
                // Return from interrupt — pop IP and FLAGS (in that order).
                self.ip = self.popStack();
                self.flags = self.popStack();
            },
            .HLT => {
                // Halt CPU — stops execution until reset.
                self.halted = true;
            },
            .IN => {
                // IN — read a 16-bit value from an I/O port into a register.
                // Supports both generic io_ports[] and special peripheral ports.
                if (is_32bit) {
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 26) & 0x3)));
                    const port: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                    self.setReg(dst, self.readPort(port));
                    self.ip +%= 4;
                } else {
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 10) & 0x3)));
                    const port = self.readWord(self.ip +% 2);
                    self.setReg(dst, self.readPort(port));
                    self.ip +%= 4;
                }
            },
            .OUT => {
                // OUT — write a 16-bit value from a register to an I/O port.
                // Supports both generic io_ports[] and special peripheral ports.
                if (is_32bit) {
                    const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 26) & 0x3)));
                    const port: u16 = @intCast((inst32 >> 8) & 0xFFFF);
                    self.writePort(port, self.getReg(src));
                    self.ip +%= 4;
                } else {
                    const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 10) & 0x3)));
                    const port = self.readWord(self.ip +% 2);
                    self.writePort(port, self.getReg(src));
                    self.ip +%= 4;
                }
            },
            .ALU => {
                // ALU — arithmetic/logic unit operations on two registers.
                // Operation selected by alu_op field.
                // Result is always stored in dst register.
                if (is_32bit) {
                    const alu_op: ISA.AluOp = @enumFromInt(@as(u4, @intCast((inst32 >> 24) & 0xF)));
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 22) & 0x3)));
                    const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 20) & 0x3)));
                    self.executeAlu(alu_op, dst, src);
                    self.ip +%= 2;
                } else {
                    const alu_op: ISA.AluOp = @enumFromInt(@as(u4, @intCast((inst16 >> 8) & 0xF)));
                    const dst: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 6) & 0x3)));
                    const src: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 4) & 0x3)));
                    self.executeAlu(alu_op, dst, src);
                    self.ip +%= 2;
                }
            },
            .CondJump => {
                // Conditional jump — jump to target if condition is met.
                // Conditions: JZ (Zero), JNZ (Not Zero), JC (Carry), JNC (No Carry),
                //            JS (Sign/Negative), JNS (No Sign/Positive)
                if (is_32bit) {
                    const cond: ISA.CondJump = @enumFromInt(@as(u4, @intCast((inst32 >> 20) & 0xF)));
                    const target: u16 = @intCast((inst32 >> 4) & 0xFFFF);
                    var taken = false;

                    switch (cond) {
                        .JZ => taken = self.getZero(),
                        .JNZ => taken = !self.getZero(),
                        .JC => taken = self.getCarry(),
                        .JNC => taken = !self.getCarry(),
                        .JS => taken = self.getSign(),
                        .JNS => taken = !self.getSign(),
                    }

                    if (taken) {
                        self.ip = target;
                    } else {
                        self.ip +%= 4;
                    }
                } else {
                    // 16-bit CondJump: condition in bits 11:8, target is next word
                    const cond: ISA.CondJump = @enumFromInt(@as(u4, @intCast((inst16 >> 8) & 0xF)));
                    const target = self.readWord(self.ip +% 2);
                    var taken = false;

                    switch (cond) {
                        .JZ => taken = self.getZero(),
                        .JNZ => taken = !self.getZero(),
                        .JC => taken = self.getCarry(),
                        .JNC => taken = !self.getCarry(),
                        .JS => taken = self.getSign(),
                        .JNS => taken = !self.getSign(),
                    }

                    if (taken) {
                        self.ip = target;
                    } else {
                        self.ip +%= 4;
                    }
                }
            },
            .PushPop => {
                // PUSH/POP — stack operations on registers.
                // PUSH: SP -= 2, then write register value to [SP].
                // POP: read value from [SP], then SP += 2.
                if (is_32bit) {
                    const reg: ISA.Register = @enumFromInt(@as(u2, @intCast((inst32 >> 26) & 0x3)));
                    const mode: ISA.StackOp = @enumFromInt(@as(u2, @intCast((inst32 >> 24) & 0x3)));
                    switch (mode) {
                        .PUSH => {
                            self.pushStack(self.getReg(reg));
                            self.ip +%= 2;
                        },
                        .POP => {
                            self.setReg(reg, self.popStack());
                            self.ip +%= 2;
                        },
                    }
                } else {
                    // 16-bit PushPop: reg in bits 11:10, mode (PUSH=00/POP=01) in bits 9:8
                    const reg: ISA.Register = @enumFromInt(@as(u2, @intCast((inst16 >> 10) & 0x3)));
                    const mode: ISA.StackOp = @enumFromInt(@as(u2, @intCast((inst16 >> 8) & 0x3)));
                    switch (mode) {
                        .PUSH => {
                            self.pushStack(self.getReg(reg));
                            self.ip +%= 2;
                        },
                        .POP => {
                            self.setReg(reg, self.popStack());
                            self.ip +%= 2;
                        },
                    }
                }
            },
        }
    }

    /// Execute an ALU (arithmetic/logic) operation.
    ///
    /// All operations read from dst and src registers, compute a result,
    /// and store it back in dst (except CMP and TEST which only set flags).
    ///
    /// Operations:
    ///   ADD  — dst = dst + src, set Carry on overflow
    ///   SUB  — dst = dst - src, set Carry on borrow
    ///   CMP  — same as SUB but result is discarded (flags only)
    ///   TEST — dst AND src, result discarded, flags only
    ///   AND  — dst = dst AND src
    ///   OR   — dst = dst OR src
    ///   XOR  — dst = dst XOR src
    ///   SHL  — dst = dst << count
    ///   SHR  — dst = dst >> count
    ///   INC  — dst = dst + 1
    ///   DEC  — dst = dst - 1
    ///   NOT  — dst = NOT dst (bitwise complement)
    ///   NEG  — dst = 0 - dst (two's complement negate)
    ///   MUL  — dst = dst * src (signed multiply) — planned
    ///   DIV  — dst = dst / src (signed divide) — planned
    fn executeAlu(self: *CPU, alu_op: ISA.AluOp, dst: ISA.Register, src: ISA.Register) void {
        const a = self.getReg(dst);
        const b = self.getReg(src);

        switch (alu_op) {
            .ADD => {
                // Addition with carry flag set on overflow
                const result, const carry = @addWithOverflow(a, b);
                self.setReg(dst, result);
                self.setCarry(carry != 0);
                self.updateFlags(result);
            },
            .SUB => {
                // Subtraction with borrow flag set on underflow
                const result, const borrow = @subWithOverflow(a, b);
                self.setReg(dst, result);
                self.setCarry(borrow != 0);
                self.updateFlags(result);
            },
            .CMP => {
                // Compare (subtract without storing result)
                const result, const borrow = @subWithOverflow(a, b);
                self.setCarry(borrow != 0);
                self.updateFlags(result);
            },
            .TEST => {
                // Bitwise AND without storing result (flags only)
                const result = a & b;
                self.setCarry(false);
                self.updateFlags(result);
            },
            .AND => {
                // Bitwise AND
                const result = a & b;
                self.setReg(dst, result);
                self.setCarry(false);
                self.updateFlags(result);
            },
            .OR => {
                // Bitwise OR
                const result = a | b;
                self.setReg(dst, result);
                self.setCarry(false);
                self.updateFlags(result);
            },
            .XOR => {
                // Bitwise XOR
                const result = a ^ b;
                self.setReg(dst, result);
                self.setCarry(false);
                self.updateFlags(result);
            },
            .SHL => {
                // Shift left by count (0-15). Carry = last bit shifted out.
                const count: u4 = @intCast(b & 0xF);
                const result = a << count;
                self.setReg(dst, result);
                self.setCarry(if (count > 0) (a >> (@as(u4, 0) -% count)) & 1 != 0 else false);
                self.updateFlags(result);
            },
            .SHR => {
                // Shift right by count (0-15). Carry = last bit shifted out.
                const count: u4 = @intCast(b & 0xF);
                const result = a >> count;
                self.setReg(dst, result);
                self.setCarry(if (count > 0) (a >> (@as(u4, count) -% 1)) & 1 != 0 else false);
                self.updateFlags(result);
            },
            .INC => {
                // Increment: dst = dst + 1 (does NOT affect Carry)
                const result = a +% 1;
                self.setReg(dst, result);
                self.updateFlags(result);
            },
            .DEC => {
                // Decrement: dst = dst - 1 (does NOT affect Carry)
                const result = a -% 1;
                self.setReg(dst, result);
                self.updateFlags(result);
            },
            .NOT => {
                // Bitwise complement (no flags affected)
                const result = ~a;
                self.setReg(dst, result);
            },
            .NEG => {
                // Two's complement negate: dst = 0 - dst
                // Carry is set if result != 0 (i.e., input was non-zero)
                const result = -%a;
                self.setReg(dst, result);
                self.setCarry(result != 0);
                self.updateFlags(result);
            },
            .MUL => {
                // Signed multiply — not yet implemented
                @panic("MUL not implemented");
            },
            .DIV => {
                // Signed divide — not yet implemented
                @panic("DIV not implemented");
            },
        }
    }

    /// Run the CPU for up to `max_cycles` instruction cycles.
    ///
    /// Each iteration calls step() which fetches-decodes-executes one instruction.
    /// Execution stops early if:
    ///   1. HLT instruction is executed (self.halted becomes true)
    ///   2. max_cycles is reached
    ///
    /// The cycle_count peripheral register is incremented each iteration.
    /// Returns the number of cycles actually executed (for benchmarking/logging).
    /// Errors from step() (e.g., invalid opcode) propagate to the caller.
    pub fn run(self: *CPU, max_cycles: u32) !u32 {
        var cycles: u32 = 0;
        while (!self.halted and cycles < max_cycles) : (cycles += 1) {
            try self.step();
            self.cycle_count += 1;
        }
        return cycles;
    }

    /// Load a byte program (raw binary) into CPU memory at start_addr.
    ///
    /// This is used by the emulator's main() to load firmware.bin,
    /// and by tests to inject instruction sequences.
    /// Bytes that would overflow past 64KB (address > 0xFFFF) are silently ignored.
    pub fn loadProgram(self: *CPU, program: []const u8, start_addr: u16) void {
        for (program, 0..) |byte, i| {
            if (start_addr +% @as(u16, @intCast(i)) < 65536) {
                self.memory[start_addr +% @as(u16, @intCast(i))] = byte;
            }
        }
    }

    /// Dump the full CPU state to stderr for debugging.
    ///
    /// Output format:
    ///   === CPU State ===
    ///   AX=0x0000 BX=0x0000 CX=0x0000 DX=0x0000
    ///   IP=0x0000 SP=0xFFFE FLAGS=0x0000 [Z=false C=false S=false]
    ///   Halted=false
    pub fn dumpState(self: *CPU) void {
        std.debug.print("=== CPU State ===\n", .{});
        std.debug.print("AX=0x{X:0>4} BX=0x{X:0>4} CX=0x{X:0>4} DX=0x{X:0>4}\n", .{ self.ax, self.bx, self.cx, self.dx });
        std.debug.print("IP=0x{X:0>4} SP=0x{X:0>4} FLAGS=0x{X:0>4} [Z={} C={} S={}]\n", .{ self.ip, self.sp, self.flags, self.getZero(), self.getCarry(), self.getSign() });
        std.debug.print("Halted={}\n", .{self.halted});
    }
};
