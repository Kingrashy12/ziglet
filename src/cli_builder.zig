const std = @import("std");
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig");
const types = @import("types.zig");
const terminal = @import("root.zig").utils.terminal;
const CLIOption = types.CLIOption;
const CLICommand = types.CLICommand;
const CommandBuilder = @import("command_builder.zig");
const printColored = terminal.printColored;
const print = terminal.print;
const color = terminal.Color;

const Self = @This();

/// The allocator used for memory management throughout the CLI builder.
allocator: Allocator,
/// A hash map storing all registered commands by their names.
commands: std.StringHashMap(CLICommand),
/// A list of global options that apply to all commands.
globalOptions: std.ArrayList(CLIOption),
/// The name of the CLI application.
name: []const u8,
/// The version string of the CLI application.
version: []const u8,
/// A description of the CLI application.
description: []const u8,
// TODO: This is irrelevant and should be removed
/// Whether the CLI should run in interactive mode.
interactive: bool = false,

/// Initializes a new CLIBuilder instance.
///
/// Parameters:
/// - allocator: The allocator to use for memory management.
/// - name: The name of the CLI application.
/// - version: The version string of the application.
/// - description: A description of the CLI application.
///
/// Returns: A new CLIBuilder instance.
pub fn init(allocator: Allocator, name: []const u8, version: []const u8, description: []const u8) Self {
    const self = Self{
        .allocator = allocator,
        .name = name,
        .version = version,
        .description = description,
        .interactive = false,
        .commands = std.StringHashMap(CLICommand).init(allocator),
        .globalOptions = .empty,
    };

    return self;
}
/// Release all allocated memory for commands and global options.
pub fn deinit(self: *Self) void {
    self.commands.deinit();
    self.globalOptions.deinit(self.allocator);
}

pub fn setGlobalOptions(self: *Self) void {
    self.globalOptions.append(self.allocator, .{
        .alias = "h",
        .name = "help",
        .type = .bool,
        .description = "Show help information",
    }) catch {};

    self.globalOptions.append(self.allocator, .{
        .alias = "V",
        .type = .bool,
        .name = "version",
        .description = "Show version number",
    }) catch {};
}

pub fn command(self: *Self, name: []const u8, description: []const u8) CommandBuilder {
    return CommandBuilder.init(self.allocator, self, name, description);
}

pub fn addCommand(self: *Self, command_: CLICommand) void {
    self.commands.put(command_.name, command_) catch {};
}

/// Global option
pub fn option(self: *Self, config: CLIOption) void {
    self.globalOptions.append(self.allocator, .{
        .name = config.name,
        .description = config.description,
        .type = config.type,
        .alias = config.alias,
        .required = config.required,
        .choices = config.choices,
        .default = config.default,
    }) catch {};
}

pub fn defOptions(self: *Self, config: []const CLIOption) []CLIOption {
    _ = self;
    return @constCast(config);
}

pub fn defChoices(self: Self, choices: []const []const u8) [][]const u8 {
    _ = self;
    return @constCast(choices);
}

// TODO: This is irrelevant, and should be removed
pub fn action(self: *Self, handler: fn (args: anytype, options: anyerror!void) void) *Self {
    // Default command action
    self.commands.put("", self.allocator, .{
        .name = "",
        .description = "Default command",
        .action = handler,
    }) catch {};

    return @constCast(self);
}

pub fn setInteractive(self: *Self, interactive: bool) *Self {
    self.interactive = interactive;

    return @constCast(self);
}

pub fn parse(self: *Self, argv: [][:0]u8, builder_commands: ?[]const *CommandBuilder) !void {
    var parser = Parser.init(self.allocator);
    defer parser.deinit();

    defer freeBuilderOptions(builder_commands);

    var parsed = try parser.parse(argv, self.globalOptions.items);
    defer {
        self.allocator.free(parsed.command);
        self.allocator.free(parsed.args);
        parsed.options.deinit();
    }

    if (parsed.options.get("help")) |_| {
        self.helpCommand(parsed.command);
        return;
    }

    if (parsed.options.get("version")) |_| {
        printColored(.white, "v{s}\n", .{self.version});
        return;
    }

    if (argv.len == 1) {
        self.showHelp();
        return;
    }

    const command_name = parsed.command[0];

    const command_ = self.commands.get(command_name);

    var found_command: CLICommand = undefined;

    if (command_) |cmd| {
        found_command = cmd;
    } else {
        printColored(.red, "Unknown command: {s}\n", .{command_name});
        printColored(.yellow, "\nAvailable commands: ", .{});
        self.listCommands();
        return;
    }

    const merged_options = try self.mergeOptions(found_command.options);
    defer self.allocator.free(merged_options);

    var command_parsed = try parser.parse(argv, merged_options);
    defer {
        self.allocator.free(command_parsed.command);
        self.allocator.free(command_parsed.args);
        command_parsed.options.deinit();
    }

    const validated_parsed = try parser.validateOptions(command_parsed, merged_options);

    try found_command.action(.{
        .name = self.name,
        .version = self.version,
        .args = validated_parsed.args,
        .options = validated_parsed.options,
        .allocator = self.allocator,
    });
}

