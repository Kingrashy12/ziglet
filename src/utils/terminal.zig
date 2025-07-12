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
