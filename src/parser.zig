const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const CLIOption = types.CLIOption;
const CLIArgument = types.CLIArgument;
const ParsedArgs = types.ParsedArgs;
const terminal = @import("root.zig").utils.terminal;

allocator: Allocator,
optionCache: std.StringHashMap(CLIOption),

const Self = @This();

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
        .optionCache = std.StringHashMap(CLIOption).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.optionCache.deinit();
}

fn isOption(token: []const u8) bool {
    return std.mem.startsWith(u8, token, "--");
}

fn isAlias(token: []const u8) bool {
    return std.mem.startsWith(u8, token, "-") and (token.len >= 2 and token.len < 5);
}

/// Caller should free returned memory from `command`,`options`,`args`
pub fn parse(self: *Self, argv: [][:0]u8, options: []const CLIOption) !ParsedArgs {
    var parsed = ParsedArgs{
        .command = &.{},
        .options = std.StringHashMap(types.Value).init(self.allocator),
        .args = &.{},
    };

    var commands: std.ArrayList([]u8) = .empty;
    var args: std.ArrayList([]u8) = .empty;

    var i: usize = 0;

    const tokens = argv[1..];

    for (options) |option| {
        if (option.default != null) {
            try switch (option.default.?) {
                .bool => |b| parsed.options.put(option.name, .{ .bool = b }),
                .string => |chars| parsed.options.put(option.name, .{ .string = chars }),
                .number => |f| parsed.options.put(option.name, .{ .number = f }),
                else => {},
            };
        }
    }

    while (i < tokens.len) {
        const token = tokens[i];

        if (token.len == 0) {
            i += 1;
            continue;
        }

        if (isOption(token)) {
            const result = try parseOption(token, tokens, i);

            const cacheKey = std.fmt.allocPrint(self.allocator, "{s}:${d}", .{ result.name, options.len }) catch unreachable;
            defer self.allocator.free(cacheKey);

            var optionCache = self.optionCache;
            var option = optionCache.get(cacheKey);
            defer optionCache.deinit();

            if (option == null) {
                for (options) |value| {
                    if (std.mem.eql(u8, value.name, result.name) or std.mem.eql(u8, value.alias.?, result.name)) {
                        option = value;
                        try optionCache.put(cacheKey, value);
                    }
                }
            }

            if (option != null) {
                try parsed.options.put(option.?.name, self.parseOptionValue(result.value, option.?));
            }

            i += 1;
        } else if (isAlias(token)) {
            const result = try parseOption(token, tokens, i);
            const shortOpts = token[1..];

            const cacheKey = std.fmt.allocPrint(self.allocator, "alias:{s}:${d}", .{ shortOpts, options.len }) catch unreachable;
            defer self.allocator.free(cacheKey);

            var optionCache = self.optionCache;
            var option = optionCache.get(cacheKey);
            defer optionCache.deinit();

            if (option == null) {
                for (options) |value| {
                    if (std.mem.eql(u8, value.name, result.name) or std.mem.eql(u8, value.alias.?, result.name)) {
                        option = value;
                        try optionCache.put(cacheKey, value);
                    }
                }

                if (option != null) {
                    try parsed.options.put(option.?.name, self.parseOptionValue(result.value, option.?));
                }
            }

            i += if (shortOpts.len > 1) 1 else 2;
        } else {
            // This is either a command or an argument
            if (parsed.command.len == 0 and parsed.args.len == 0) {
                try commands.append(self.allocator, token);
                parsed.command = try commands.toOwnedSlice(self.allocator);
            } else {
                try args.append(self.allocator, token);
            }
            i += 1;
        }
    }
    // Since command can receive lots of argument, e.g `my-cli install pk1 pk2 pkg3` this has to be bundled outside the loop
    parsed.args = try args.toOwnedSlice(self.allocator);

    return parsed;
}

/// Try to parse slice to float, if failed return the slice
fn parseNumber(slice: []const u8) types.Value {
    const value = std.fmt.parseFloat(f64, slice) catch {
        return types.Value{ .string = slice };
    };

    return types.Value{ .number = value };
}

fn parseOption(token: []const u8, tokens: [][:0]u8, index: usize) !struct { name: []const u8, value: types.Value } {
    if (isOption(token)) {
        const name = tokens[index];
        var value: types.Value = .{ .bool = true };

        if (index + 1 < tokens.len and !isAlias(tokens[index + 1])) {
            value = .{ .string = tokens[index + 1] };
        }

        return .{ .name = name[2..], .value = value };
    } else if (isAlias(token)) {
        const name = tokens[index];
        var value: types.Value = .{ .bool = true };

        if (index + 1 < tokens.len and (!isAlias(tokens[index + 1]) and !isOption(tokens[index + 1]))) {
            value = .{ .string = tokens[index + 1] };
        }

        return .{ .name = name[1..], .value = value };
    }

    return error.NotAnOption;
}

