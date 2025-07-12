const std = @import("std");
const cmd = @import("root.zig").Commander;
const Option = @import("root.zig").Option;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var commander = try cmd.init(allocator, "my-cli", "1.0.0", null);
    defer commander.deinit();

    // Define a simple command
    try commander.addCommand("greet", "Say Hello", greetFn, &[_]Option{ Option{
        .flag = "--name",
        .description = "User name",
    }, Option{
        .flag = "--age",
        .description = "User age",
    } });

    try commander.checkArgs();

    try commander.executeCommand();
}

// The function to execute
fn greetFn(self: *cmd) !void {
    std.debug.print("Hello from {s}!\n", .{self.name});
}
