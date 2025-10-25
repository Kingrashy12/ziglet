const terminal = @import("utils/terminal.zig");
const Value = @import("types.zig").Value;
const std = @import("std");

pub fn takeBool(value: Value) bool {
    if (value == .bool) {
        return value.bool;
    } else if (value == .string) {
        const string_value = value.string;

        if (std.mem.eql(u8, string_value, "true")) {
            return true;
        } else if (std.mem.eql(u8, string_value, "false")) {
            return false;
        } else {
            terminal.printError("value is not a boolean.", .{});
            std.process.exit(1);
        }
    } else {
        terminal.printError("value is not a boolean.", .{});
        std.process.exit(1);
    }
}

pub fn takeString(value: Value) []const u8 {
    if (value == .string) {
        return value.string;
    } else {
        terminal.printError("value is not a string.", .{});
        std.process.exit(1);
    }
}

pub fn takeNumber(value: Value) []const u8 {
    if (value == .number) {
        return value.number;
    } else {
        terminal.printError("value is not a number.", .{});
        std.process.exit(1);
    }
}
