const std = @import("std");
const ArgParser = @import("../parser/parser.zig").ArgParser();
const tmc = @import("../../utils/terminal.zig");
const Color = tmc.Color;
const printColored = tmc.printColored;
const printError = tmc.printError;

pub const OptionType = enum {
    bool,
    string,
    int,
    float,
};

// TODO: Add short and long flags support

/// Represents a command-line option.
///
/// - `flag`: The option flag (e.g., "--help").
/// - `description`: A brief description of the option.
/// - `required`: Indicates if the option is required (defaults to `false`).
pub const Option = struct {
    flag: []const u8,
    description: []const u8,
    required: bool = false,
    option_type: OptionType = .string,

    pub fn isBool(self: Option) bool {
        return self.option_type == .bool;
    }
};

/// Represents a command in the CLI application.
///
/// Fields:
/// - `name`: The name of the command.
/// - `description`: A brief description of what the command does.
/// - `execute`: A pointer to the function that executes the command. The function takes
///   an array of arguments and a pointer to the `Commander` instance, and returns an error or void.
/// - `options`: An optional list of options that the command accepts.
pub const Command = struct { name: []const u8, description: []const u8, execute: *const fn (*Commander) anyerror!void, options: ?[]const Option };

/// Commander is a struct that provides functionality for parsing and handling command-line arguments.
/// It is designed to help build CLI applications by managing commands, options, and arguments.
///
/// Represents the core structure for managing program commands and argument parsing.
/// - `commands`: A hash map containing all available commands for the program.
/// - `parser`: An instance responsible for parsing command-line arguments.
/// - `rawArgs`: The raw command-line arguments as received by the program.
/// - `version`: The version string of the program.
/// - `options`: A hash map of options passed to a command; only accessible within the execute function.
/// - `allocator`: The memory allocator used for dynamic allocations.
/// - `name`: The name of the program.
/// - `description`: An optional description of the program.
pub const Commander = struct {
    const Self = @This();
    /// A hash map that stores commands by their names.
    commands: std.StringHashMap(Command),
    /// An instance of ArgParser that handles parsing command-line arguments.
    /// It provides methods to parse arguments and access parsed values.
    parser: ArgParser,
    /// The raw command-line arguments as received by the program.
    /// This is a slice of null-terminated strings, where each string represents an argument.
    rawArgs: [][:0]u8,
    /// The version string of the program.
    version: []const u8,
    /// A hash map of options passed to a command; only accessible within the execute function.
    /// This allows commands to access options specified by the user.
    /// The keys are option flags (e.g., "--help")
    options: std.StringHashMap([]const u8),
    /// The memory allocator used for dynamic allocations.
    /// This is typically an arena allocator for efficient memory management.
    allocator: std.mem.Allocator,
    /// The name of the program.
    name: []const u8,
    /// An optional description of the program.
    description: ?[]const u8,

    /// Initializes a new Commander instance.
    pub fn init(allocator: std.mem.Allocator, name: []const u8, version: []const u8, description: ?[]const u8) !Self {
        var args = try std.process.argsAlloc(allocator);

        return Self{
            .commands = std.StringHashMap(Command).init(allocator),
            .parser = try ArgParser.init(allocator, args[0..]),
            .rawArgs = args,
            .name = name,
            .version = version,
            .description = description,
            .options = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit();
        self.parser.deinit();
        self.options.deinit();
    }

    /// Adds a new command to the commander with the specified name, description, execution function, and optional options.
    ///
    /// - `name`: The name of the command to add.
    /// - `description`: A brief description of what the command does.
    /// - `execute`: The function to execute when the command is invoked. It receives the command arguments and a pointer to the Commander.
    /// - `options`: An optional slice of `Option` structs that define command-line options for this command.
    ///
    /// Returns an error if the command could not be added.
    pub fn addCommand(self: *Self, name: []const u8, description: []const u8, execute: fn (*Commander) anyerror!void, options: ?[]const Option) !void {
        if (self.commands.contains(name)) {
            return error.DuplicateCommandName;
        }
        try self.commands.put(name, Command{ .description = description, .name = name, .execute = execute, .options = options });
    }

    /// Executes the currently selected command.
    ///
    /// This function runs the command associated with the current instance of `Self`.
    /// It may return an error if command execution fails.
    /// If `validateArg` returns an error, it will propagate and command execution will be skipped.
    pub fn executeCommand(self: *Self) !void {
        if (self.rawArgs.len < 2) return;

        const arg = self.parser.args;

        const name = self.rawArgs[1];

        if ((arg.len > 1 and std.mem.eql(u8, arg[1], "--version")) or (arg.len > 1 and std.mem.eql(u8, arg[1], "-v"))) {
            print("v{s}", .{self.version});
            return;
        }

        if ((arg.len > 1 and std.mem.eql(u8, arg[1], "--help")) or (arg.len > 1 and std.mem.eql(u8, arg[1], "-h"))) {
            try self.printHelp();
            return;
        }

        const command = self.commands.get(name) orelse {
            printError("Unknown command: {s}", .{name});

            print("\nTo see a list of supported commands, run: \n {s} --help\n", .{self.name});
            return;
        };

        if (arg.len > 2 and std.mem.eql(u8, arg[2], "-h") or arg.len > 2 and std.mem.eql(u8, arg[2], "--help") or arg.len > 2 and std.mem.eql(u8, arg[2], "help")) {
            try self.generateHelp(command);
        } else {
            // Validate arguments
            const callNext = try self.validateArg(command);

            if (callNext) {
                var bool_option_indices = std.ArrayList(usize).init(self.allocator);
                defer bool_option_indices.deinit();

                if (command.options) |options| {
                    for (options, 0..options.len) |option, i| {
                        if (option.isBool()) {
                            try bool_option_indices.append(i);
                        }
                    }
                }

                // Ensure only a single bool option is available
                if (bool_option_indices.items.len > 1) {
                    return printError("Command currently supports only one option with option_type bool.", .{});
                }

                // Assign options to result from `parser.parse`
                self.options = try self.parser.parse(bool_option_indices.items, command);

                // Check if arg passed is valid
                try command.execute(self);
            }
        }
    }

    fn generateHelp(self: *Self, command: Command) !void {
        const has_options = command.options != null and command.options.?.len >= 1;

        if (has_options) {
            print("Usage: {s} {s} [options]\n\n", .{ self.name, command.name });
        } else print("Usage: {s} {s}\n\n", .{ self.name, command.name });

        print("Description: {s}\n\n", .{command.description});

        if (has_options) {
            print("Options:\n", .{});
            for (command.options.?) |option| {
                print("{s:<15}   {s}\n", .{ option.flag, option.description });
            }
        }
    }

    /// Prints the help information for the current command to the standard output.
    /// This typically includes usage instructions and available options.
    /// Returns an error if printing fails.
    pub fn printHelpCommand(self: *Self) !void {
        const name = self.rawArgs[1];
        const command = self.commands.get(name) orelse {
            printError("Unknown command: {s}", .{name});

            print("\nTo see a list of supported commands, run: \n {s} --help\n", .{self.name});
            return;
        };

        return try self.generateHelp(command);
    }

    /// Validates the command-line arguments against the expected options for the command.
    fn validateArg(self: *Self, command: Command) anyerror!bool {
        if (command.options != null and command.options.?.len >= 1) {
            const args = self.rawArgs[2..];

            var flags = std.ArrayList([]const u8).init(self.allocator);
            defer flags.deinit();

            // Collect all flags from args
            for (args) |arg| {
                if (std.mem.startsWith(u8, arg, "--")) {
                    try flags.append(arg);
                }
            }

            // Check if each flag matches any option
            for (flags.items) |flag| {
                var found = false;
                for (command.options.?) |option| {
                    if (std.mem.eql(u8, flag, option.flag)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    printError("Unknown flag '{s}'\n", .{flag});

                    print("Did you mean to use one of:\n", .{});

                    for (command.options.?) |option| {
                        print("  {s}\n", .{option.flag});
                    }
                    return false;
                }
            }

            // Check for required options
            for (command.options.?) |option| {
                if (option.required) {
                    var present = false;
                    for (flags.items) |flag| {
                        if (std.mem.eql(u8, flag, option.flag)) {
                            present = true;
                            break;
                        }
                    }
                    if (!present) {
                        printError("Missing required option: {s}", .{option.flag});
                        return false;
                    }
                }
            }
        }

        return true;
    }

    fn printHelp(self: *Self) !void {
        print("Usage: {s} <command> [option]\n\n", .{self.name});

        printColored(.white, "Commands:\n\n", .{});

        var it = self.commands.iterator();

        while (it.next()) |entry| {
            printColored(.white, "{s:<16} {s}\n", .{ entry.key_ptr.*, entry.value_ptr.description });
        }

        printColored(.white, "{s:<16} {s}\n", .{ "<command> -h", "quick help on <command>" });
    }

    /// Checks the validity of the arguments provided to the command.
    pub fn checkArgs(self: *Self) !void {
        if (self.rawArgs.len < 2) {
            try self.printHelp();
            return;
        }
    }

    fn print(comptime format: []const u8, args: anytype) void {
        var stdout = std.io.getStdOut().writer();
        _ = stdout.print(format, args) catch {};
    }
};
