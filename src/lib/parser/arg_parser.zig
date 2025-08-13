const std = @import("std");

const ArgParserError = error{MissingValue};

/// Returns a generic argument parser type for the given struct `T`.
/// The returned type provides functionality to parse command-line arguments
/// and populate an instance of `T` with the parsed values.
///
/// - `T`: The struct type that defines the expected arguments and their types.
///
/// Usage:
/// ```zig
/// const Parser = ArgParser(std.StringHashMap([]const u8));
/// ```
///
/// This function is typically used to create a parser tailored to your
/// application's argument structure.
pub fn ArgParser(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        args: [][:0]u8,

        /// Initializes a new instance of `Self` using the provided allocator and argument list.
        ///
        /// - `allocator`: The memory allocator to use for internal allocations.
        /// - `args`: A slice of null-terminated argument strings to be parsed.
        ///
        /// Returns: An initialized `Self` instance on success, or an error if initialization fails.
        pub fn init(allocator: std.mem.Allocator, args: [][:0]u8) !Self {
            return Self{ .allocator = allocator, .args = args };
        }

        pub fn deinit(self: *Self) void {
            std.process.argsFree(self.allocator, self.args);
        }

        /// Parses the arguments and returns a value of type `T`.
        ///
        /// Returns:
        ///   - `T`: The parsed value.
        ///   - Error: If parsing fails, an error is returned.
        ///
        /// Usage:
        ///   Call this function on an instance of `Self` to parse the arguments.
        ///
        /// Errors:
        ///   This function may return an error if the arguments cannot be parsed successfully.
        pub fn parse(self: *Self, bool_option_indices: []const usize, command: anytype) !T {
            var result: T = T.init(self.allocator);

            var i: usize = 0;
            while (i < self.args.len) {
                const arg = std.mem.sliceTo(self.args[i], 0);
                // Handle both long (--flag) and short (-f) flags
                if (std.mem.startsWith(u8, arg, "--") or (std.mem.startsWith(u8, arg, "-") and arg.len > 1 and arg[1] != '-')) {
                    var key: []const u8 = undefined;
                    var option_key: []const u8 = undefined;

                    if (std.mem.startsWith(u8, arg, "--")) {
                        key = arg[2..];
                        option_key = key;
                    } else {
                        // Short flag: find the corresponding long flag name
                        key = arg;
                        option_key = self.findLongFlagForShort(arg, command) orelse key[1..];
                    }

                    // Check if this is a boolean option by matching against the actual flag
                    var is_bool: bool = false;
                    if (command.options) |options| {
                        for (options, 0..options.len) |option, idx| {
                            if (option.matchesFlag(key)) {
                                // Check if this option index is in bool_option_indices
                                for (bool_option_indices) |bool_idx| {
                                    if (bool_idx == idx) {
                                        is_bool = true;
                                        break;
                                    }
                                }
                                break;
                            }
                        }
                    }

                    if (is_bool) {
                        try result.put(option_key, "true");
                        i += 1;
                    } else if (i + 1 >= self.args.len) {
                        return ArgParserError.MissingValue;
                    } else {
                        const value = std.mem.sliceTo(self.args[i + 1], 0);
                        try result.put(option_key, value);
                        i += 2;
                    }
                } else {
                    i += 1;
                }
            }

            return result;
        }

        /// Find the long flag name for a given short flag
        fn findLongFlagForShort(self: *Self, short_flag: []const u8, command: anytype) ?[]const u8 {
            _ = self;
            if (command.options) |options| {
                for (options) |option| {
                    if (option.short) |short| {
                        if (std.mem.eql(u8, short_flag, short)) {
                            // Return the long flag without the "--" prefix
                            return option.long[2..];
                        }
                    }
                }
            }
            return null;
        }
    };
}
