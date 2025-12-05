const std = @import("std");

/// Formats a byte count into a human-readable string with appropriate units (e.g., KB, MB, GB).
///
/// - `bytes`: The number of bytes to format.
///
/// Returns: A string slice representing the formatted byte count.
///
/// Errors: Returns an error if memory allocation for the formatted string fails.
pub fn formatBytes(bytes: u64) ![]const u8 {
    var buffer: [500]u8 = undefined;

    if (bytes < 1024) {
        return try std.fmt.bufPrint(buffer[0..], "{} B", .{bytes});
    } else if (bytes < 1024 * 1024) {
        const kb: f64 = @floatFromInt(bytes);
        return try std.fmt.bufPrint(buffer[0..], "{d:.2} KB", .{kb / 1024});
    } else if (bytes < 1024 * 1024 * 1024) {
        const mb: f64 = @floatFromInt(bytes);
        return try std.fmt.bufPrint(buffer[0..], "{d:.2} MB", .{mb / (1024 * 1024)});
    } else {
        const gb: f64 = @floatFromInt(bytes);
        return try std.fmt.bufPrint(buffer[0..], "{d:.2} GB", .{gb / (1024 * 1024 * 1024)});
    }
}

pub fn convertNanosecondsToTime(nanoseconds: u64) struct { milliseconds: f64, seconds: f64, minutes: f64, hours: f64 } {
    const milliseconds_in_nanoseconds: u64 = 1_000_000;
    const seconds_in_nanoseconds: u64 = 1_000_000_000;
    const minutes_in_nanoseconds: u64 = 60 * seconds_in_nanoseconds;
    const hours_in_nanoseconds: u64 = 60 * minutes_in_nanoseconds;

    const milliseconds: f64 = @as(f64, @floatFromInt(nanoseconds)) / @as(f64, @floatFromInt(milliseconds_in_nanoseconds));
    const seconds: f64 = @as(f64, @floatFromInt(nanoseconds)) / @as(f64, @floatFromInt(seconds_in_nanoseconds));
    const minutes: f64 = @as(f64, @floatFromInt(nanoseconds)) / @as(f64, @floatFromInt(minutes_in_nanoseconds));
    const hours: f64 = @as(f64, @floatFromInt(nanoseconds)) / @as(f64, @floatFromInt(hours_in_nanoseconds));

    return .{ .milliseconds = milliseconds, .seconds = seconds, .minutes = minutes, .hours = hours };
}

pub fn formatNumber(allocator: std.mem.Allocator, n: usize) ![]const u8 {
    if (n >= 1_000_000_000) {
        const value = n / 1_000_000_000;
        const rem = (n % 1_000_000_000) / 100_000_000; // get 1 decimal
        return try std.fmt.allocPrint(allocator, "{d}.{d}B", .{ value, rem });
    } else if (n >= 1_000_000) {
        const value = n / 1_000_000;
        const rem = (n % 1_000_000) / 100_000; // 1 decimal
        return try std.fmt.allocPrint(allocator, "{d}.{d}M", .{ value, rem });
    } else if (n >= 1_000) {
        const value = n / 1_000;
        const rem = (n % 1_000) / 100; // 1 decimal
        return try std.fmt.allocPrint(allocator, "{d}.{d}K", .{ value, rem });
    } else {
        return try std.fmt.allocPrint(allocator, "{}", .{n});
    }
}

test "format bytes" {
    try std.testing.expectEqualStrings("188 B", try formatBytes(188));
    try std.testing.expectEqualStrings("1.84 KB", try formatBytes(1887));
    try std.testing.expectEqualStrings("1.03 MB", try formatBytes(1050 * 1024));
    try std.testing.expectEqualStrings("1.03 GB", try formatBytes(1050 * 1024 * 1024));

    const allocator = std.testing.allocator;

    const one_k = try formatNumber(allocator, 1100);
    defer allocator.free(one_k);
    const one_million = try formatNumber(allocator, 1100000);
    defer allocator.free(one_million);
    const one_billion = try formatNumber(allocator, 1100000000);
    defer allocator.free(one_billion);

    try std.testing.expectEqualStrings("1.1K", one_k);
    try std.testing.expectEqualStrings("1.1M", one_million);
    try std.testing.expectEqualStrings("1.1B", one_billion);
}
