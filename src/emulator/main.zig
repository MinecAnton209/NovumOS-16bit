const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Disassembler = @import("disasm.zig").Disassembler;

/// Command-line arguments for the NovumOS-16bit emulator.
const Args = struct {
    firmware: []const u8 = "build/firmware.bin",
    max_cycles: u32 = 1000,
    debug: bool = false,
    disasm: bool = false,
    dump_addr: ?u16 = null,
    dump_end: ?u16 = null,
    quiet: bool = false,
};

/// Print usage information and exit.
fn printUsage() void {
    const usage =
        \\NovumOS-16bit CPU Emulator
        \\
        \\Usage: emulator [options]
        \\
        \\Options:
        \\  -f, --firmware <path>   Path to firmware binary (default: build/firmware.bin)
        \\  -c, --cycles <n>        Maximum execution cycles (default: 1000)
        \\  -d, --debug             Enable debug mode (step through instructions)
        \\  -a, --disasm            Disassemble firmware before execution
        \\  -m, --dump <addr>       Dump memory at address (hex, e.g. 0x0000)
        \\  -e, --dump-end <addr>   End address for memory dump range
        \\  -q, --quiet             Suppress non-essential output
        \\  -h, --help              Show this help message
        \\
        \\Examples:
        \\  emulator                          Run default firmware
        \\  emulator -f mycode.bin            Run custom firmware
        \\  emulator -d                       Debug mode (step through)
        \\  emulator -a -m 0x0000 -e 0x0050   Disassemble + dump memory range
        \\
    ;
    std.debug.print("{s}", .{usage});
}

/// Parse command-line arguments into Args struct.
fn parseArgs(init: std.process.Init) Args {
    const arena: std.mem.Allocator = init.arena.allocator();
    const args = init.minimal.args.toSlice(arena) catch return Args{};

    var result = Args{};
    var i: usize = 1; // skip argv[0] (program name)

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--firmware")) {
            i += 1;
            if (i < args.len) result.firmware = args[i];
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

/// Dump a range of memory in hex format.
fn dumpMemory(memory: []const u8, start: u16, end: u16) void {
    std.debug.print("\nMemory dump [0x{X:0>4} - 0x{X:0>4}]:\n", .{ start, end });
    var addr = start;
    while (addr < end) : (addr +%= 16) {
        std.debug.print("  0x{X:0>4}: ", .{addr});

        // Hex bytes
        var j: u16 = 0;
        while (j < 16 and addr +% j < end) : (j += 1) {
            const a = addr +% j;
            std.debug.print("{X:0>2} ", .{memory[a]});
        }

        // Pad if less than 16 bytes
        while (j < 16) : (j += 1) {
            std.debug.print("   ", .{});
        }

        // ASCII representation
        std.debug.print(" |", .{});
        j = 0;
        while (j < 16 and addr +% j < end) : (j += 1) {
            const a = addr +% j;
            const b = memory[a];
            if (b >= 0x20 and b < 0x7F) {
                std.debug.print("{c}", .{@as(u8, @intCast(b))});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("|\n", .{});
    }
}

/// Debug mode — step through instructions with simple output.
/// Note: Interactive stdin input is not supported in Zig 0.16.
/// This mode runs all cycles and shows state after each instruction.
fn debugMode(cpu: *CPU, max_cycles: u32) !void {
    std.debug.print("\n=== Debug Mode ===\n", .{});
    std.debug.print("Running {d} cycles with full trace...\n\n", .{max_cycles});

    var disasm = Disassembler.init(&cpu.memory);
    var cycles: u32 = 0;
    while (!cpu.halted and cycles < max_cycles) : (cycles += 1) {
        // Show current instruction
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

/// Main entry point for the NovumOS-16bit CPU emulator.
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const args = parseArgs(init);

    var cpu = CPU{};

    // Open firmware binary from disk
    const dir = std.Io.Dir.cwd();
    const file = dir.openFile(io, args.firmware, .{}) catch |err| {
        std.debug.print("Error: cannot open firmware '{s}': {}\n", .{ args.firmware, err });
        std.debug.print("Run 'zig build firmware' to generate it, or use -f to specify a path.\n", .{});
        return err;
    };
    defer file.close(io);

    // Validate firmware size
    const file_size = (try file.stat(io)).size;
    if (file_size > 65536) {
        std.debug.print("Firmware too large: {d} bytes (max 65536)\n", .{file_size});
        return error.FirmwareTooLarge;
    }

    // Read firmware into CPU memory at address 0x0000
    var buf: [4096]u8 = undefined;
    var reader = file.reader(io, &buf);
    const r = &reader.interface;
    const target = cpu.memory[0..file_size];
    try r.readSliceAll(target);

    if (!args.quiet) {
        std.debug.print("Loaded firmware: {d} bytes from '{s}'\n\n", .{ file_size, args.firmware });
    }

    // Disassemble firmware if requested
    if (args.disasm) {
        var disasm = Disassembler.init(&cpu.memory);
        disasm.dumpDisassembly(0, @intCast(file_size));
        std.debug.print("\n", .{});
    }

    // Dump initial CPU state
    if (!args.quiet) {
        cpu.dumpState();
        std.debug.print("\n", .{});
    }

        // Debug mode or normal execution
        if (args.debug) {
            try debugMode(&cpu, args.max_cycles);
        } else {
            // Execute firmware
            const cycles = try cpu.run(args.max_cycles);

            // Print any UART output
            cpu.flushUartTx();

            if (!args.quiet) {
                std.debug.print("\nExecuted {d} cycles\n\n", .{cycles});
                cpu.dumpState();
            }

        // Dump memory at specific address if requested
        if (args.dump_addr) |start| {
            const end = args.dump_end orelse (start +% 128);
            dumpMemory(&cpu.memory, start, end);
        } else if (!args.quiet) {
            // Default: dump first 128 bytes
            dumpMemory(&cpu.memory, 0, 128);
        }
    }
}
