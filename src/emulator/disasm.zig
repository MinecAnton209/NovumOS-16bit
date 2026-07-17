const std = @import("std");
const ISA = @import("codegen");

/// Disassembler for NovumOS-16bit CPU instructions.
///
/// Converts binary instruction words into human-readable assembly text.
/// Supports both 16-bit and 32-bit instruction formats.
pub const Disassembler = struct {
    memory: []const u8,

    pub fn init(memory: []const u8) Disassembler {
        return .{ .memory = memory };
    }

    fn readWord(self: *Disassembler, addr: u16) u16 {
        const lo: u16 = self.memory[addr];
        const hi: u16 = self.memory[@intCast(@as(u32, addr) +% 1 & 0xFFFF)];
        return lo | (hi << 8);
    }

    fn readWord32(self: *Disassembler, addr: u16) u32 {
        const w0: u32 = self.readWord(addr);
        const w1: u32 = self.readWord(addr +% 2);
        return w0 | (w1 << 16);
    }

    fn regName(r: ISA.Register) []const u8 {
        return switch (r) {
            .AX => "AX",
            .BX => "BX",
            .CX => "CX",
            .DX => "DX",
        };
    }

    fn aluName(op: ISA.AluOp) []const u8 {
        return switch (op) {
            .ADD => "ADD", .SUB => "SUB", .CMP => "CMP", .TEST => "TEST",
            .AND => "AND", .OR => "OR", .XOR => "XOR", .SHL => "SHL",
            .SHR => "SHR", .INC => "INC", .DEC => "DEC", .NOT => "NOT",
            .NEG => "NEG",
        };
    }

    fn condName(cond: ISA.CondJump) []const u8 {
        return switch (cond) {
            .JZ => "JZ", .JNZ => "JNZ", .JC => "JC", .JNC => "JNC",
            .JS => "JS", .JNS => "JNS",
        };
    }

    fn writeHex4(buf: []u8, pos: *usize, val: u16) void {
        const hex = "0123456789ABCDEF";
        buf[pos.*] = hex[(val >> 12) & 0xF];
        buf[pos.* + 1] = hex[(val >> 8) & 0xF];
        buf[pos.* + 2] = hex[(val >> 4) & 0xF];
        buf[pos.* + 3] = hex[val & 0xF];
        pos.* += 4;
    }

    fn writeStr(buf: []u8, pos: *usize, s: []const u8) void {
        for (s) |ch| {
            buf[pos.*] = ch;
            pos.* += 1;
        }
    }

    /// Disassemble a single instruction. Returns text and size (2 or 4).
    pub fn disassemble(self: *Disassembler, addr: u16) struct { text: [64]u8, size: u8 } {
        var buf: [64]u8 = std.mem.zeroes([64]u8);
        var p: usize = 0;

        const lo16 = self.readWord(addr);
        const hi16 = self.readWord(addr +% 2);
        const raw32: u32 = @as(u32, lo16) | (@as(u32, hi16) << 16);

        const hi_mode: u2 = @intCast((raw32 >> 24) & 0x3);
        const is_32bit = hi_mode == 0b01;
        const opcode_raw: u4 = if (is_32bit) @intCast((raw32 >> 28) & 0xF) else @intCast((lo16 >> 12) & 0xF);
        const opcode: ISA.Opcode = @enumFromInt(opcode_raw);

        if (is_32bit) {
            const dst_raw: u2 = @intCast((raw32 >> 26) & 0x3);
            const dst: ISA.Register = @enumFromInt(dst_raw);
            const imm: u16 = @intCast((raw32 >> 8) & 0xFFFF);

            switch (opcode) {
                .MOV => {
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((raw32 >> 24) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", 0x");
                            writeHex4(&buf, &p, imm);
                        },
                        .RegReg => {
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((raw32 >> 20) & 0x3)));
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", ");
                            writeStr(&buf, &p, regName(src));
                        },
                        .Indirect => {
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((raw32 >> 20) & 0x3)));
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", [");
                            writeStr(&buf, &p, regName(src));
                            writeStr(&buf, &p, "]");
                        },
                        .IndirectOff => {
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((raw32 >> 20) & 0x3)));
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", [");
                            writeStr(&buf, &p, regName(src));
                            writeStr(&buf, &p, "+0x");
                            writeHex4(&buf, &p, imm);
                            writeStr(&buf, &p, "]");
                        },
                    }
                },
                .JMP => {
                    const mode: ISA.AddrMode = @enumFromInt(@as(u2, @intCast((raw32 >> 24) & 0x3)));
                    switch (mode) {
                        .Imm => {
                            writeStr(&buf, &p, "JMP 0x");
                            writeHex4(&buf, &p, imm);
                        },
                        .RegReg => {
                            const src: ISA.Register = @enumFromInt(@as(u2, @intCast((raw32 >> 20) & 0x3)));
                            writeStr(&buf, &p, "JMP ");
                            writeStr(&buf, &p, regName(src));
                        },
                        else => writeStr(&buf, &p, "JMP ?"),
                    }
                },
                .CALL => {
                    writeStr(&buf, &p, "CALL 0x");
                    writeHex4(&buf, &p, imm);
                },
                .INT => {
                    writeStr(&buf, &p, "INT 0x");
                    writeHex4(&buf, &p, imm);
                },
                .IN => {
                    writeStr(&buf, &p, "IN ");
                    writeStr(&buf, &p, regName(dst));
                    writeStr(&buf, &p, ", 0x");
                    writeHex4(&buf, &p, imm);
                },
                .OUT => {
                    writeStr(&buf, &p, "OUT 0x");
                    writeHex4(&buf, &p, imm);
                    writeStr(&buf, &p, ", ");
                    writeStr(&buf, &p, regName(dst));
                },
                .CondJump => {
                    const cond_raw: u4 = @intCast((raw32 >> 20) & 0xF);
                    const cond: ISA.CondJump = @enumFromInt(cond_raw);
                    const target: u16 = @intCast((raw32 >> 4) & 0xFFFF);
                    writeStr(&buf, &p, condName(cond));
                    writeStr(&buf, &p, " 0x");
                    writeHex4(&buf, &p, target);
                },
                else => {
                    writeStr(&buf, &p, "DW 0x");
                    writeHex4(&buf, &p, @intCast(raw32 & 0xFFFF));
                },
            }
            return .{ .text = buf, .size = 4 };
        } else {
            const dst_raw: u2 = @intCast((lo16 >> 10) & 0x3);
            const src_raw: u2 = @intCast((lo16 >> 8) & 0x3);
            const dst: ISA.Register = @enumFromInt(dst_raw);
            const src: ISA.Register = @enumFromInt(src_raw);
            const mode_raw: u2 = @intCast((lo16 >> 6) & 0x3);
            const mode: ISA.AddrMode = @enumFromInt(mode_raw);

            switch (opcode) {
                .NOP => writeStr(&buf, &p, "NOP"),
                .HLT => writeStr(&buf, &p, "HLT"),
                .RET => writeStr(&buf, &p, "RET"),
                .IRET => writeStr(&buf, &p, "IRET"),
                .MOV => {
                    switch (mode) {
                        .RegReg => {
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", ");
                            writeStr(&buf, &p, regName(src));
                        },
                        .Indirect => {
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", [");
                            writeStr(&buf, &p, regName(src));
                            writeStr(&buf, &p, "]");
                        },
                        .IndirectOff => {
                            const offset = self.readWord(addr +% 2);
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", [");
                            writeStr(&buf, &p, regName(src));
                            writeStr(&buf, &p, "+0x");
                            writeHex4(&buf, &p, offset);
                            writeStr(&buf, &p, "]");
                        },
                        .Imm => {
                            const imm16 = self.readWord(addr +% 2);
                            writeStr(&buf, &p, "MOV ");
                            writeStr(&buf, &p, regName(dst));
                            writeStr(&buf, &p, ", 0x");
                            writeHex4(&buf, &p, imm16);
                        },
                    }
                },
                .ALU => {
                    const alu_op_raw: u4 = @intCast((lo16 >> 8) & 0xF);
                    const alu_op: ISA.AluOp = @enumFromInt(alu_op_raw);
                    const alu_dst: u2 = @intCast((lo16 >> 6) & 0x3);
                    const alu_src: u2 = @intCast((lo16 >> 4) & 0x3);
                    const d: ISA.Register = @enumFromInt(alu_dst);
                    const s: ISA.Register = @enumFromInt(alu_src);
                    writeStr(&buf, &p, aluName(alu_op));
                    writeStr(&buf, &p, " ");
                    writeStr(&buf, &p, regName(d));
                    writeStr(&buf, &p, ", ");
                    writeStr(&buf, &p, regName(s));
                },
                .PushPop => {
                    const stack_op_raw: u2 = @intCast((lo16 >> 8) & 0x3);
                    const stack_op: ISA.StackOp = @enumFromInt(stack_op_raw);
                    switch (stack_op) {
                        .PUSH => {
                            writeStr(&buf, &p, "PUSH ");
                            writeStr(&buf, &p, regName(dst));
                        },
                        .POP => {
                            writeStr(&buf, &p, "POP ");
                            writeStr(&buf, &p, regName(dst));
                        },
                    }
                },
                .CondJump => {
                    const cond_raw: u4 = @intCast((lo16 >> 8) & 0xF);
                    const cond: ISA.CondJump = @enumFromInt(cond_raw);
                    const target = self.readWord(addr +% 2);
                    writeStr(&buf, &p, condName(cond));
                    writeStr(&buf, &p, " 0x");
                    writeHex4(&buf, &p, target);
                },
                .JMP => {
                    switch (mode) {
                        .Imm => {
                            const target = self.readWord(addr +% 2);
                            writeStr(&buf, &p, "JMP 0x");
                            writeHex4(&buf, &p, target);
                        },
                        .RegReg => {
                            writeStr(&buf, &p, "JMP ");
                            writeStr(&buf, &p, regName(src));
                        },
                        else => {
                            writeStr(&buf, &p, "DW 0x");
                            writeHex4(&buf, &p, lo16);
                        },
                    }
                },
                .CALL => {
                    switch (mode) {
                        .Imm => {
                            const target = self.readWord(addr +% 2);
                            writeStr(&buf, &p, "CALL 0x");
                            writeHex4(&buf, &p, target);
                        },
                        else => {
                            writeStr(&buf, &p, "DW 0x");
                            writeHex4(&buf, &p, lo16);
                        },
                    }
                },
                .INT => {
                    const vector = self.readWord(addr +% 2);
                    writeStr(&buf, &p, "INT 0x");
                    writeHex4(&buf, &p, vector);
                },
                .IN => {
                    const port = self.readWord(addr +% 2);
                    writeStr(&buf, &p, "IN ");
                    writeStr(&buf, &p, regName(dst));
                    writeStr(&buf, &p, ", 0x");
                    writeHex4(&buf, &p, port);
                },
                .OUT => {
                    const port = self.readWord(addr +% 2);
                    writeStr(&buf, &p, "OUT 0x");
                    writeHex4(&buf, &p, port);
                    writeStr(&buf, &p, ", ");
                    writeStr(&buf, &p, regName(dst));
                },
            }

            const is_extended = mode == .Imm or mode == .IndirectOff or
                opcode == .JMP or opcode == .CALL or opcode == .INT or
                opcode == .CondJump or opcode == .IN or opcode == .OUT;
            return .{ .text = buf, .size = if (is_extended) @as(u8, 4) else @as(u8, 2) };
        }
    }

    /// Count how many consecutive instructions starting at `addr` have the same
    /// disassembly text as the instruction at `addr`. Returns at least 1.
    pub fn countCollapsed(self: *Disassembler, addr: u16, end: u16) u16 {
        const first = self.disassemble(addr);
        var first_text: [64]u8 = std.mem.zeroes([64]u8);
        @memcpy(&first_text, &first.text);
        var first_len: usize = 0;
        while (first_len < first_text.len and first_text[first_len] != 0) : (first_len += 1) {}

        var count: u16 = 1;
        var scan_addr = addr +% first.size;
        while (scan_addr < end and count < 256) {
            const next = self.disassemble(scan_addr);
            var next_len: usize = 0;
            while (next_len < next.text.len and next.text[next_len] != 0) : (next_len += 1) {}
            if (!std.mem.eql(u8, first_text[0..first_len], next.text[0..next_len])) break;
            count += 1;
            scan_addr +%= next.size;
        }
        return count;
    }

    /// Disassemble a range of memory and print to stderr.
    /// Collapses repeated identical instructions (e.g. NOP runs) into a single range line.
    pub fn dumpDisassembly(self: *Disassembler, start: u16, end: u16) void {
        var addr = start;
        while (addr < end) {
            const result = self.disassemble(addr);
            const text = result.text;
            var len: usize = 0;
            while (len < text.len and text[len] != 0) : (len += 1) {}
            const text_str = if (len > 0) text[0..len] else "???";

            const count = self.countCollapsed(addr, end);
            const old = addr;
            if (count >= 3) {
                const range_end = addr +% (count - 1) *% result.size;
                std.debug.print("  0x{X:0>4} - 0x{X:0>4}: {s}\n", .{ addr, range_end, text_str });
                addr +%= count *% result.size;
            } else {
                std.debug.print("  0x{X:0>4}: ", .{addr});
                if (result.size == 4) {
                    const lo = self.readWord(addr);
                    const hi = self.readWord(addr +% 2);
                    std.debug.print("{X:0>2} {X:0>2} {X:0>2} {X:0>2}  ", .{
                        lo & 0xFF, (lo >> 8) & 0xFF, hi & 0xFF, (hi >> 8) & 0xFF,
                    });
                } else {
                    const lo = self.readWord(addr);
                    std.debug.print("{X:0>2} {X:0>2}        ", .{
                        lo & 0xFF, (lo >> 8) & 0xFF,
                    });
                }
                std.debug.print("{s}\n", .{text_str});
                addr +%= result.size;
            }
            if (addr <= old) break;
        }
    }
};
