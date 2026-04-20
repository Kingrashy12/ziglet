const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Color = @import("color.zig");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    var stdout = &stdout_writer.interface;

    stdout.print(fmt, args) catch |err| {
        std.log.err("Failed to write to stdout: {s}\n", .{@errorName(err)});
    };

    defer stdout.flush() catch |err| {
        std.log.err("Failed to flush: {s}\n", .{@errorName(err)});
    };
}

/// Prints colored text to the terminal
/// - `styles`: Array of color styles to apply
/// - `fmt`: Format string
/// - `args`: Arguments for the format string
///
/// ### Example
/// ```zig
/// printColored(&[_]Color.Style{.red, .bold}, "Hello, {s}!", .{"World"});
/// ```
pub fn printColored(styles: []const Color.Style, comptime fmt: []const u8, args: anytype) void {
    const allocator = std.heap.page_allocator;

    const text = std.fmt.allocPrint(allocator, fmt, args) catch fmt;
    defer allocator.free(text);

    var r = Color.colored(allocator, text, styles) catch unreachable;
    defer r.instance.deinit();

    print("{s}", .{r.result});
}

pub fn clearConsole() void {
    print("\x1B[2J\x1B[3J\x1B[H", .{});
}

pub fn hideCursor() void {
    print("\x1b[?25l", .{});
}

pub fn showCursor() void {
    print("\x1b[?25h", .{});
}

pub fn clearLine() void {
    print("\x1b[2K\r", .{});
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
/// - `prompt`: An optional prompt to display before reading input.
///
/// Returns the input as a slice of constant bytes, or an error if reading fails.
/// Caller owns the returned memory
pub fn readInput(allocator: std.mem.Allocator, prompt: ?[]const u8) ![]const u8 {
    if (prompt) |p| {
        std.debug.print("{s}", .{p});
    }

    const slice = try readLine(allocator, 100, false);
    defer allocator.free(slice);

    return allocator.dupe(u8, std.mem.trim(u8, slice, "\n\r"));
}

/// Reads a numeric input from the terminal, optionally displaying a prompt message.
///
/// - `prompt`: An optional prompt message to display before reading input.
///
/// Returns the input as an unsigned 8-bit integer (`u8`)
pub fn readInputNum(allocator: Allocator, prompt: ?[]const u8) !u8 {
    if (prompt) |p| {
        std.debug.print("{s}", .{p});
    }

    const slice = try readLine(allocator, 10, false);
    defer allocator.free(slice);

    return try std.fmt.parseInt(u8, slice, 10);
}

/// Presents a selection menu to the user with the given options and message.
///
/// - `options`: A slice of string slices representing the selectable options.
/// - `message`: A message to display to the user before showing the options.
///
/// Returns the index of the selected option on success.
/// Returns an error if the selection process fails.
pub fn select(allocator: Allocator, options: []const []const u8, message: []const u8) !usize {
    std.debug.print("{s}\n", .{message});

    for (options, 0..) |option, i| {
        std.debug.print("{d}. {s}\n", .{ i + 1, option });
    }

    while (true) {
        std.debug.print("> ", .{});

        const slice = try readLine(allocator, 10, false);
        defer allocator.free(slice);

        const index = std.fmt.parseInt(usize, slice, 10) catch {
            std.debug.print("Invalid index. Please enter a number.\n", .{});
            continue;
        };

        if (index > 0 and index <= options.len) {
            return index - 1;
        } else {
            std.debug.print("Invalid option. Please try again.\n", .{});
        }
    }
}

/// Prompts the user with the given `message` and waits for a confirmation input.
/// Returns `true` if the user confirms, `false` otherwise.
/// May return an error if input/output operations fail.
pub fn confirm(allocator: Allocator, message: []const u8) !bool {
    std.debug.print("{s} (y/n): ", .{message});

    const slice = try readLine(allocator, 10, true);
    defer allocator.free(slice);

    if (std.mem.eql(u8, slice, "y")) {
        return true;
    } else if (std.mem.eql(u8, slice, "n")) {
        return false;
    } else {
        std.debug.print("Invalid input. Please enter y or n.\n", .{});
        return try confirm(allocator, message);
    }
}

/// Reads input from stdin, filtering out non-alphanumeric characters and spaces.
///
/// - `allocator`: The allocator to use for memory allocation.
/// - `max_size`: The maximum size of input to read.
///
/// Caller owns the returned memory
pub fn readLine(allocator: std.mem.Allocator, comptime max_size: usize, to_lower: bool) ![]const u8 {
    var stdin_buffer: [max_size]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    const line = try stdin.takeDelimiterExclusive('\n');

    var filtered_list: std.ArrayList(u8) = .empty;

    for (line) |char| {
        switch (char) {
            '@', '-', ' ', '0'...'9', 'A'...'Z', 'a'...'z', '_', '/', '\\', '#', '$', '.', '^', '%', '!', '*', '+', ',', ';', '~', '`', '=', '(', ')', '?', '>', '<', '[', ']' => {
                const c = if (to_lower) std.ascii.toLower(char) else char;
                try filtered_list.append(allocator, c);
            },
            else => {},
        }
    }

    return try filtered_list.toOwnedSlice(allocator);
}

pub fn stripAnsi(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;

    while (i < input.len) {
        if (input[i] == 0x1b and i + 1 < input.len and input[i + 1] == '[') {
            i += 2;
            while (i < input.len and input[i] != 'm') i += 1;
            i += 1;
        } else {
            try out.append(allocator, input[i]);
            i += 1;
        }
    }
    return out.toOwnedSlice(allocator);
}
