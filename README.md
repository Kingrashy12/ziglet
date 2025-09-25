# 🐣 Ziglet – Your Minimalist CLI Builder in Zig

Ziglet is a lightweight command-line interface (CLI) builder. It lets you effortlessly define custom commands and execute them using Ziglet's core, giving you a flexible and blazing-fast CLI tool tailored to your needs.

## ✨ Features

- Add and organize custom commands with ease
- Execute commands with `parse` built into Ziglet
- Minimal dependencies, maximum speed
- Built in Zig for clarity, performance, and control

## 📚 How to Use

1. Fetch the package:

```bash
zig fetch --save git+https://github.com/Kingrashy12/ziglet
```

2. Add the module to your `build.zig`:

```zig
  // Add the ziglet dependency
  const ziglet_dep = b.dependency("ziglet", .{});

    // Add the ziglet module to the executable
    exe.root_module.addImport("ziglet", ziglet_dep.module("ziglet"));
```

3. Import and use in your code:

### Basic Usage

```zig
const std = @import("std");
const ziglet = @import("ziglet");
const ActionArg = ziglet.BuilderTypes.ActionArg;
const CLIBuilder = ziglet.CLIBuilder;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = CLIBuilder.init(allocator, "my-cli", "0.1.0", "A simple CLI example");
    defer cli.deinit();

    // Add a command with options
    cli.addCommand(.{
        .name = "greet",
        .description = "Greet someone",
        .action = greet,
        .options = cli.defOptions(&.{.{
            .name = "name",
            .alias = "n",
            .type = .string,
            .required = true,
            .description = "Name to greet",
        }}),
    });

    try cli.parse(args, null);
}

fn greet(arg: ActionArg) !void {
    const name = arg.options.get("name");

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}
```

### Global Options

Ziglet supports global options that apply to all commands:

```zig
// ... (same setup as above)

var cli = CLIBuilder.init(allocator, "example-cli", "1.0.0", "A CLI with global options");
defer cli.deinit();

// Enable global options (adds --help and --version automatically)
cli.setGlobalOptions();

// Add a global option
cli.option(.{
    .alias = "v",
    .name = "verbose",
    .type = .bool,
    .description = "Enable verbose output",
});

// Add commands that can access global options
cli.addCommand(.{
    .name = "greet",
    .description = "Greet someone",
    .action = greet,
    .options = cli.defOptions(&.{.{
        .name = "name",
        .alias = "n",
        .type = .string,
        .required = true,
        .description = "Name to greet",
    }}),
});

try cli.parse(args, null);

// In your action function, access both global and command options
fn greet(arg: ActionArg) !void {
    const verbose = arg.options.get("verbose");
    const name = arg.options.get("name");

    if (verbose) |v| if (v.bool) {
        std.debug.print("Verbose mode enabled.\n", .{});
    }

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}
```

### Factory Pattern (Fluent API)

For a more fluent and readable way to build commands:

```zig
// ... (same setup as above)

var cli = CLIBuilder.init(allocator, "my-cli", "0.1.0", "Factory builder example");
defer cli.deinit();

cli.setGlobalOptions();

// Global option
_ = cli.option(.{
    .alias = "v",
    .name = "verbose",
    .type = .bool,
    .description = "Enable verbose output",
});

// Build commands using fluent API
const greet_cmd = cli.command("greet", "Greet someone")
    .option(.{
        .alias = "n",
        .name = "name",
        .required = true,
        .type = .string,
        .description = "Name to greet",
    })
    .action(greet)
    .finalize();

const calc_cmd = cli.command("calc", "Calculate sum of two numbers")
    .option(.{
        .alias = "a",
        .name = "a",
        .required = true,
        .type = .number,
        .description = "First number",
    })
    .option(.{
        .alias = "b",
        .name = "b",
        .required = true,
        .type = .number,
        .description = "Second number",
    })
    .action(calc)
    .finalize();

// Command without options
_ = cli.command("status", "Show status")
    .action(status)
    .finalize();

// Parse with factory commands
try cli.parse(args, &.{ greet_cmd, calc_cmd });

fn greet(arg: ActionArg) !void {
    const name = arg.options.get("name");
    std.debug.print("Greeting someone.\n", .{});

    if (name) |n| {
        std.debug.print("Hello, {s}!\n", .{n.string});
    }
}

fn calc(arg: ActionArg) !void {
    const a_opt = arg.options.get("a");
    const b_opt = arg.options.get("b");

    if (a_opt) |a| if (b_opt) |b| {
        const sum = a.number + b.number;
        std.debug.print("Sum: {d}\n", .{sum});
    }
}

fn status(arg: ActionArg) !void {
    _ = arg;
    std.debug.print("System status: All good!\n", .{});
}
```

## 📖 Examples

For runnable examples, see the [examples/](examples/) directory:

- [`examples/plain.zig`](examples/plain.zig) - Comprehensive example with multiple commands, global options, and different option types
- [`examples/factory.zig`](examples/factory.zig) - Demonstrates the fluent factory pattern for building commands

## 🤝 Contributing

Want to make Ziglet even snappier? Feel free to open issues, suggest features, or submit pull requests. Let’s build something sharp together.

## 📄 License

MIT – free to use, modify, and share.
