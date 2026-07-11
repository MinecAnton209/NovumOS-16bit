const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Disassembler = @import("disasm.zig").Disassembler;
const Term = @import("term.zig").Term;
const config = @import("config");

const Args = struct {
    firmware: []const u8 = "build/firmware.bin",
    max_cycles: u32 = 1000,
    debug: bool = false,
    disasm: bool = false,
    dump_addr: ?u16 = null,
    dump_end: ?u16 = null,
    quiet: bool = false,
    interactive: bool = false,
};

fn printUsage() void {
    const usage =
        \\NovumOS-16bit CPU Emulator
        \\
        \\Usage: emulator [options]
        \\
        \\Options:
        \\  -f, --firmware <path>   Path to firmware binary (default: build/firmware.bin)
        \\  -i, --interactive       Interactive mode — use emulator as a PC (terminal + keyboard)
        \\  -c, --cycles <n>        Maximum execution cycles (default: 1000, ignored with -i)
        \\  -d, --debug             Enable debug mode (step through instructions)
        \\  -a, --disasm            Disassemble firmware before execution
        \\  -m, --dump <addr>       Dump memory at address (hex, e.g. 0x0000)
        \\  -e, --dump-end <addr>   End address for memory dump range
        \\  -q, --quiet             Suppress non-essential output
        \\  -h, --help              Show this help message
        \\
        \\Examples:
        \\  emulator -i                       Interactive mode (use as PC)
        \\  emulator -i -f kernel.bin         Interactive with custom firmware
        \\  emulator                          Batch mode (run 1000 cycles)
        \\  emulator -c 50000 -a             Disassemble + run 50000 cycles
        \\
    ;
    std.debug.print("{s}", .{usage});
}

fn parseArgs(init: std.process.Init) Args {
    const arena: std.mem.Allocator = init.arena.allocator();
    const args = init.minimal.args.toSlice(arena) catch return Args{};

    var result = Args{};
    var i: usize = 1;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--firmware")) {
            i += 1;
            if (i < args.len) result.firmware = args[i];
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interactive")) {
            result.interactive = true;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--cycles")) {
            i += 1;
            if (i < args.len) {
                result.max_cycles = std.fmt.parseInt(u32, args[i], 10) catch 1000;
            }
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--debug")) {
            result.debug = true;
        } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--disasm")) {
            result.disasm = true;
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--dump")) {
            i += 1;
            if (i < args.len) {
                result.dump_addr = std.fmt.parseInt(u16, args[i], 16) catch null;
            }
        } else if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--dump-end")) {
            i += 1;
            if (i < args.len) {
                result.dump_end = std.fmt.parseInt(u16, args[i], 16) catch null;
            }
        } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
            result.quiet = true;
        }
    }

    return result;
}