fn parseOptionValue(self: *Self, value: types.Value, option: CLIOption) types.Value {
    const allocator = self.allocator;

    if (value == .bool and option.type == .bool) {
        return value;
    }

    switch (option.type) {
        .bool => {
            if (value == .string) {
                const string_value = value.string;

                if (std.mem.eql(u8, string_value, "true")) {
                    return types.Value{ .bool = true };
                } else if (std.mem.eql(u8, string_value, "false")) {
                    return types.Value{ .bool = false };
                } else {
                    terminal.printColored(.red, "Option '{s}' expects bool but got '{s}' which can not be converted to boolean.\n", .{ option.name, @tagName(value) });
                    std.debug.print("\nOption '{s}' expects bool but got: {s}.\n", .{ option.name, @tagName(value) });
                    std.process.exit(1);
                }
            } else if (value != .bool) {
                terminal.printColored(.red, "Option '{s}' expects bool but got: {s}.\n", .{ option.name, @tagName(value) });
                std.debug.print("\nOption '{s}' expects bool but got: {s}.\n", .{ option.name, @tagName(value) });
                std.process.exit(1);
            }

            return value;
        },
        .number => {
            if (value == .bool) {
                terminal.printColored(.red, "Option '{s}' expects number but got: {s}.\n", .{ option.name, @tagName(value) });
                std.process.exit(1);
            } else {
                const res = parseNumber(value.string);

                if (res != .number) {
                    terminal.printColored(.red, "Option '{s}' expects number but got: {s}.\n", .{ option.name, @tagName(value) });
                    std.process.exit(1);
                }

                return res;
            }
        },
        .string => {
            const res = parseNumber(value.string);

            if (res != .string) {
                terminal.printColored(.red, "Option '{s}' expects string but got: {s}.\n", .{ option.name, @tagName(res) });
                std.process.exit(1);
            }

            if (option.choices != null and option.choices.?.len >= 1) {
                var choices_array: std.ArrayList([]const u8) = .empty;
                for (option.choices.?, 0..) |choice, i| {
                    choices_array.append(allocator, choice) catch terminal.printError("Out of memory.", .{});
                    if (option.choices.?.len > 1 and i < option.choices.?.len - 1) choices_array.append(allocator, ", ") catch terminal.printError("Out of memory.", .{});
                }

                const choices = choices_array.toOwnedSlice(allocator) catch unreachable;
                defer allocator.free(choices);

                var found = false;

                for (choices) |choice| {
                    if (!std.mem.eql(u8, choice, ",") and std.mem.eql(u8, choice, value.string)) {
                        found = true;
                        break;
                    } else {
                        found = false;
                        continue;
                    }
                }

                if (found == false) {
                    terminal.printColored(.red, "Option '{s}' must be one of: [", .{option.name});

                    for (choices) |choice| {
                        terminal.printColored(.red, "{s}", .{choice});
                    }
                    terminal.printColored(.red, "]", .{});
                    std.process.exit(1);
                }
            }
            return value;
        },
    }
}

// pub fn validateArgs(parsed: ParsedArgs, args: []CLIArgument) void {
//     var argIndex: usize = 0;

//     for (args) |arg| {
//         if (argIndex >= parsed.args.length) {
//             if (arg.required) {
//                 terminal.printColored(.red, "Missing required argument: {s}\n", .{arg.name});
//                 std.process.exit(1);
//             }
//             break;
//         }

//         if (arg.variadic) {
//             // All remaining args go to this variadic argument
//             break;
//         }

//         argIndex += 1;
//     }
// }

pub fn validateOptions(self: *Self, parsed: ParsedArgs, options: []CLIOption) !ParsedArgs {
    var missing_options: std.ArrayList(CLIOption) = .empty;

    // First collect all missing required options
    for (options) |option| {
        if (option.required and parsed.options.get(option.name) == null) {
            try missing_options.append(self.allocator, option);
        }
    }

    if (missing_options.items.len > 0) {
        const alias = if (missing_options.items[0].alias) |a| a else "";
        terminal.printColored(.red, "Missing required option: --{s} (-{s})", .{ missing_options.items[0].name, alias });
        std.process.exit(1);
    }

    defer missing_options.deinit(self.allocator);

    return parsed;
}

test "parser - basic command with option and argument" {
    const allocator = std.testing.allocator;

    var parser = init(allocator);
    defer parser.deinit();

    // Setup test arguments
    const args = try allocator.alloc([:0]u8, 5);
    defer {
        // Free each argument created by toSentinel
        for (args) |arg| {
            allocator.free(arg);
        }
        allocator.free(args);
    }

    args[0] = try toSentinel(allocator, ""); // skip, parser start tokens from index 1 of the argv `argv[1..]`
    args[1] = try toSentinel(allocator, "install");
    args[2] = try toSentinel(allocator, "-D");
    args[3] = try toSentinel(allocator, "true");
    args[4] = try toSentinel(allocator, "pk1");

    // Define CLI options for testing
    const options = &[_]CLIOption{.{
        .name = "dev",
        .description = "Install as dev package",
        .alias = "D",
        .type = .bool,
    }};

    // Parse arguments
    var parsed = try parser.parse(args, options);
    defer {
        allocator.free(parsed.command);
        allocator.free(parsed.args);
        parsed.options.deinit();
    }

    // Verify command
    try std.testing.expectEqualStrings("install", parsed.command[0]);

    // Verify option was correctly parsed
    const dev_option = parsed.options.get("dev");
    try std.testing.expect(dev_option != null);
    try std.testing.expect(dev_option.?.bool == true);

    // Verify argument
    try std.testing.expectEqual(@as(usize, 1), parsed.args.len);
    try std.testing.expectEqualStrings("pk1", parsed.args[0]);
}

fn toSentinel(allocator: std.mem.Allocator, slice: []const u8) ![:0]u8 {
    const result = try allocator.allocSentinel(u8, slice.len, 0);
    @memcpy(result[0..slice.len], slice);
    return result;
}
