/// NovumOS-16bit Kernel — VGA Console + Line-Buffered Shell
///
/// Port I/O map:
///   Port 0x03 — CMD status (IN — returns command ID, clears on read)
///               0=none, 1=help, 2=clear, 3=reboot, 4=info, 5=dump, 6=halt, 7=unknown
///   Port 0x04 — Line read (IN — returns next byte from line buffer, 0=empty)
///   Port 0x10 — VGA char output (OUT AX, 0x10 — char in low byte)
///   Port 0x11 — VGA control (OUT AX, 0x11 — 0x0001=clear, 0x0002=flush)
const std = @import("std");
const codegen = @import("codegen");
const versioning = @import("versioning");

const MEM = 65536;

// String data addresses
const S_BOOT: usize = 0x1000;
const S_PROMPT: usize = 0x1024;
const S_HELP: usize = 0x1040;
const S_INFO: usize = 0x1200;
const S_DUMP_HDR: usize = 0x1300;
const S_NEWLINE: usize = 0x1380;
const HEX_TABLE: usize = 0x1800;

// I/O ports
const CMD_PORT: u16 = 0x0003;
const LINE_PORT: u16 = 0x0004;
const VGA_CHAR: u16 = 0x0010;
const VGA_CTRL: u16 = 0x0011;

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

const Fixup = struct {
    addr: u16,
    shift: u4,
};

