const std = @import("std");
const ArgParser = @import("arg_parser.zig").ArgParser;

// Helper to build [:0]u8 slices
fn makeSentinelArg(allocator: std.mem.Allocator, str: []const u8) ![:0]u8 {
    const with_null = try std.mem.concat(allocator, u8, &[_][]const u8{ str, &[_]u8{0} });

    // Coerce to sentinel slice
    return with_null.ptr[0..with_null.len :0];
}

test "ArgParser parses arguments into StringHashMap" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const ArgsMap = std.StringHashMap([]const u8);

    // Arguments: ["--name", "John", "--age", "30"]
    var args = try allocator.alloc([:0]u8, 4);
    defer allocator.free(args);

    args[0] = try makeSentinelArg(allocator, "--name");
    args[1] = try makeSentinelArg(allocator, "John");
    args[2] = try makeSentinelArg(allocator, "--age");
    args[3] = try makeSentinelArg(allocator, "30");

    var parser = try ArgParser(ArgsMap).init(allocator, args);
    defer parser.deinit();

    var result = try parser.parse();
    defer result.deinit();

    const name = result.get("name") orelse null;
    const age = result.get("age") orelse null;

    try std.testing.expect(name != null);
    try std.testing.expect(age != null);
    try std.testing.expectEqualStrings("John", name.?);
    try std.testing.expectEqualStrings("30", age.?);
}
