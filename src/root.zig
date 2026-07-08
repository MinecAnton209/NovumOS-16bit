//! Root module for the NovumOS-16bit package.
//! By convention, root.zig is the root source file when making a Zig package.
//! This module provides the public API exported by the package.
const std = @import("std");
const Io = std.Io;

pub const codegen = @import("codegen.zig");
pub const ISA = codegen.ISA;
pub const asm_ = @import("wrappers/asm.zig");

/// Print a help message to the given writer.
/// Uses Io.Writer for portable I/O (works with files, stdout, stderr, etc.)
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

/// Add two integers. Simple utility function for package testing.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
