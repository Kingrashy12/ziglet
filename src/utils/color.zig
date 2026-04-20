//! Utility functions for printing colored text to the terminal.
//!
//! ### Usage examples:
//!
//! ```zig
//! var color = Color.init(allocator);
//! defer color.deinit();
//!
//! // Method chaining
//! const styled = try color.bold().cyan().underline().paint("Hello World");
//!
//! // Or using the colored helper
//! var red_text = try Color.colored(allocator, "Error!", .{Color.red, Color.bold});
//! defer red_text.instance.deinit();
//!
//! // Background + foreground
//! const highlighted = try color.bgYellow().black().paint("Warning");
//! ```
//!
const std = @import("std");

codes: std.ArrayList(u8),
allocator: std.mem.Allocator,
// Store allocated strings to prevent use-after-free
buckets: std.ArrayList([]u8),

const Self = @This();

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .codes = .empty,
        .allocator = allocator,
        .buckets = .empty,
    };
}

pub fn deinit(self: *Self) void {
    self.codes.deinit(self.allocator);
    for (self.buckets.items) |bucket| {
        self.allocator.free(bucket);
    }
    self.buckets.deinit(self.allocator);
}

fn addCode(self: *Self, code: []const u8) *Self {
    if (self.codes.items.len > 0) {
        self.codes.appendSlice(self.allocator, ";") catch {};
    }
    self.codes.appendSlice(self.allocator, code) catch {};
    return self;
}

// Style methods - each returns *Color for chaining
pub fn reset(self: *Self) *Self {
    self.codes.clearRetainingCapacity();
    return self;
}

pub fn bold(self: *Self) *Self {
    return self.addCode("1");
}

pub fn dim(self: *Self) *Self {
    return self.addCode("2");
}

pub fn italic(self: *Self) *Self {
    return self.addCode("3");
}

pub fn underline(self: *Self) *Self {
    return self.addCode("4");
}

pub fn blink(self: *Self) *Self {
    return self.addCode("5");
}

pub fn rapidBlink(self: *Self) *Self {
    return self.addCode("6");
}

pub fn reverse(self: *Self) *Self {
    return self.addCode("7");
}

pub fn hidden(self: *Self) *Self {
    return self.addCode("8");
}

pub fn strikethrough(self: *Self) *Self {
    return self.addCode("9");
}

// Foreground colors
pub fn black(self: *Self) *Self {
    return self.addCode("30");
}

pub fn red(self: *Self) *Self {
    return self.addCode("31");
}

pub fn green(self: *Self) *Self {
    return self.addCode("32");
}

pub fn yellow(self: *Self) *Self {
    return self.addCode("33");
}

pub fn blue(self: *Self) *Self {
    return self.addCode("34");
}

pub fn magenta(self: *Self) *Self {
    return self.addCode("35");
}

pub fn cyan(self: *Self) *Self {
    return self.addCode("36");
}

pub fn white(self: *Self) *Self {
    return self.addCode("37");
}

pub fn gray(self: *Self) *Self {
    return self.addCode("90");
}

pub fn redBright(self: *Self) *Self {
    return self.addCode("91");
}

pub fn greenBright(self: *Self) *Self {
    return self.addCode("92");
}

pub fn yellowBright(self: *Self) *Self {
    return self.addCode("93");
}

pub fn blueBright(self: *Self) *Self {
    return self.addCode("94");
}

pub fn magentaBright(self: *Self) *Self {
    return self.addCode("95");
}

pub fn cyanBright(self: *Self) *Self {
    return self.addCode("96");
}

pub fn whiteBright(self: *Self) *Self {
    return self.addCode("97");
}

// Background colors
pub fn bgBlack(self: *Self) *Self {
    return self.addCode("40");
}

pub fn bgRed(self: *Self) *Self {
    return self.addCode("41");
}

pub fn bgGreen(self: *Self) *Self {
    return self.addCode("42");
}

pub fn bgYellow(self: *Self) *Self {
    return self.addCode("43");
}

pub fn bgBlue(self: *Self) *Self {
    return self.addCode("44");
}

pub fn bgMagenta(self: *Self) *Self {
    return self.addCode("45");
}

pub fn bgCyan(self: *Self) *Self {
    return self.addCode("46");
}

pub fn bgWhite(self: *Self) *Self {
    return self.addCode("47");
}

pub fn bgGray(self: *Self) *Self {
    return self.addCode("100");
}

pub fn bgRedBright(self: *Self) *Self {
    return self.addCode("101");
}

pub fn bgGreenBright(self: *Self) *Self {
    return self.addCode("102");
}

pub fn bgYellowBright(self: *Self) *Self {
    return self.addCode("103");
}

