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
pub fn bufPrintC(
    text: []const u8,
    colorKeys: []const Color,
    buffer: []u8,
) ![]u8 {
    var writer = std.io.fixedBufferStream(buffer);
    const stream = writer.writer();

    for (colorKeys) |key| {
        try stream.writeAll(colors.get(key).?);
    }
    try stream.writeAll(text);
    try stream.writeAll(colors.get(.reset).?);

    return writer.getWritten();
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
    if (promt) |p| {
        std.debug.print("{s}: ", .{p});
    }

    var stdin = std.io.getStdIn().reader();

    var writer = std.io.getStdOut().writer();

    const input = stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 500) catch |err| {
        return @errorName(err);
    };
    defer allocator.free(input.?);

    if (input) |line| {
        return allocator.dupe(u8, std.mem.trim(u8, line, "\n\r"));
    } else {
        var wbuffer: [100]u8 = undefined;

        try writer.print("{s} \n", .{try bufPrintC("Input error. Try again.", &[_]Color{.red}, &wbuffer)});
        return "Cancelled";
    }
}

/// Reads a numeric input from the terminal, optionally displaying a prompt message.
///
/// - `promt`: An optional prompt message to display before reading input.
///
/// Returns the input as an unsigned 8-bit integer (`u8`), or an error if the input is invalid.
pub fn readInputNum(promt: ?[]const u8) !u8 {
    if (promt) |p| {
        std.debug.print("{s}: ", .{p});
    }

    var stdin = std.io.getStdIn().reader();

    var writer = std.io.getStdOut().writer();

    var buffer: [500]u8 = undefined;

    const input = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');

    if (input) |line| {
        const trimmed = std.mem.trim(u8, line, "\n\r\t");

        return try std.fmt.parseInt(u8, trimmed, 10);
    } else {
        var wbuffer: [100]u8 = undefined;
        try writer.print("{s} \n", .{try bufPrintC("Input error. Try again.", &[_]Color{.red}, &wbuffer)});
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
    std.debug.print("{s}\n", .{message});

    for (options, 0..) |option, i| {
        std.debug.print("{d}. {s}\n", .{ i + 1, option });
    }

    while (true) {
        std.debug.print("> ", .{});
        var buffer: [100]u8 = undefined;

        const input = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n');

        if (input) |line| {
            const index = std.fmt.parseInt(usize, std.mem.trim(u8, line, "\r\n"), 10) catch {
                std.debug.print("Invalid index. Please enter a number.\n", .{});
                continue;
            };

            if (index > 0 and index <= options.len) {
                return index - 1;
            } else {
                std.debug.print("Invalid option. Please try again.\n", .{});
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
    std.debug.print("{s} (y/n): ", .{message});
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
