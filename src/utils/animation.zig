const std = @import("std");
const terminal = @import("terminal.zig");
const Color = terminal.Color;
const printColored = terminal.printColored;

/// Represents an animation, encapsulating its properties and behavior.
/// Use this struct to manage animation state and logic within your application.
pub const Animation = struct {
    stop_animation: *std.atomic.Value(bool),
    status: *std.atomic.Value(i32),
    status_buffer: []const u8,

    const Self = @This();

    pub fn init(stop_animation: *std.atomic.Value(bool), status: *std.atomic.Value(i32)) Self {
        return Self{ .stop_animation = stop_animation, .status = status, .status_buffer = undefined };
    }

    pub const Status = enum(i32) { loading = 0, success = 1, failed = 2 };

    /// Displays a spinning animation alongside the provided message.
    /// This function is typically used to indicate ongoing processing or loading.
    ///
    /// - `message`: The message to display next to the spinner.
    pub fn spin(self: *Self, message: []const u8) void {
        const spinner_chars = [_]u8{ '|', '/', '-', '\\' };
        const success_icon = "✅ ";
        const error_icon = "❌ ";
        var i: usize = 0;

        while (!self.stop_animation.load(.seq_cst)) {
            switch (self.status.load(.seq_cst)) {
                @intFromEnum(Status.loading) => {
                    std.debug.print("\r{c} {s}...", .{ spinner_chars[i % spinner_chars.len], message });
                    std.time.sleep(100 * 1000000);
                    i += 1;
                },
                @intFromEnum(Status.success) => {
                    std.debug.print("\r{s} {s}\n", .{ success_icon, message });
                    return;
                },
                @intFromEnum(Status.failed) => {
                    std.debug.print("\r{s} {s}\n", .{ error_icon, message });
                    return;
                },
                else => unreachable,
            }
        }

        switch (self.status.load(.seq_cst)) {
            @intFromEnum(Status.success) => {
                printColored(.green, "\r{s} {s}\n", .{ success_icon, self.status_buffer });
                return;
            },
            @intFromEnum(Status.failed) => {
                printColored(.green, "\r{s} {s}\n", .{ error_icon, self.status_buffer });
                return;
            },
            else => unreachable,
        }
    }
    /// Sets the current status and associated message for the animation.
    ///
    /// - `status`: The new status to set.
    /// - `message`: A string message describing the status.
    ///
    /// This function updates the internal status and message fields of the animation.
    pub fn setStatus(self: *Self, status: Status, message: []const u8) void {
        self.status_buffer = message;
        self.status.store(@intFromEnum(status), .seq_cst);
    }
};

pub fn write(text: []const u8, delay: u64) void {
    var i: usize = 0;

    const stdout = std.io.getStdOut().writer();

    while (i < text.len) {
        _ = stdout.print("\r{s}", .{text[0 .. i + 1]}) catch {};

        i += 1;

        std.time.sleep(delay * std.time.ns_per_ms);
    }
    _ = stdout.print("\n", .{}) catch {};
}

pub fn progressBar(delay: u64, message: []const u8) void {
    var i: u8 = 0;

    const stdout = std.io.getStdOut().writer();

    while (i < 101) {
        var bar: [50]u8 = [_]u8{' '} ** 50;

        for (0..@divTrunc(i, 2)) |j| {
            bar[j] = '=';
        }

        _ = stdout.print("\r{s}: {d}% [{s}]", .{ message, i, bar }) catch {};

        i += 1;

        std.time.sleep(delay * std.time.ns_per_ms);
    }
    _ = stdout.print("\n", .{}) catch {};
}