pub fn bgBlueBright(self: *Self) *Self {
    return self.addCode("104");
}

pub fn bgMagentaBright(self: *Self) *Self {
    return self.addCode("105");
}

pub fn bgCyanBright(self: *Self) *Self {
    return self.addCode("106");
}

pub fn bgWhiteBright(self: *Self) *Self {
    return self.addCode("107");
}

/// Apply the accumulated styles to text
pub fn paint(self: *Self, text: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(self.allocator);

    try result.appendSlice(self.allocator, "\x1b[");
    try result.appendSlice(self.allocator, self.codes.items);
    try result.appendSlice(self.allocator, "m");
    try result.appendSlice(self.allocator, text);
    try result.appendSlice(self.allocator, "\x1b[0m");

    const painted = try result.toOwnedSlice(self.allocator);
    try self.buckets.append(self.allocator, painted);
    return painted;
}

/// Get the ANSI code string without painting
///
/// Caller must free the returned memory
pub fn ansiCode(self: *Self) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(self.allocator);

    try result.appendSlice(self.allocator, "\x1b[");
    try result.appendSlice(self.allocator, self.codes.items);
    try result.appendSlice(self.allocator, "m");

    return try result.toOwnedSlice(self.allocator);
}

/// Helper to create colored text with one call
///
/// * `allocator` - The allocator to use for memory allocation
/// * `text` - The text to color
/// * `styles` - A slice of Style enum values to apply
///
/// ### Usage
///
/// ```zig
/// var colored_text = try Color.colored(allocator, "Error!", &[_]Style{.red, .bold});
/// defer colored_text.deinit();
/// std.debug.print("{s}\n", .{colored_text.result});
/// ```
///
/// Caller must call deinit on the returned Colored instance
pub fn colored(allocator: std.mem.Allocator, text: []const u8, styles: []const Style) !Colored {
    var color = Self.init(allocator);

    // Apply all styles
    for (styles) |style| {
        _ = style.getStyle()(&color);
    }

    const painted = try color.paint(text);

    return Colored{
        .result = painted,
        .instance = color,
    };
}

/// Helper to create colored text with formatting arguments
///
/// * `allocator` - The allocator to use for memory allocation
/// * `text` - The text to color (can contain format specifiers like {s}, {d}, etc.)
/// * `styles` - A slice of Style enum values to apply
/// * `args` - Arguments to format into the text
///
/// ### Usage
///
/// ```zig
/// var colored_text = try Color.coloredWithArgs(allocator, "Error: {s}", &[_]Style{.red, .bold}, .{"Something went wrong"});
/// defer colored_text.deinit();
/// std.debug.print("{s}\n", .{colored_text.result});
/// ```
///
/// Caller must call deinit on the returned Colored instance
pub fn coloredWithArgs(allocator: std.mem.Allocator, comptime text: []const u8, styles: []const Style, args: anytype) !Colored {
    var color = Self.init(allocator);

    // Apply all styles
    for (styles) |style| {
        _ = style.getStyle()(&color);
    }

    const formatted = try std.fmt.allocPrint(allocator, text, args);
    defer allocator.free(formatted);

    const painted = try color.paint(formatted);

    return Colored{
        .result = painted,
        .instance = color,
    };
}

/// A struct that holds both the colored text and the Color instance used to generate it
pub const Colored = struct {
    /// The Color instance used to generate the colored text
    instance: Self,
    /// The colored text
    result: []const u8,

    /// Deinitializes the Color instance and frees allocated memory
    pub fn deinit(self: *Colored) void {
        self.instance.deinit();
    }
};

