const std = @import("std");
const ziglet = @import("ziglet");
const CommandContext = ziglet.BuilderTypes.CommandContext;
const CLIOption = ziglet.CLIOption;
const CLIBuilder = ziglet.CLIBuilder;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(arena.allocator());

    var cli = CLIBuilder.init(allocator, init, "example-cli", "1.0.0", "A simple example CLI using CLIBuilder.");
    defer cli.deinit();

    cli.setGlobalOptions();

    // Add a global option
    cli.option(.{
        .alias = "v",
        .name = "verbose",
        .type = .bool,
        .description = "Enable verbose output",
    });

    // Add command: greet
    cli.addCommand(.{
        .name = "greet",
        .description = "Greet someone",
        .action = greet,
        .options = cli.defOptions(&.{
            .{
                .name = "name",
                .alias = "n",
                .type = .string,
                .required = true,
                .description = "Name to greet",
            },
        }),
    });

    // Add command: calc
    cli.addCommand(.{
        .name = "calc",
        .description = "Calculate sum of two numbers",
        .action = calc,
        .options = cli.defOptions(&.{
            .{
                .name = "a",
                .alias = "a",
                .type = .number,
                .required = true,
                .description = "First number",
            },
            .{
                .name = "b",
                .alias = "b",
                .type = .number,
                .required = true,
                .description = "Second number",
            },
        }),
    });

    cli.addCommand(.{
        .name = "install",
        .description = "Install a package from the registry",
        .action = install,
        .options = cli.defOptions(&.{.{
            .name = "dev",
            .alias = "D",
            .description = "Install as a development package(won't be added to finally binary).",
            .type = .bool,
        }}),
    });

    try cli.parse(args, null);
}

fn greet(ctx: CommandContext) !void {
    const name = ctx.options.get("name");
    const verbose = ctx.options.get("verbose");

    if (verbose) |v| if (v.bool) {
        std.debug.print("Verbose mode enabled.\n", .{});
    };

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}

fn calc(ctx: CommandContext) !void {
    const a_opt = ctx.options.get("a");
    const b_opt = ctx.options.get("b");
    const verbose = ctx.options.get("verbose");

    if (verbose) |v| if (v.bool) {
        std.debug.print("Verbose mode enabled.\n", .{});
    };

    if (a_opt) |a| if (b_opt) |b| {
        const sum = a.number + b.number;
        std.debug.print("Sum: {d}\n", .{sum});
    };
}

fn install(ctx: CommandContext) !void {
    std.debug.print("Running 'install' action.\n", .{});

    if (ctx.options.get("dev")) |_| {
        std.debug.print("Saving as dev package.\n", .{});
    }

    if (ctx.args.len == 0) {
        //error
    }

    if (ctx.args.len > 0) {
        for (ctx.args) |value| {
            std.debug.print("package: {s}.\n", .{value});
        }
    }
}
