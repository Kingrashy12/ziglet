const std = @import("std");

const Parser = @import("arg_parser.zig").ArgParser;

/// Returns the type for an argument parser.
/// This function is typically used to instantiate a parser for command-line arguments.
/// The returned type provides methods and fields for parsing and accessing arguments.
pub fn ArgParser() type {
    const ArgsMap = std.StringHashMap([]const u8);

    return Parser(ArgsMap);
}
