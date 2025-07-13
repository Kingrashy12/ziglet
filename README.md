# 🐣 Ziglet – Your Minimalist CLI Builder in Zi

Ziglet is a lightweight command-line interface (CLI) builder. It lets you effortlessly define custom commands and execute them using Ziglet's core `executeCommand` functionality—giving you a flexible and blazing-fast CLI tool tailored to your needs.

## ✨ Features

- Add and organize custom commands with ease
- Execute commands with `executeCommand` built into Ziglet
- Minimal dependencies, maximum speed
- Built in Zig for clarity, performance, and control

## 📚 Example Usage

```zig
const std = @import("std");
const cmd = @import("ziglet").Commander;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var commander = try cmd.init(allocator, "my-cli", "0.1.0", null);
    defer commander.deinit();

    // Define a simple command
    try commander.addCommand("greet", "Say Hello", greetFn, null);

    try commander.checkArgs();

    try commander.executeCommand();
}

// The function to execute
fn greetFn(self: *cmd) void {
    std.debug.print("Hello from {s}!\n", .{self.name});
}
```

## 🤝 Contributing

Want to make Ziglet even snappier? Feel free to open issues, suggest features, or submit pull requests. Let’s build something sharp together.

## 📄 License

MIT – free to use, modify, and share.
