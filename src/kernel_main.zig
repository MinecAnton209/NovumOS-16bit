/// Kernel firmware writer — builds kernel.bin from comptime-generated firmware.
const std = @import("std");
const kernel = @import("kernel.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.Io.Dir.cwd().createDirPath(io, "build") catch {};

    const file = try std.Io.Dir.cwd().createFile(io, "build/kernel.bin", .{});
    defer file.close(io);

    try file.writeStreamingAll(io, &kernel.kernel_firmware);
}
