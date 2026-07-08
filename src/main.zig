const std = @import("std");
const Io = std.Io;

const NovumOS_16bit = @import("NovumOS_16bit");

/// Main entry point for the NovumOS-16bit package.
///
/// This is a boilerplate entry point from `zig init`.
/// The actual OS emulator is in src/emulator/main.zig.
/// This file demonstrates basic Zig 0.16 I/O patterns.
pub fn main(init: std.process.Init) !void {
    // Print welcome message to stderr (unbuffered)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // Create an arena allocator for process-lifetime allocations
    const arena: std.mem.Allocator = init.arena.allocator();

    // Access and print command-line arguments
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // Set up stdout for application output
    // (stderr is for debug messages, stdout is for actual program output)
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // Use the NovumOS_16bit package's printAnotherMessage function
    try NovumOS_16bit.printAnotherMessage(stdout_writer);

    // Flush stdout buffer — must be done explicitly in Zig 0.16
    try stdout_writer.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Fuzz test: randomly adds/duplicates data in an ArrayList
    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