fn dumpMemory(memory: []const u8, start: u16, end: u16) void {
    std.debug.print("\nMemory dump [0x{X:0>4} - 0x{X:0>4}]:\n", .{ start, end });
    var addr = start;
    while (addr < end) : (addr +%= 16) {
        std.debug.print("  0x{X:0>4}: ", .{addr});
        var j: u16 = 0;
        while (j < 16 and addr +% j < end) : (j += 1) {
            std.debug.print("{X:0>2} ", .{memory[addr +% j]});
        }
        while (j < 16) : (j += 1) {
            std.debug.print("   ", .{});
        }
        std.debug.print(" |", .{});
        j = 0;
        while (j < 16 and addr +% j < end) : (j += 1) {
            const b = memory[addr +% j];
            if (b >= 0x20 and b < 0x7F) {
                std.debug.print("{c}", .{@as(u8, @intCast(b))});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("|\n", .{});
    }
}

/// Debug mode — step through instructions with trace output.
fn debugMode(cpu: *CPU, max_cycles: u32) !void {
    std.debug.print("\n=== Debug Mode ===\n", .{});
    std.debug.print("Running {d} cycles with full trace...\n\n", .{max_cycles});

    var disasm = Disassembler.init(&cpu.memory);
    var cycles: u32 = 0;
    while (!cpu.halted and cycles < max_cycles) : (cycles += 1) {
        const result = disasm.disassemble(cpu.ip);
        var len: usize = 0;
        while (len < result.text.len and result.text[len] != 0) : (len += 1) {}
        const text = if (len > 0) result.text[0..len] else "???";

        std.debug.print("[{d: >4}] 0x{X:0>4}: {s: <20} ", .{ cycles, cpu.ip, text });
        std.debug.print("AX=0x{X:0>4} BX=0x{X:0>4} CX=0x{X:0>4} DX=0x{X:0>4} SP=0x{X:0>4} FL=0x{X:0>4}\n", .{
            cpu.ax, cpu.bx, cpu.cx, cpu.dx, cpu.sp, cpu.flags,
        });

        try cpu.step();
        cpu.cycle_count += 1;
        cycles += 1;
    }

    if (cpu.halted) {
        std.debug.print("\nCPU halted after {d} cycles\n", .{cycles});
    } else if (cycles >= max_cycles) {
        std.debug.print("\nReached maximum cycles ({d})\n", .{max_cycles});
    }
}

/// Interactive mode — run as a PC with real-time terminal I/O.
fn interactiveMode(cpu: *CPU, firmware: []const u8) !void {
    var term = try Term.init();
    defer term.deinit();

    std.debug.print("\n=== Interactive Mode ===\n", .{});
    std.debug.print("Firmware: {s}\n", .{firmware});
    std.debug.print("Press Ctrl+C to exit.\n\n", .{});

    // Clear UART TX from firmware load
    cpu.flushUartTx();

    var poll_count: u32 = 0;
    var key_count: u32 = 0;
    while (!cpu.halted) {
        // Poll keyboard input (non-blocking)
        if (term.readKey()) |key| {
            key_count += 1;
            if (key.ctrl and (key.ascii == 0x03 or key.ascii == 0x1A)) {
                std.debug.print("\n[exited by user]\n", .{});
                return;
            }
            cpu.putKey(key.ascii);
            if (config.Debug.key_debug) {
                std.debug.print("[key: 0x{X:0>2} '{c}' count={d}]\n", .{ key.ascii, key.ascii, key_count });
            }
        }

        // Execute one instruction
        try cpu.step();
        cpu.cycle_count += 1;
        poll_count += 1;

        // Flush any pending UART TX output to terminal
        // (vgaPutChar mirrors port 0x10 writes to uart_tx)
        cpu.flushUartTx();

        if (config.Debug.poll_interval > 0 and poll_count % config.Debug.poll_interval == 0) {
            std.debug.print("[poll #{d} keys={d}]\n", .{ poll_count, key_count });
        }
    }

    std.debug.print("\n[CPU halted after {d} cycles]\n", .{cpu.cycle_count});
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const args = parseArgs(init);

    var cpu = CPU{};

    // Open firmware binary
    const dir = std.Io.Dir.cwd();
    const file = dir.openFile(io, args.firmware, .{}) catch |err| {
        std.debug.print("Error: cannot open firmware '{s}': {}\n", .{ args.firmware, err });
        std.debug.print("Run 'zig build kernel' to generate it, or use -f to specify a path.\n", .{});
        return err;
    };
    defer file.close(io);

    const file_size = (try file.stat(io)).size;
    if (file_size > 65536) {
        std.debug.print("Firmware too large: {d} bytes (max 65536)\n", .{file_size});
        return error.FirmwareTooLarge;
    }

    // Read firmware into CPU memory
    var buf: [4096]u8 = undefined;
    var reader = file.reader(io, &buf);
    const r = &reader.interface;
    const target = cpu.memory[0..file_size];
    try r.readSliceAll(target);

    if (!args.quiet) {
        std.debug.print("Loaded firmware: {d} bytes from '{s}'\n\n", .{ file_size, args.firmware });
    }

    // Disassemble if requested
    if (args.disasm) {
        var disasm = Disassembler.init(&cpu.memory);
        disasm.dumpDisassembly(0, @intCast(@min(file_size, 65535)));
        std.debug.print("\n", .{});
    }

    if (args.interactive) {
        // Interactive mode
        try interactiveMode(&cpu, args.firmware);
    } else if (args.debug) {
        // Debug mode
        try debugMode(&cpu, args.max_cycles);
    } else {
        // Batch mode
        const cycles = try cpu.run(args.max_cycles);

        cpu.flushUartTx();

        if (!args.quiet) {
            std.debug.print("\nExecuted {d} cycles\n\n", .{cycles});
            cpu.dumpState();
        }

        if (args.dump_addr) |start| {
            const end = args.dump_end orelse (start +% 128);
            dumpMemory(&cpu.memory, start, end);
        } else if (!args.quiet) {
            dumpMemory(&cpu.memory, 0, 128);
        }
    }
}
