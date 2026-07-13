const std = @import("std");
const builtin = @import("builtin");

pub const Term = struct {
    platform: Platform,

    const Platform = if (builtin.os.tag == .windows) WindowsTerm else PosixTerm;

    pub const Key = struct {
        ascii: u8,
        ctrl: bool = false,
    };

    pub fn init() !Term {
        return .{ .platform = try Platform.init() };
    }

    pub fn deinit(self: *Term) void {
        self.platform.deinit();
    }

    pub fn readKey(self: *Term) ?Key {
        return self.platform.readKey();
    }

    pub fn readKeyBlocking(self: *Term) Key {
        return self.platform.readKeyBlocking();
    }

    /// Render VGA text buffer to terminal.
    /// Clears screen and redraws entire buffer as plain text lines.
    pub fn renderVga(self: *Term, buffer: []const u16, prev: []u16, cursor_row: u16, cursor_col: u16) void {
        _ = self;

        // Only re-render if something actually changed
        var changed = false;
        for (0..2000) |i| {
            if (buffer[i] != prev[i]) {
                changed = true;
                break;
            }
        }
        if (!changed) return;

        // Clear screen and move cursor to top-left
        std.debug.print("\x1B[2J\x1B[1;1H", .{});

        // Render 25 rows of 80 characters
        for (0..25) |row| {
            for (0..80) |col| {
                const idx = row * 80 + col;
                const ch: u8 = @intCast(buffer[idx] & 0xFF);
                if (ch >= 0x20 and ch < 0x7F) {
                    std.debug.print("{c}", .{ch});
                } else {
                    std.debug.print(" ", .{});
                }
            }
            if (row < 24) std.debug.print("\r\n", .{});
        }

        // Position cursor
        std.debug.print("\x1B[{d};{d}H", .{ cursor_row + 1, cursor_col + 1 });

        // Copy current to prev
        @memcpy(prev, buffer);
    }

    // =========================================================================
    // Windows
    // =========================================================================

    const WindowsTerm = struct {
        h_in: HANDLE,
        old_mode: u32,
        is_console: bool,

        fn init() !WindowsTerm {
            const h_in = GetStdHandle(STD_INPUT_HANDLE);

            var old_mode: u32 = 0;
            const is_console = GetConsoleMode(h_in, &old_mode) != 0;

            if (is_console) {
                const new_mode = old_mode & ~@as(u32, ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT);
                _ = SetConsoleMode(h_in, new_mode);
            }

            return .{ .h_in = h_in, .old_mode = old_mode, .is_console = is_console };
        }

        fn deinit(self: *WindowsTerm) void {
            _ = SetConsoleMode(self.h_in, self.old_mode);
        }

        fn readKey(self: *WindowsTerm) ?Key {
            if (self.is_console) {
                // Console handle: WaitForSingleObject checks if data is available non-blocking
                const result = WaitForSingleObject(self.h_in, 0);
                if (result != WAIT_OBJECT_0) return null;
            } else {
                // Pipe/file handle: PeekNamedPipe checks non-blocking
                var total: u32 = 0;
                const peek_result = PeekNamedPipe(self.h_in, null, 0, null, &total, null);
                if (peek_result == 0 or total == 0) return null;
            }

            var buf: [1]u8 = undefined;
            var n_read: u32 = 0;
            _ = ReadFile(self.h_in, &buf, 1, &n_read, null);
            if (n_read == 0) return null;
            const ch = buf[0];
            // Skip UTF-8 continuation/leading bytes (>= 0x80) — only accept ASCII
            if (ch >= 0x80) return null;
            if (ch == 0x03 or ch == 0x1A) return .{ .ascii = ch, .ctrl = true };
            return .{ .ascii = ch };
        }

        fn readKeyBlocking(self: *WindowsTerm) Key {
            _ = self;
            while (true) {
                var events_read: u32 = 0;
                var event: INPUT_RECORD = std.mem.zeroes(INPUT_RECORD);
                _ = ReadConsoleInputA(GetStdHandle(STD_INPUT_HANDLE), &event, 1, &events_read);
                if (events_read == 0) continue;
                if (event.EventType != 1) continue;
                if (event.u.KeyEvent.bKeyDown == 0) continue;
                const ch = event.u.KeyEvent.uChar.AsciiChar;
                if (ch == 0) continue;
                return .{ .ascii = ch };
            }
        }

        const INPUT_RECORD = extern struct {
            EventType: u16,
            u: extern union {
                KeyEvent: KEY_EVENT_RECORD,
                _pad: [16]u8,
            },
        };

        const KEY_EVENT_RECORD = extern struct {
            bKeyDown: i32,
            wRepeatCount: u16,
            wVirtualKeyCode: u16,
            wVirtualScanCode: u16,
            uChar: extern union {
                AsciiChar: u8,
                UnicodeChar: u16,
            },
            dwControlKeyState: u32,
        };

        const HANDLE = *anyopaque;
        const STD_INPUT_HANDLE = @as(u32, @bitCast(@as(i32, -10)));
        const ENABLE_LINE_INPUT = 0x0002;
        const ENABLE_ECHO_INPUT = 0x0004;
        const ENABLE_PROCESSED_INPUT = 0x0001;
        const WAIT_OBJECT_0 = 0;

        extern "kernel32" fn GetStdHandle(nStdHandle: u32) callconv(.winapi) HANDLE;
        extern "kernel32" fn GetConsoleMode(hConsoleHandle: HANDLE, lpMode: *u32) callconv(.winapi) i32;
        extern "kernel32" fn SetConsoleMode(hConsoleHandle: HANDLE, dwMode: u32) callconv(.winapi) i32;
        extern "kernel32" fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: u32) callconv(.winapi) u32;
        extern "kernel32" fn ReadConsoleInputA(hConsoleInput: HANDLE, lpBuffer: *INPUT_RECORD, nLength: u32, lpNumberOfEventsRead: *u32) callconv(.winapi) i32;
        extern "kernel32" fn ReadFile(hFile: HANDLE, lpBuffer: *[1]u8, nNumberOfBytesToRead: u32, lpNumberOfBytesRead: *u32, lpOverlapped: ?*anyopaque) callconv(.winapi) i32;
        extern "kernel32" fn PeekNamedPipe(hNamedPipe: HANDLE, lpBuffer: ?*anyopaque, nBufferSize: u32, lpBytesRead: ?*u32, lpTotalBytesAvail: ?*u32, lpBytesLeftThisMessage: ?*u32) callconv(.winapi) i32;
    };

    // =========================================================================
    // POSIX (Linux, macOS)
    // =========================================================================

    const PosixTerm = struct {
        fd: i32,
        old_termios: std.posix.termios,

        fn init() !PosixTerm {
            const fd = std.posix.STDIN_FILENO;
            const old = try std.posix.tcgetattr(fd);

            var raw = old;
            raw.iflag &= ~@as(u32, std.posix.BRKINT | std.posix.ICRNL | std.posix.INPCK | std.posix.ISTRIP | std.posix.IXON);
            raw.oflag &= ~@as(u32, std.posix.OPOST);
            raw.cflag |= @as(u32, std.posix.CS8);
            raw.lflag &= ~@as(u32, std.posix.ECHO | std.posix.ICANON | std.posix.IEXTEN | std.posix.ISIG);
            raw.cc[@intCast(std.posix.VMIN)] = 0;
            raw.cc[@intCast(std.posix.VTIME)] = 0;

            try std.posix.tcsetattr(fd, std.posix.TCSA.FLUSH, raw);

            const flags = try std.posix.fcntl(fd, std.posix.F.GETFL, 0);
            _ = try std.posix.fcntl(fd, std.posix.F.SETFL, flags | @as(u32, @bitCast(@as(i32, std.posix.O.NONBLOCK))));

            return .{ .fd = fd, .old_termios = old };
        }

        fn deinit(self: *PosixTerm) void {
            std.posix.tcsetattr(self.fd, std.posix.TCSA.FLUSH, self.old_termios) catch {};
            const flags = std.posix.fcntl(self.fd, std.posix.F.GETFL, 0) catch return;
            _ = std.posix.fcntl(self.fd, std.posix.F.SETFL, flags & ~@as(u32, @bitCast(@as(i32, std.posix.O.NONBLOCK)))) catch {};
        }

        fn readKey(self: *PosixTerm) ?Key {
            var buf: [1]u8 = undefined;
            const n = std.posix.read(self.fd, &buf) catch return null;
            if (n == 0) return null;
            const ch = buf[0];
            // Skip UTF-8 continuation/leading bytes (>= 0x80) — only accept ASCII
            if (ch >= 0x80) return null;
            if (ch == 0x03 or ch == 0x1A) return .{ .ascii = ch, .ctrl = true };
            return .{ .ascii = ch };
        }

        fn readKeyBlocking(self: *PosixTerm) Key {
            while (true) {
                var buf: [1]u8 = undefined;
                const n = std.posix.read(self.fd, &buf) catch {
                    std.time.sleep(10 * std.time.ns_per_ms);
                    continue;
                };
                if (n == 0) {
                    std.time.sleep(10 * std.time.ns_per_ms);
                    continue;
                }
                return .{ .ascii = buf[0] };
            }
        }
    };
};