fn helpCommand(self: *Self, parsed_commands: [][]u8) void {
    if (parsed_commands.len > 0) {
        self.showCommandHelp(parsed_commands[0]);
    } else {
        self.showHelp();
    }
}

fn freeBuilderOptions(builder_commands: ?[]const *CommandBuilder) void {
    if (builder_commands) |cmds| {
        for (cmds) |value| {
            value.deinit();
        }
    }
}

fn mergeOptions(self: *Self, command_options: ?[]const CLIOption) ![]CLIOption {
    const globalOptions = self.globalOptions;

    // Merge global and command options into one array
    var merged: std.ArrayList(CLIOption) = .empty;

    // Add global options to merge array
    for (globalOptions.items) |_option| {
        try merged.append(self.allocator, _option);
    }

    if (command_options) |cmd_op| {
        // Add command options to merge array
        for (cmd_op) |_option| {
            try merged.append(self.allocator, _option);
        }
    }

    return try merged.toOwnedSlice(self.allocator);
}

pub fn showHelp(self: *Self) void {
    print("{s} \n\n", .{self.description});
    printColored(.bold, "Usage:", .{});
    print(" {s} <command> [options]\n\n", .{self.name});

    self.listCommands();
    self.showGlobalOptions();

    terminal.print("\nRun \"{s} <command> --help\" for more information about a command.\n", .{self.name});
}

fn showCommandHelp(self: *Self, command_name: []const u8) void {
    if (self.commands.get(command_name)) |cmd| {
        printColored(.bold, "Usage: ", .{});

        if (cmd.options != null and cmd.options.?.len > 0) {
            print("{s} {s} [options]\n", .{ self.name, cmd.name });
        } else print("{s} {s}\n", .{ self.name, cmd.name });

        print("\n {s}\n", .{cmd.description});

        if (cmd.options) |options| {
            if (options.len > 0) {
                printColored(.bold, "\nOptions:\n", .{});
            }

            for (options) |_option| {
                const flags = if (_option.alias) |_| std.fmt.allocPrint(self.allocator, "-{s}, --{s}", .{ _option.alias.?, _option.name }) catch unreachable else std.fmt.allocPrint(self.allocator, "--{s}", .{_option.name}) catch unreachable;
                defer self.allocator.free(flags);

                print("  {s:<20} {s}\n", .{ flags, _option.description });
            }
        }
    } else {
        printColored(.red, "Unknown command: {s}\n", .{command_name});
        printColored(.yellow, "\nAvailable commands: ", .{});
        self.listCommands();
    }
}

fn listCommands(self: *Self) void {
    if (self.commands.capacity() > 0) {
        printColored(.bold, "Commands:\n", .{});

        var command_iterator = self.commands.iterator();

        while (command_iterator.next()) |entry| {
            const name = entry.key_ptr.*;
            print("  {s:<26} {s}\n", .{ name, entry.value_ptr.description });
        }
    }
}

fn showGlobalOptions(self: *Self) void {
    if (self.globalOptions.items.len > 0) {
        printColored(.bold, "\nGlobal Options:\n", .{});

        for (self.globalOptions.items) |_option| {
            const flags = if (_option.alias) |_| std.fmt.allocPrint(self.allocator, "-{s}, --{s}", .{ _option.alias.?, _option.name }) catch unreachable else std.fmt.allocPrint(self.allocator, "--{s}", .{_option.name}) catch unreachable;
            defer self.allocator.free(flags);

            const required = if (_option.required) " (required)" else "";

            var value: types.Value = .undefined;

            if (_option.default) |_| switch (_option.default.?) {
                .string => |str| value = .{ .string = str },
                .bool => |b| value = .{ .bool = b },
                .number => |num| value = .{ .number = num },
                else => {},
            };

            const default_value = switch (value) {
                .string => |default| terminal.coloredWithArgs(self.allocator, "(default: {s})", .{default}, .gray),
                .number => |default| terminal.coloredWithArgs(self.allocator, "(default: {d})", .{default}, .gray),
                .bool => |default| terminal.coloredWithArgs(self.allocator, "(default: {})", .{default}, .gray),
                else => terminal.coloredWithArgs(self.allocator, "", .{}, .gray),
            };

            defer self.allocator.free(default_value);

            print("  {s:<26} {s} {s}{s}{s} {s}\n", .{ flags, _option.description, color.ansiCode(.red), required, color.ansiCode(.reset), default_value });
        }
    }
}
