const std = @import("std");
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig");
const types = @import("types.zig");
const CommandBuilder = types.CommandBuilder;
const CLICommand = types.CLICommand;
const CLIBuilder = @import("cli_builder.zig");
const CLIOption = types.CLIOption;

const Self = @This();

cmd: CLICommand,
parent: *CLIBuilder,
allocator: Allocator,
options: std.ArrayList(CLIOption),

fn default(args: types.CommandContext) anyerror!void {
    _ = args;
}

pub fn init(allocator: Allocator, parent: *CLIBuilder, name: []const u8, description: []const u8) Self {
    return Self{
        .parent = parent,
        .options = .empty,
        .cmd = .{
            .name = name,
            .description = description,
            .action = default,
        },
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.cmd.options) |options| {
        self.allocator.free(options);
    }
}

pub fn option(self: *const Self, config: CLIOption) *Self {
    var cast_self: *Self = @constCast(self);

    if (cast_self.cmd.options == null) {
        cast_self.cmd.options = &.{};
    }

    const previous_opts = cast_self.cmd.options;

    for (previous_opts.?) |value| {
        cast_self.options.append(cast_self.allocator, value) catch unreachable;
    }

    cast_self.options.append(cast_self.allocator, config) catch unreachable;

    return @constCast(self);
}

pub fn action(
    self: *const Self,
    handler: *const fn (types.CommandContext) anyerror!void,
) *Self {
    var cast_self: *Self = @constCast(self);
    cast_self.cmd.action = handler;
    cast_self.cmd.options = cast_self.options.toOwnedSlice(cast_self.allocator) catch unreachable;

    return @constCast(self);
}

pub fn showHelp(self: *Self) void {
    self.parent.addCommand(self.cmd);
    self.parent.showHelp();
}

pub fn finalize(self: *Self) *Self {
    self.parent.addCommand(self.cmd);

    return self;
}
