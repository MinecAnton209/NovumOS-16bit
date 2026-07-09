/// NovumOS-16bit Kernel — Bootloader + UART Console
const std = @import("std");
const codegen = @import("codegen");

const MEM = 65536;

const S_BOOT: usize = 0x1000;
const S_PROMPT: usize = 0x1020;
const S_HELP: usize = 0x1028;
const S_INFO: usize = 0x10C0;
const S_CLEAR: usize = 0x1140;
const S_DUMP_HDR: usize = 0x1150;
const S_NEWLINE: usize = 0x1170;
const HEX_TABLE: usize = 0x1800;

fn w16(b: *[MEM]u8, p: *usize, v: u16) void {
    b[p.*] = @intCast(v & 0xFF);
    b[p.* + 1] = @intCast((v >> 8) & 0xFF);
    p.* += 2;
}

fn w32(b: *[MEM]u8, p: *usize, v: u32) void {
    b[p.*] = @intCast(v & 0xFF);
    b[p.* + 1] = @intCast((v >> 8) & 0xFF);
    b[p.* + 2] = @intCast((v >> 16) & 0xFF);
    b[p.* + 3] = @intCast((v >> 24) & 0xFF);
    p.* += 4;
}

fn writeStr(b: *[MEM]u8, addr: usize, s: []const u8) void {
    for (s, 0..) |c, i| b[addr + i] = c;
    b[addr + s.len] = 0;
}

// Fixup system — tracks where to patch jump targets
const Fixup = struct {
    addr: u16,
    shift: u4, // bits to shift target: 8 for JMP/CALL, 4 for CondJump
};

const FixupList = struct {
    items: [128]Fixup = undefined,
    len: usize = 0,

    fn emitJump(self: *FixupList, b: *[MEM]u8, p: *usize, opcode: codegen.Opcode) void {
        self.items[self.len] = .{ .addr = @intCast(p.*), .shift = 8 };
        self.len += 1;
        w32(b, p, (@as(u32, @intFromEnum(opcode)) << 28) | (@as(u32, 0b01) << 24));
    }

    fn emitCondJump(self: *FixupList, b: *[MEM]u8, p: *usize, cond: codegen.CondJump) void {
        self.items[self.len] = .{ .addr = @intCast(p.*), .shift = 4 };
        self.len += 1;
        w32(b, p, (@as(u32, @intFromEnum(codegen.Opcode.CondJump)) << 28) |
            (@as(u32, 0b01) << 24) | (@as(u32, @intFromEnum(cond)) << 20));
    }

    fn patch(self: FixupList, b: *[MEM]u8, idx: usize, target: u16) void {
        const f = self.items[idx];
        const a = f.addr;
        const old = @as(u32, b[a]) | (@as(u32, b[a + 1]) << 8) |
            (@as(u32, b[a + 2]) << 16) | (@as(u32, b[a + 3]) << 24);
        const mask = ~(@as(u32, 0xFFFF) << @intCast(f.shift));
        const v = (old & mask) | (@as(u32, target) << @intCast(f.shift));
        b[a] = @intCast(v & 0xFF);
        b[a + 1] = @intCast((v >> 8) & 0xFF);
        b[a + 2] = @intCast((v >> 16) & 0xFF);
        b[a + 3] = @intCast((v >> 24) & 0xFF);
    }
};

pub const kernel_firmware: [MEM]u8 = generateKernel();

