const std = @import("std");
const ziglet = @import("ziglet");
const CommandContext = ziglet.BuilderTypes.CommandContext;
const CLIBuilder = ziglet.CLIBuilder;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = CLIBuilder.init(allocator, "my-cli", "0.1.0", "Factory builder example");
    defer cli.deinit();

    cli.setGlobalOptions();

    // Global option
    _ = cli.option(.{
        .alias = "l",
        .name = "list",
        .description = "List lib directories",
        .type = .string,
    });

    const greet_cmd = cli.command("greet", "Greet someone").option(.{
        .alias = "n",
        .name = "name",
        .required = true,
        .type = .string,
        .description = "Name to greet",
    }).action(greet).finalize();

    const calc_cmd = cli.command("calc", "Calculate sum of two numbers").option(.{
        .alias = "a",
        .name = "a",
        .required = true,
        .type = .number,
        .description = "First number",
    }).option(.{
        .alias = "b",
        .name = "b",
        .required = true,
        .type = .number,
        .description = "Second number",
    }).action(calc).finalize();

    // Command without options
    _ = cli.command("status", "Show status").action(status).finalize();

    // Only commands with options need to be passed to parse
    try cli.parse(args, &.{ greet_cmd, calc_cmd });
}

fn greet(arg: CommandContext) !void {
    const name = arg.options.get("name");

    std.debug.print("Greeting someone.\n", .{});

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}

fn calc(arg: CommandContext) !void {
    const a_opt = arg.options.get("a");
    const b_opt = arg.options.get("b");

    std.debug.print("Calculating sum.\n", .{});

    if (a_opt) |a| if (b_opt) |b| {
        const sum = a.number + b.number;
        std.debug.print("Sum: {d}\n", .{sum});
    };
}

fn status(arg: CommandContext) !void {
    _ = arg;
    std.debug.print("System status: All good!\n", .{});
}
