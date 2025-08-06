const std = @import("std");

/// Represents terminal color options for text formatting.
pub const Color = enum {
    reset,
    red,
    green,
    yellow,
    cyan,
    white,
    blue,
    bold,
    magenta,
    black,

    pub fn ansiCode(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .bold => "\x1b[1m",
        };
    }
};

const colors = std.enums.EnumMap(Color, []const u8).init(.{
    .reset = "\x1b[0m",
    .red = "\x1b[31m",
    .green = "\x1b[32m",
    .yellow = "\x1b[33m",
    .blue = "\x1b[34m",
    .cyan = "\x1b[36m",
    .white = "\x1b[37m",
    .bold = "\x1b[1m",
    .magenta = "\x1b[35m",
    .black = "\x1b[30m",
});

/// Prints formatted text with ANSI color codes to a buffer.
/// This function allows you to format a string with color information,
/// suitable for terminal output. The formatted result is written into
/// the provided buffer.
///
/// - `buf`: The buffer to write the formatted string into.
/// - `color`: The ANSI color code or color specification to apply.
/// - `fmt`: The format string.
/// - `args`: Arguments for the format string.
///
/// Returns the number of bytes written to the buffer or an error if formatting fails.
///
/// *@deprecated* - Use `printColored` instead
pub fn bufPrintC(
    text: []const u8,
    colorKeys: []const Color,
    buffer: []u8,
) !void {
    _ = text;
    _ = colorKeys;
    _ = buffer;
    @compileError("Use `printColored` instead");
}

pub fn printColored(color: Color, comptime fmt: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    _ = stdout.print("{s}" ++ fmt ++ "{s}", .{color.ansiCode()} ++ args ++ .{Color.reset.ansiCode()}) catch {};
}

pub fn printColoredInfo(color: Color, comptime fmt: []const u8, args: anytype) void {
    std.log.info("{s}" ++ fmt ++ "{s}", .{color.ansiCode()} ++ args ++ .{Color.reset.ansiCode()});
}

pub fn printError(comptime fmt: []const u8, args: anytype) void {
    std.log.err("{s}" ++ fmt ++ "{s}", .{Color.red.ansiCode()} ++ args ++ .{Color.reset.ansiCode()});
}

pub fn clearConsole() void {
    var stdout = std.io.getStdOut();
    _ = stdout.write("\x1B[2J\x1B[3J\x1B[H") catch unreachable;
}

/// Set console to UTF-8 on Windows
pub fn setWinConsole() void {
    // Define CP_UTF8 constant for Windows
    const CP_UTF8 = 65001;

    // Set console to UTF-8 on Windows
    if (@import("builtin").os.tag == .windows) {
        const windows = std.os.windows;
        _ = windows.kernel32.SetConsoleOutputCP(CP_UTF8);
    }
}

/// Reads a line of input from the terminal, optionally displaying a prompt.
/// Allocates memory for the input using the provided allocator.
///
/// - `allocator`: The allocator to use for memory allocation.
/// - `promt`: An optional prompt to display before reading input.
///
/// Returns the input as a slice of constant bytes, or an error if reading fails.
pub fn readInput(allocator: std.mem.Allocator, promt: ?[]const u8) ![]const u8 {
    var stdout = std.io.getStdOut().writer();

    if (promt) |p| {
        stdout.print("{s}: ", .{p}) catch {};
    }

    var stdin = std.io.getStdIn().reader();

    const input = stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 500) catch |err| {
        return @errorName(err);
    };
    defer allocator.free(input.?);

    if (input) |line| {
        return allocator.dupe(u8, std.mem.trim(u8, line, "\n\r"));
    } else {
        printColored(.red, "Input error. Try again.", .{});
        return "Cancelled";
    }
}

/// Reads a numeric input from the terminal, optionally displaying a prompt message.
///
/// - `promt`: An optional prompt message to display before reading input.
///
/// Returns the input as an unsigned 8-bit integer (`u8`), or an error if the input is invalid.
pub fn readInputNum(promt: ?[]const u8) !u8 {
    var stdout = std.io.getStdOut().writer();

    if (promt) |p| {
        stdout.print("{s}: ", .{p}) catch {};
    }

    var stdin = std.io.getStdIn().reader();

    var buffer: [500]u8 = undefined;

    const input = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');

    if (input) |line| {
        const trimmed = std.mem.trim(u8, line, "\n\r\t");

        return try std.fmt.parseInt(u8, trimmed, 10);
    } else {
        printColored(.red, "Input error. Try again.", .{});
        return 0;
    }
}

/// Presents a selection menu to the user with the given options and message.
///
/// - `options`: A slice of string slices representing the selectable options.
/// - `message`: A message to display to the user before showing the options.
///
/// Returns the index of the selected option on success.
/// Returns an error if the selection process fails.
pub fn select(options: []const []const u8, message: []const u8) !usize {
    var stdout = std.io.getStdOut().writer();

    stdout.print("{s}\n", .{message}) catch {};

    for (options, 0..) |option, i| {
        stdout.print("{d}. {s}\n", .{ i + 1, option });
    }

    while (true) {
        stdout.print("> ", .{}) catch {};
        var buffer: [100]u8 = undefined;

        const input = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n');

        if (input) |line| {
            const index = std.fmt.parseInt(usize, std.mem.trim(u8, line, "\r\n"), 10) catch {
                stdout.print("Invalid index. Please enter a number.\n", .{}) catch {};
                continue;
            };

            if (index > 0 and index <= options.len) {
                return index - 1;
            } else {
                stdout.print("Invalid option. Please try again.\n", .{}) catch {};
            }
        } else {
            return error.EndOfFile;
        }
    }
}

/// Prompts the user with the given `message` and waits for a confirmation input.
/// Returns `true` if the user confirms, `false` otherwise.
/// May return an error if input/output operations fail.
pub fn confirm(message: []const u8) !bool {
    var stdout = std.io.getStdOut().writer();

    stdout.print("{s} (y/n): ", .{message}) catch {};
    var buffer: [10]u8 = undefined;

    const input = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n');

    if (input) |line| {
        const trimmed = std.mem.trim(u8, line, "\r\n");
        if (std.mem.eql(u8, trimmed, "y")) {
            return true;
        } else if (std.mem.eql(u8, trimmed, "n")) {
            return false;
        } else {
            std.debug.print("Invalid input. Please enter y or n.\n", .{});
            return try confirm(message);
        }
    } else {
        return error.EndOfFile;
    }
}