fn generateKernel() [MEM]u8 {
    var b: [MEM]u8 = std.mem.zeroes([MEM]u8);
    var p: usize = 0;
    var fx: FixupList = .{};

    writeStr(&b, S_BOOT, "NovumOS-16bit v0.1\r\n");
    writeStr(&b, S_PROMPT, "> ");
    writeStr(&b, S_HELP, "h=help c=clear r=reboot i=info\r\nd=dump x=halt\r\n");
    writeStr(&b, S_INFO, "NovumOS-16bit v0.1\r\nCPU: 16-bit NAND-core\r\nRAM: 64KB\r\nUART: 0x00\r\n");
    writeStr(&b, S_CLEAR, "\x1B[2J\x1B[H");
    writeStr(&b, S_DUMP_HDR, "\r\n[MEM 0x0000]\r\n");
    writeStr(&b, S_NEWLINE, "\r\n");
    writeStr(&b, HEX_TABLE, "0123456789ABCDEF");

    // BOOTLOADER
    p = 0;
    w16(&b, &p, codegen.encodeAlu(.XOR, .AX, .AX));
    w16(&b, &p, codegen.encode16(.MOV, .BX, .AX, .RegReg));
    w16(&b, &p, codegen.encode16(.MOV, .CX, .AX, .RegReg));
    w16(&b, &p, codegen.encode16(.MOV, .DX, .AX, .RegReg));

    const fi = fx.len;
    fx.emitJump(&b, &p, .CALL);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_BOOT));
    const fp = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fs = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // INIT_PERIPHERALS — no initialization needed (simple UART at port 0x00)
    const addr_init: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));

    // PRINT_STR: string at [BX]
    const addr_print: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    const fpjz = fx.len;
    fx.emitCondJump(&b, &p, .JZ);
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX));
    const fpjmp = fx.len;
    fx.emitJump(&b, &p, .JMP);
    const addr_ret: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));
    fx.patch(&b, fpjz, addr_ret);
    fx.patch(&b, fpjmp, addr_print);

    // PRINT_HEX_BYTE: print byte in AX as 2 hex chars. Clobbers CX.
    const addr_hex: u16 = @intCast(p);
    w16(&b, &p, codegen.encodePushPop(.PUSH, .BX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .CX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .DX));
    w16(&b, &p, codegen.encode16(.MOV, .DX, .AX, .RegReg)); // save byte
    // High nibble: SHR AX, 4
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0004));
    w16(&b, &p, codegen.encodeAlu(.SHR, .AX, .CX));
    // Look up hex table
    w32(&b, &p, codegen.encode32(.MOV, .BX, HEX_TABLE));
    w16(&b, &p, codegen.encodeAlu(.ADD, .BX, .AX));
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect)); // AX = [BX]
    // AND AX, 0x00FF (CPU has no ALU-imm, use MOV+AND)
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    // Low nibble: AND AX, 0x000F
    w16(&b, &p, codegen.encode16(.MOV, .AX, .DX, .RegReg)); // restore byte
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x000F));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.MOV, .BX, HEX_TABLE));
    w16(&b, &p, codegen.encodeAlu(.ADD, .BX, .AX));
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    // AND AX, 0x00FF
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    w16(&b, &p, codegen.encodePushPop(.POP, .DX));
    w16(&b, &p, codegen.encodePushPop(.POP, .CX));
    w16(&b, &p, codegen.encodePushPop(.POP, .BX));
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));

    // DUMP_MEM: hex dump of first 32 bytes of memory
    const addr_dump: u16 = @intCast(p);
    w16(&b, &p, codegen.encodePushPop(.PUSH, .BX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .CX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .DX));
    // Print header
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_DUMP_HDR));
    const fdh = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_STR
    // BX = 0x0000 (address), DX = 0x0020 (end)
    w32(&b, &p, codegen.encode32(.MOV, .BX, 0x0000));
    w32(&b, &p, codegen.encode32(.MOV, .DX, 0x0020));
    const fd_loop: u16 = @intCast(p);
    // Read word, print high byte
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0008));
    w16(&b, &p, codegen.encodeAlu(.SHR, .AX, .CX));
    const fdh1 = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_HEX_byte
    // Space
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0020));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    // Print low byte
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    // AND AX, 0x00FF
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    const fdh2 = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_HEX_byte
    // Space
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0020));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    // BX += 2, loop
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX));
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX));
    w16(&b, &p, codegen.encodeAlu(.CMP, .BX, .DX));
    const fdjnz = fx.len;
    fx.emitCondJump(&b, &p, .JNZ); // JNZ fd_loop
    // Newline
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_NEWLINE));
    const fdn = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_STR
    w16(&b, &p, codegen.encodePushPop(.POP, .DX));
    w16(&b, &p, codegen.encodePushPop(.POP, .CX));
    w16(&b, &p, codegen.encodePushPop(.POP, .BX));
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));

    // SHELL
    const addr_shell: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_PROMPT));
    const fsp = fx.len;
    fx.emitJump(&b, &p, .CALL);

    const addr_poll: u16 = @intCast(p);
    // Simple UART: just read char (0 = no data)
    w32(&b, &p, codegen.encode32(.IN, .AX, 0x0000));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0000));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    const fpoll = fx.len;
    fx.emitCondJump(&b, &p, .JZ);

    // Echo char
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x000D));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    const fenter = fx.len;
    fx.emitCondJump(&b, &p, .JZ);
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0008));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    const fbs = fx.len;
    fx.emitCondJump(&b, &p, .JZ);
    const fdisp = fx.len;
    fx.emitJump(&b, &p, .JMP);

    const addr_bs: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0008));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0020));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x0000));
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0008));
    w32(&b, &p, codegen.encode32(.OUT, .AX, 0x03F8));
    const fbsback = fx.len;
    fx.emitJump(&b, &p, .JMP);

    fx.patch(&b, fsp, addr_print);
    fx.patch(&b, fpoll, addr_poll);
    fx.patch(&b, fenter, addr_shell);
    fx.patch(&b, fbs, addr_bs);
    fx.patch(&b, fbsback, addr_poll);

    // DISPATCH
    const addr_dispatch: u16 = @intCast(p);
    const fh = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0068));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    const fc = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0063));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    const fr = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0072));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    const fi2 = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0069));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check 'd' (0x64)
    const fd = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0064));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check 'x' (0x78)
    const fx2 = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0078));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    const funknown = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // HANDLERS
    const addr_help: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_HELP));
    const fhp = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fhb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    const addr_clear: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_CLEAR));
    const fcp = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fcb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    const addr_reboot: u16 = @intCast(p);
    const frb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    const addr_info: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_INFO));
    const fip = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fib = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // Dump handler
    const addr_dump_cmd: u16 = @intCast(p);
    const fdcp = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL DUMP_MEM
    const fdcb = fx.len;
    fx.emitJump(&b, &p, .JMP); // JMP shell

    // Halt handler
    const addr_halt: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.HLT, .AX, .AX, .RegReg));

    // PATCH ALL
    fx.patch(&b, fi, addr_init);
    fx.patch(&b, fp, addr_print);
    fx.patch(&b, fs, addr_shell);
    fx.patch(&b, fdisp, addr_dispatch);
    fx.patch(&b, fh, addr_help);
    fx.patch(&b, fc, addr_clear);
    fx.patch(&b, fr, addr_reboot);
    fx.patch(&b, fi2, addr_info);
    fx.patch(&b, fd, addr_dump_cmd);
    fx.patch(&b, fx2, addr_halt);
    fx.patch(&b, funknown, addr_shell);
    fx.patch(&b, fhp, addr_print);
    fx.patch(&b, fhb, addr_shell);
    fx.patch(&b, fcp, addr_print);
    fx.patch(&b, fcb, addr_shell);
    fx.patch(&b, frb, 0x0000);
    fx.patch(&b, fip, addr_print);
    fx.patch(&b, fib, addr_shell);
    fx.patch(&b, fdcp, addr_dump);
    fx.patch(&b, fdcb, addr_shell);
    fx.patch(&b, fdh, addr_print);
    fx.patch(&b, fdh1, addr_hex);
    fx.patch(&b, fdh2, addr_hex);
    fx.patch(&b, fdjnz, fd_loop);
    fx.patch(&b, fdn, addr_print);

    return b;
}
