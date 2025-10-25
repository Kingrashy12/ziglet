const std = @import("std");

pub const CommandBuilder = struct {
    alias: fn (alias: []const u8) CommandBuilder,
    option: fn (name: []const u8, description: []const u8, config: ?CLIOption) CommandBuilder,
    action: fn (handler: fn (args: anytype, options: anytype) void) CommandBuilder,
    command: fn (name: []const u8, description: []const u8) CommandBuilder,
    showHelp: fn () void,
    finalize: fn () void,
};

const OptionType = enum { number, bool, string };

pub const Value = union(enum) {
    bool: bool,
    string: []const u8,
    number: f64,
    undefined,
};

pub const CLIOption = struct {
    name: []const u8,
    alias: ?[]const u8 = null,
    description: []const u8,
    type: OptionType,
    required: bool = false,
    default: ?Value = null,
    choices: ?[][]const u8 = null,
};

pub const ActionArg = struct { args: [][]u8, options: std.StringHashMap(Value), allocator: std.mem.Allocator };

pub const CLICommand = struct {
    name: []const u8,
    description: []const u8,
    options: ?[]CLIOption = null,
    action: *const fn (ActionArg) anyerror!void,
    // subcommands: ?[]CLICommand,
};

pub const CLIConfig = struct {
    name: []const u8,
    version: []const u8,
    description: ?[]const u8,
    commands: std.StringHashMap(CLICommand),
    globalOptions: ?[]CLIOption,
};

pub const ParsedArgs = struct {
    command: [][]u8,
    args: [][]u8,
    options: std.StringHashMap(Value),
};

pub const CLIBuilderOptions = struct {
    interactive: ?bool,
};

pub const CLIBuilder = struct {
    command: fn (name: []const u8, description: []const u8) CommandBuilder,
    option: fn (name: []const u8, description: []const u8, config: ?CLIOption) CLIBuilder,
    action: fn (handler: fn (args: anytype, options: anytype) void) CLIBuilder,
    parse: fn (argv: [][:0]u8) void,
    showHelp: fn () void,
    addCommand: fn (command: CLICommand) void,
    setInteractive: fn (interactive: bool) CLIBuilder,
};