const FixupList = struct {
    items: [256]Fixup = undefined,
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

    // ── String Data ──
    writeStr(&b, S_BOOT, versioning.NOVUMOS_FULL ++ "\r\n");
    writeStr(&b, S_PROMPT, "> ");
    writeStr(&b, S_HELP,
        \\Commands:
        \\  help    -- show this help
        \\  clear   -- clear screen
        \\  reboot  -- restart system
        \\  info    -- show system info
        \\  dump    -- hex dump of memory
        \\  halt    -- halt CPU
        \\
    );
    writeStr(&b, S_INFO, versioning.NOVUMOS_FULL ++ "\r\nCPU: 16-bit NAND-core\r\nRAM: 64KB\r\nVGA: port 0x10\r\nKBD: port 0x02\r\n");
    writeStr(&b, S_DUMP_HDR, "\r\n[MEM 0x0000]\r\n");
    writeStr(&b, S_NEWLINE, "\r\n");
    writeStr(&b, HEX_TABLE, "0123456789ABCDEF");

    // =====================================================================
    // BOOTLOADER
    // =====================================================================
    p = 0;
    w16(&b, &p, codegen.encodeAlu(.XOR, .AX, .AX));
    w16(&b, &p, codegen.encode16(.MOV, .BX, .AX, .RegReg));
    w16(&b, &p, codegen.encode16(.MOV, .CX, .AX, .RegReg));
    w16(&b, &p, codegen.encode16(.MOV, .DX, .AX, .RegReg));

    // Print boot message
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_BOOT));
    const fp_boot_print = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fp_boot_shell = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // =====================================================================
    // PRINT_STR — print null-terminated string at [BX]
    // =====================================================================
    const addr_print: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect)); // AX = [BX]
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX)); // mask to byte
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0000));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX)); // null?
    const fp_print_end = fx.len;
    fx.emitCondJump(&b, &p, .JZ); // → addr_print_ret
    // OUT char to VGA
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CHAR));
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX)); // next byte
    const fp_print_loop = fx.len;
    fx.emitJump(&b, &p, .JMP); // → addr_print
    const addr_print_ret: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));
    w16(&b, &p, 0x0000); // NOP guard

    // =====================================================================
    // VGA_CLEAR — clear screen (OUT 1 to VGA_CTRL)
    // =====================================================================
    const addr_vga_clear: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0001));
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CTRL));
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));
    w16(&b, &p, 0x0000); // NOP guard

    // =====================================================================
    // PRINT_HEX_BYTE — print byte in AX as 2 hex chars. Clobbers CX.
    // =====================================================================
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
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CHAR));
    // Low nibble: AND AX, 0x000F
    w16(&b, &p, codegen.encode16(.MOV, .AX, .DX, .RegReg));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x000F));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.MOV, .BX, HEX_TABLE));
    w16(&b, &p, codegen.encodeAlu(.ADD, .BX, .AX));
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CHAR));
    w16(&b, &p, codegen.encodePushPop(.POP, .DX));
    w16(&b, &p, codegen.encodePushPop(.POP, .CX));
    w16(&b, &p, codegen.encodePushPop(.POP, .BX));
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));
    w16(&b, &p, 0x0000); // NOP guard

    // =====================================================================
    // DUMP_MEM — hex dump of first 32 bytes
    // =====================================================================
    const addr_dump: u16 = @intCast(p);
    w16(&b, &p, codegen.encodePushPop(.PUSH, .BX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .CX));
    w16(&b, &p, codegen.encodePushPop(.PUSH, .DX));
    // Print header
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_DUMP_HDR));
    const fdh = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_STR
    // BX = 0x0000, DX = 0x0020
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
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CHAR));
    // Print low byte
    w16(&b, &p, codegen.encode16(.MOV, .AX, .BX, .Indirect));
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x00FF));
    w16(&b, &p, codegen.encodeAlu(.AND, .AX, .CX));
    const fdh2 = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_HEX_byte
    // Space
    w32(&b, &p, codegen.encode32(.MOV, .AX, 0x0020));
    w32(&b, &p, codegen.encode32(.OUT, .AX, VGA_CHAR));
    // BX += 2, loop
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX));
    w16(&b, &p, codegen.encodeAlu(.INC, .BX, .AX));
    w16(&b, &p, codegen.encodeAlu(.CMP, .BX, .DX));
    const fdjnz = fx.len;
    fx.emitCondJump(&b, &p, .JNZ);
    // Newline
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_NEWLINE));
    const fdn = fx.len;
    fx.emitJump(&b, &p, .CALL);
    w16(&b, &p, codegen.encodePushPop(.POP, .DX));
    w16(&b, &p, codegen.encodePushPop(.POP, .CX));
    w16(&b, &p, codegen.encodePushPop(.POP, .BX));
    w16(&b, &p, codegen.encode16(.RET, .AX, .AX, .RegReg));
    w16(&b, &p, 0x0000); // NOP guard

    // =====================================================================
    // SHELL — poll port 0x03 for command ID, dispatch
    // =====================================================================
    const addr_shell: u16 = @intCast(p);
    // Print prompt
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_PROMPT));
    const fsp = fx.len;
    fx.emitJump(&b, &p, .CALL); // CALL PRINT_STR

    // Poll for command
    const addr_poll: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.IN, .AX, CMD_PORT)); // AX = cmd_id
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0000));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    const fpoll = fx.len;
    fx.emitCondJump(&b, &p, .JZ); // if 0, keep polling

    // Dispatch: 1=help, 2=clear, 3=reboot, 4=info, 5=dump, 6=halt, 7=unknown

    // Check help (1)
    const fh = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0001));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check clear (2)
    const fc = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0002));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check reboot (3)
    const fr = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0003));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check info (4)
    const fi = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0004));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check dump (5)
    const fd = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0005));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Check halt (6)
    const fxh = fx.len;
    w32(&b, &p, codegen.encode32(.MOV, .CX, 0x0006));
    w16(&b, &p, codegen.encodeAlu(.CMP, .AX, .CX));
    fx.emitCondJump(&b, &p, .JZ);
    // Unknown (7) → re-prompt
    const funknown = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // ── Command Handlers ──

    // help (1) — print help text, re-prompt
    const addr_help: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_HELP));
    const fhp = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fhb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // clear (2) — clear VGA, re-prompt
    const addr_clear: u16 = @intCast(p);
    const fcc = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fcb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // reboot (3) — jump to 0x0000
    const addr_reboot: u16 = @intCast(p);
    const frb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // info (4) — print info text, re-prompt
    const addr_info: u16 = @intCast(p);
    w32(&b, &p, codegen.encode32(.MOV, .BX, S_INFO));
    const fip = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fib = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // dump (5) — hex dump, re-prompt
    const addr_dump_cmd: u16 = @intCast(p);
    const fdcp = fx.len;
    fx.emitJump(&b, &p, .CALL);
    const fdcb = fx.len;
    fx.emitJump(&b, &p, .JMP);

    // halt (6) — halt CPU
    const addr_halt: u16 = @intCast(p);
    w16(&b, &p, codegen.encode16(.HLT, .AX, .AX, .RegReg));

    // =====================================================================
    // PATCH ALL FIXUPS
    // =====================================================================
    // Boot
    fx.patch(&b, fp_boot_print, addr_print);
    fx.patch(&b, fp_boot_shell, addr_shell);
    // Shell
    fx.patch(&b, fsp, addr_print);
    fx.patch(&b, fpoll, addr_poll);
    // Dispatch
    fx.patch(&b, fh, addr_help);
    fx.patch(&b, fc, addr_clear);
    fx.patch(&b, fr, addr_reboot);
    fx.patch(&b, fi, addr_info);
    fx.patch(&b, fd, addr_dump_cmd);
    fx.patch(&b, fxh, addr_halt);
    fx.patch(&b, funknown, addr_shell);
    // Handlers
    fx.patch(&b, fhp, addr_print);
    fx.patch(&b, fhb, addr_shell);
    fx.patch(&b, fcc, addr_vga_clear);
    fx.patch(&b, fcb, addr_shell);
    fx.patch(&b, frb, 0x0000);
    fx.patch(&b, fip, addr_print);
    fx.patch(&b, fib, addr_shell);
    fx.patch(&b, fdcp, addr_dump);
    fx.patch(&b, fdcb, addr_shell);
    // PRINT_STR
    fx.patch(&b, fp_print_end, addr_print_ret);
    fx.patch(&b, fp_print_loop, addr_print);
    // DUMP_MEM
    fx.patch(&b, fdh, addr_print);
    fx.patch(&b, fdh1, addr_hex);
    fx.patch(&b, fdh2, addr_hex);
    fx.patch(&b, fdjnz, fd_loop);
    fx.patch(&b, fdn, addr_print);

    return b;
}
