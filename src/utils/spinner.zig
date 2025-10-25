const std = @import("std");
const terminal = @import("terminal.zig");

pub const Spinner = struct {
    frames: []const []const u8,
    current: usize = 0,
    message: []const u8,
    timer: std.time.Timer,

    pub fn init(message: []const u8) !Spinner {
        return Spinner{
            .frames = &[_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
            .message = message,
            .timer = try std.time.Timer.start(),
            .current = 0,
        };
    }

    pub fn tick(self: *Spinner) void {
        terminal.setWinConsole();

        terminal.print("\r{s} {s}", .{ self.frames[self.current], self.message });
        self.current = (self.current + 1) % self.frames.len;

        std.time.sleep(100 * std.time.ns_per_ms);
        // std.Thread.sleep(80 * std.time.ns_per_ms);
    }

    pub fn stop(self: *Spinner, message: []const u8) void {
        terminal.setWinConsole();

        _ = self.timer.lap();
        terminal.print("\r{s}\n", .{message});
    }

    pub fn failed(self: *Spinner, message: []const u8) void {
        terminal.setWinConsole();

        _ = self.timer.lap();
        terminal.printColored(.red, "\r❌ {s}\n", .{message});
    }

    pub fn success(self: *Spinner, message: []const u8) void {
        terminal.setWinConsole();

        _ = self.timer.lap();
        terminal.printColored(.green, "\r✅ {s}\n", .{message});
    }
};
