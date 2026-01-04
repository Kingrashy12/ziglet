const std = @import("std");

/// Formats a byte count into a human-readable string with appropriate units (e.g., KB, MB, GB).
///
/// - `bytes`: The number of bytes to format.
///
/// Returns: A string slice representing the formatted byte count.
///
/// Errors: Returns an error if memory allocation for the formatted string fails.
///
/// Caller must free the returned string.
pub fn formatBytes(allocator: std.mem.Allocator, bytes: usize) ![]const u8 {
    var buffer: [500]u8 = undefined;

    if (bytes < 1024) {
        return try allocator.dupe(u8, try std.fmt.bufPrint(buffer[0..], "{} B", .{bytes}));
    } else if (bytes < 1024 * 1024) {
        const kb: f64 = @floatFromInt(bytes);
        return try allocator.dupe(u8, try std.fmt.bufPrint(buffer[0..], "{d:.2} KB", .{kb / 1024}));
    } else if (bytes < 1024 * 1024 * 1024) {
        const mb: f64 = @floatFromInt(bytes);
        return try allocator.dupe(u8, try std.fmt.bufPrint(buffer[0..], "{d:.2} MB", .{mb / (1024 * 1024)}));
    } else {
        const gb: f64 = @floatFromInt(bytes);
        return try allocator.dupe(u8, try std.fmt.bufPrint(buffer[0..], "{d:.2} GB", .{gb / (1024 * 1024 * 1024)}));
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

pub fn formatNumber(allocator: std.mem.Allocator, n: usize, precision: usize) ![]const u8 {
    const float_n = @as(f64, @floatFromInt(n));

    if (n >= 1_000_000_000) {
        return try std.fmt.allocPrint(allocator, "{d:.[1]}B", .{ float_n / 1e9, precision });
    } else if (n >= 1_000_000) {
        return try std.fmt.allocPrint(allocator, "{d:.[1]}M", .{ float_n / 1e6, precision });
    } else if (n >= 1_000) {
        return try std.fmt.allocPrint(allocator, "{d:.[1]}K", .{ float_n / 1e3, precision });
    } else {
        return try std.fmt.allocPrint(allocator, "{d}", .{n});
    }
}

test "format number" {
    const allocator = std.testing.allocator;

    const one_k = try formatNumber(allocator, 1100, 1);
    defer allocator.free(one_k);
    try std.testing.expectEqualStrings("1.1K", one_k);

    const one_million = try formatNumber(allocator, 1100000, 1);
    defer allocator.free(one_million);
    try std.testing.expectEqualStrings("1.1M", one_million);

    const one_billion = try formatNumber(allocator, 1100000000, 1);
    defer allocator.free(one_billion);
    try std.testing.expectEqualStrings("1.1B", one_billion);

    const one_million_1 = try formatNumber(allocator, 1100000, 0);
    defer allocator.free(one_million_1);
    try std.testing.expectEqualStrings("1M", one_million_1);
}

test "format bytes" {
    const allocator = std.testing.allocator;

    const result_188 = try formatBytes(allocator, 188);
    defer allocator.free(result_188);
    const result_1887 = try formatBytes(allocator, 1887);
    defer allocator.free(result_1887);
    const result_mb = try formatBytes(allocator, 1050 * 1024);
    defer allocator.free(result_mb);
    const result_gb = try formatBytes(allocator, 1050 * 1024 * 1024);
    defer allocator.free(result_gb);

    try std.testing.expectEqualStrings("188 B", result_188);
    try std.testing.expectEqualStrings("1.84 KB", result_1887);
    try std.testing.expectEqualStrings("1.03 MB", result_mb);
    try std.testing.expectEqualStrings("1.03 GB", result_gb);
}
