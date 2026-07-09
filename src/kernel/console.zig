/// Simple UART console I/O for NovumOS-16bit kernel.
///
/// Provides helper functions that return instruction arrays for UART operations.
/// Used by kernel.zig to build the firmware binary.
const std = @import("std");
const ISA = @import("codegen").ISA;
const asm_ = @import("wrappers/asm.zig");

/// UART port address (simple terminal I/O)
pub const UART_DATA: u16 = 0x00;

/// Write a single character to UART TX.
/// `char_reg` = register holding the character to send.
/// Returns array of instructions.
pub fn putChar(comptime char_reg: ISA.Register) []const u32 {
    return &[_]u32{
        asm_.out(UART_DATA, char_reg),
    };
}

/// Read a single character from UART RX into `dst_reg`.
/// Returns 0 if no data available.
pub fn getChar(comptime dst_reg: ISA.Register) []const u32 {
    return &[_]u32{
        asm_.in(dst_reg, UART_DATA),
    };
}
