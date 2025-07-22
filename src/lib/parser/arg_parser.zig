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
                if (std.mem.startsWith(u8, arg, "--")) {
                    const key = arg[2..];

                    // Check if this is a boolean option
                    var is_bool: bool = false;
                    for (bool_option_indices) |idx| {
                        if (command.options != null and i == idx) {
                            is_bool = true;
                            break;
                        }
                    }

                    if (is_bool) {
                        try result.put(key, "true");
                        i += 1;
                    } else if (i + 1 >= self.args.len) {
                        return ArgParserError.MissingValue;
                    } else {
                        const value = std.mem.sliceTo(self.args[i + 1], 0);
                        try result.put(key, value);
                        i += 2;
                    }
                } else {
                    i += 1;
                }
            }

            return result;
        }
    };
}
