const std = @import("std");
const root = @import("ziglet");
const ActionArg = root.BuilderTypes.ActionArg;
const CLIOption = root.CLIOption;
const CLIBuilder = root.CLIBuilder;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = CLIBuilder.init(allocator, "example-cli", "1.0.0", "A simple example CLI using CLIBuilder.");
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

fn greet(arg: ActionArg) !void {
    const name = arg.options.get("name");
    const verbose = arg.options.get("verbose");

    if (verbose) |v| if (v.bool) {
        std.debug.print("Verbose mode enabled.\n", .{});
    };

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}

fn calc(arg: ActionArg) !void {
    const a_opt = arg.options.get("a");
    const b_opt = arg.options.get("b");
    const verbose = arg.options.get("verbose");

    if (verbose) |v| if (v.bool) {
        std.debug.print("Verbose mode enabled.\n", .{});
    };

    if (a_opt) |a| if (b_opt) |b| {
        const sum = a.number + b.number;
        std.debug.print("Sum: {d}\n", .{sum});
    };
}

fn install(arg: ActionArg) !void {
    std.debug.print("Running 'install' action.\n", .{});

    if (arg.options.get("dev")) |_| {
        std.debug.print("Saving as dev package.\n", .{});
    }

    if (arg.args.len == 0) {
        //error
    }

    if (arg.args.len > 0) {
        for (arg.args) |value| {
            std.debug.print("package: {s}.\n", .{value});
        }
    }
}