/// Enum representing different ANSI color and style codes
pub const Style = enum {
    cyan,
    bold,
    red,
    green,
    yellow,
    blue,
    magenta,
    white,
    gray,
    red_bright,
    green_bright,
    yellow_bright,
    blue_bright,
    magenta_bright,
    cyan_bright,
    white_bright,
    underline,
    italic,
    dim,
    blink,
    reverse,
    hidden,
    strikethrough,
    // Backgrounds
    bg_black,
    bg_red,
    bg_green,
    bg_yellow,
    bg_blue,
    bg_magenta,
    bg_cyan,
    bg_white,
    bg_gray,
    bg_red_bright,
    bg_green_bright,
    bg_yellow_bright,
    bg_blue_bright,
    bg_magenta_bright,
    bg_cyan_bright,
    bg_white_bright,

    /// Returns a function that applies the style to a Color instance
    pub fn getStyle(self: Style) *const fn (*Self) *Self {
        return switch (self) {
            .cyan => struct {
                fn apply(c: *Self) *Self {
                    return c.cyan();
                }
            }.apply,
            .bold => struct {
                fn apply(c: *Self) *Self {
                    return c.bold();
                }
            }.apply,
            .red => struct {
                fn apply(c: *Self) *Self {
                    return c.red();
                }
            }.apply,
            .green => struct {
                fn apply(c: *Self) *Self {
                    return c.green();
                }
            }.apply,
            .yellow => struct {
                fn apply(c: *Self) *Self {
                    return c.yellow();
                }
            }.apply,
            .blue => struct {
                fn apply(c: *Self) *Self {
                    return c.blue();
                }
            }.apply,
            .magenta => struct {
                fn apply(c: *Self) *Self {
                    return c.magenta();
                }
            }.apply,
            .white => struct {
                fn apply(c: *Self) *Self {
                    return c.white();
                }
            }.apply,
            .gray => struct {
                fn apply(c: *Self) *Self {
                    return c.gray();
                }
            }.apply,
            .red_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.redBright();
                }
            }.apply,
            .green_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.greenBright();
                }
            }.apply,
            .yellow_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.yellowBright();
                }
            }.apply,
            .blue_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.blueBright();
                }
            }.apply,
            .magenta_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.magentaBright();
                }
            }.apply,
            .cyan_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.cyanBright();
                }
            }.apply,
            .white_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.whiteBright();
                }
            }.apply,
            .underline => struct {
                fn apply(c: *Self) *Self {
                    return c.underline();
                }
            }.apply,
            .italic => struct {
                fn apply(c: *Self) *Self {
                    return c.italic();
                }
            }.apply,
            .dim => struct {
                fn apply(c: *Self) *Self {
                    return c.dim();
                }
            }.apply,
            .blink => struct {
                fn apply(c: *Self) *Self {
                    return c.blink();
                }
            }.apply,
            .reverse => struct {
                fn apply(c: *Self) *Self {
                    return c.reverse();
                }
            }.apply,
            .hidden => struct {
                fn apply(c: *Self) *Self {
                    return c.hidden();
                }
            }.apply,
            .strikethrough => struct {
                fn apply(c: *Self) *Self {
                    return c.strikethrough();
                }
            }.apply,
            .bg_black => struct {
                fn apply(c: *Self) *Self {
                    return c.bgBlack();
                }
            }.apply,
            .bg_red => struct {
                fn apply(c: *Self) *Self {
                    return c.bgRed();
                }
            }.apply,
            .bg_green => struct {
                fn apply(c: *Self) *Self {
                    return c.bgGreen();
                }
            }.apply,
            .bg_yellow => struct {
                fn apply(c: *Self) *Self {
                    return c.bgYellow();
                }
            }.apply,
            .bg_blue => struct {
                fn apply(c: *Self) *Self {
                    return c.bgBlue();
                }
            }.apply,
            .bg_magenta => struct {
                fn apply(c: *Self) *Self {
                    return c.bgMagenta();
                }
            }.apply,
            .bg_cyan => struct {
                fn apply(c: *Self) *Self {
                    return c.bgCyan();
                }
            }.apply,
            .bg_white => struct {
                fn apply(c: *Self) *Self {
                    return c.bgWhite();
                }
            }.apply,
            .bg_gray => struct {
                fn apply(c: *Self) *Self {
                    return c.bgGray();
                }
            }.apply,
            .bg_red_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgRedBright();
                }
            }.apply,
            .bg_green_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgGreenBright();
                }
            }.apply,
            .bg_yellow_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgYellowBright();
                }
            }.apply,
            .bg_blue_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgBlueBright();
                }
            }.apply,
            .bg_magenta_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgMagentaBright();
                }
            }.apply,
            .bg_cyan_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgCyanBright();
                }
            }.apply,
            .bg_white_bright => struct {
                fn apply(c: *Self) *Self {
                    return c.bgWhiteBright();
                }
            }.apply,
        };
    }
};

/// Helper function to apply multiple styles
///
/// * `color` - The Color instance to apply styles to
/// * `styles` - A slice of Style enum values to apply
///
/// ### Usage
///
/// ```zig
/// var color = Color.init(allocator);
/// defer color.deinit();
/// _ = applyStyles(&color, &[_]Style{.cyan, .bold, .underline});
/// const styled_text = try color.paint("Hello World");
/// ```
/// ```zig
/// // Or apply one style
/// _ = Style.cyan.getStyle()(&color);
/// const styled_text = try color.paint("Hello World");
/// ```
pub fn applyStyles(color: *Self, styles: []const Style) *Self {
    for (styles) |style| {
        _ = style.getStyle()(color);
    }
    return color;
}
