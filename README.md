# 🐣 Ziglet – Your Minimalist CLI Builder in Zig

Ziglet is a lightweight command-line interface (CLI) builder. It lets you effortlessly define custom commands and execute them using Ziglet's core `executeCommand` functionality—giving you a flexible and blazing-fast CLI tool tailored to your needs.

## ✨ Features

- Add and organize custom commands with ease
- Execute commands with `executeCommand` built into Ziglet
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
  const ziglet_dep = b.dependency("ziglet", .{
      .target = target,
      .optimize = optimize,
    });

    // Add the ziglet module to the executable
    exe.root_module.addImport("ziglet", ziglet_dep.module("ziglet"));
```

3. Import and use in your code:

```zig
const std = @import("std");
const root = @import("ziglet");
const ActionArg = root.BuilderTypes.ActionArg;
const CLIBuilder = root.CLIBuilder;

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

## 📖 Examples

For more comprehensive examples, see the [examples/](examples/) directory:

- [Basic CLI with CLIBuilder](examples/plain.zig) - Demonstrates commands with options, global options, and actions.
- [Factory pattern CLI](examples/factory.zig) - Shows a fluent API for building commands.

## 🤝 Contributing

Want to make Ziglet even snappier? Feel free to open issues, suggest features, or submit pull requests. Let’s build something sharp together.

## 📄 License

MIT – free to use, modify, and share.
