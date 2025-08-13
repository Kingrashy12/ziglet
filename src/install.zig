const std = @import("std");
const ziglet = @import("root.zig");
const terminal = @import("utils/terminal.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Set console to UTF-8 on Windows
    terminal.setWinConsole();

    var commander = try ziglet.Commander.init(allocator, "ziglet-install", "1.0.0", "Install utility for Ziglet CLI applications");
    defer commander.deinit();

    // Define install command with options
    const install_options = [_]ziglet.Option{
        .{
            .short = "-n",
            .long = "--name",
            .description = "Name of the CLI to install (required)",
            .required = true,
            .option_type = .string,
        },
        .{
            .short = "-p",
            .long = "--path",
            .description = "Custom installation path",
            .required = false,
            .option_type = .string,
        },
        .{
            .short = "-f",
            .long = "--force",
            .description = "Force overwrite existing installation",
            .required = false,
            .option_type = .bool,
        },
    };

    try commander.addCommand("install", "Install a CLI application", installCommand, &install_options);

    try commander.checkArgs();
    try commander.executeCommand();
}

fn installCommand(cmd: *ziglet.Commander) !void {
    const allocator = cmd.allocator;

    // Get CLI name from options
    const cli_name = cmd.options.get("name") orelse {
        terminal.printError("CLI name is required. Use --name or -n flag.\n", .{});
        return;
    };

    // Get optional custom path
    const custom_path = cmd.options.get("path");
    const force_install = cmd.options.get("force") != null;

    terminal.printColored(.cyan, "🚀 Installing CLI: {s}\n", .{cli_name});

    // Determine source binary location
    const bin_path = try std.fmt.allocPrintZ(allocator, "zig-out/bin/{s}{s}", .{
        cli_name,
        if (@import("builtin").os.tag == .windows) ".exe" else "",
    });
    defer allocator.free(bin_path);

    // Detect platform and determine install paths
    const os_tag = @import("builtin").os.tag;

    var install_dir_path: []const u8 = undefined;
    var dest_file_name: []const u8 = undefined;

    if (custom_path) |path| {
        // Use custom path
        install_dir_path = try allocator.dupe(u8, path);
        dest_file_name = if (os_tag == .windows)
            try std.fmt.allocPrint(allocator, "{s}.exe", .{cli_name})
        else
            try allocator.dupe(u8, cli_name);
    } else if (os_tag == .windows) {
        // Windows: %USERPROFILE%\ziglet\bin\<cli_name>.exe
        const home = try std.process.getEnvVarOwned(allocator, "USERPROFILE");
        defer allocator.free(home);

        install_dir_path = try std.fs.path.join(allocator, &[_][]const u8{ home, "ziglet", "bin" });
        dest_file_name = try std.fmt.allocPrint(allocator, "{s}.exe", .{cli_name});
    } else {
        // Unix: ~/.local/bin/<cli_name>
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch ".";
        defer if (!std.mem.eql(u8, home, ".")) allocator.free(home);

        install_dir_path = try std.fs.path.join(allocator, &[_][]const u8{ home, ".local", "bin" });
        dest_file_name = try allocator.dupe(u8, cli_name);
    }
    defer allocator.free(install_dir_path);
    defer allocator.free(dest_file_name);

    // Construct full install path
    const install_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir_path, dest_file_name });
    defer allocator.free(install_path);

    // Open current working directory
    const cwd = std.fs.cwd();

    // Verify source file exists
    cwd.access(bin_path, .{}) catch |err| {
        terminal.printError("Source file '{s}' not found: {s}\n", .{ bin_path, @errorName(err) });
        terminal.printColored(.yellow, "💡 Make sure you've built your CLI with: zig build\n", .{});
        return err;
    };

    // Create destination directory
    var dest_dir = cwd.makeOpenPath(install_dir_path, .{}) catch |err| {
        terminal.printError("Failed to create directory '{s}': {s}\n", .{ install_dir_path, @errorName(err) });
        return err;
    };
    defer dest_dir.close();

    // Check if file already exists
    if (!force_install) {
        if (dest_dir.access(dest_file_name, .{})) |_| {
            // File exists, ask for confirmation
            const should_overwrite = try terminal.confirm("File already exists. Overwrite?");
            if (!should_overwrite) {
                terminal.printColored(.yellow, "Installation cancelled.\n", .{});
                return;
            }
        } else |err| switch (err) {
            error.FileNotFound => {}, // File doesn't exist, proceed
            else => {
                terminal.printError("Failed to check existing file: {s}\n", .{@errorName(err)});
                return err;
            },
        }
    }

    // Copy the binary
    cwd.copyFile(bin_path, dest_dir, dest_file_name, .{}) catch |err| {
        terminal.printError("Failed to copy '{s}' to '{s}': {s}\n", .{ bin_path, install_path, @errorName(err) });
        return err;
    };

    terminal.printColored(.green, "✅ Successfully installed '{s}' to: {s}\n", .{ cli_name, install_path });

    // Check and update PATH if necessary
    try updatePathIfNeeded(allocator, install_dir_path, os_tag);

    terminal.printColored(.cyan, "🎉 Installation complete! You can now use: {s}\n", .{cli_name});
}

fn updatePathIfNeeded(allocator: std.mem.Allocator, install_dir_path: []const u8, os_tag: std.Target.Os.Tag) !void {
    const path_env = std.process.getEnvVarOwned(allocator, "PATH") catch |err| {
        terminal.printColored(.yellow, "⚠️  Could not detect PATH environment: {s}\n", .{@errorName(err)});
        terminal.printColored(.yellow, "Add to PATH manually: {s}\n", .{install_dir_path});
        return;
    };
    defer allocator.free(path_env);

    // Check if install directory is already in PATH
    const separator = if (os_tag == .windows) ";" else ":";
    var path_iterator = std.mem.splitScalar(u8, path_env, separator[0]);

    while (path_iterator.next()) |path_entry| {
        if (std.mem.eql(u8, std.mem.trim(u8, path_entry, " "), install_dir_path)) {
            terminal.printColored(.green, "ℹ️  '{s}' is already in your PATH.\n", .{install_dir_path});
            return;
        }
    }

    // Directory is not in PATH, attempt to add it
    terminal.printColored(.yellow, "⚠️  '{s}' is not in your PATH. Attempting to add it automatically...\n", .{install_dir_path});

    if (os_tag == .windows) {
        try updateWindowsPath(allocator, path_env, install_dir_path);
    } else {
        try updateUnixPath(allocator, install_dir_path);
    }
}

fn updateWindowsPath(allocator: std.mem.Allocator, current_path: []const u8, install_dir_path: []const u8) !void {
    // Validate PATH length (Windows max is ~2047 chars for user PATH)
    const new_path_len = current_path.len + 1 + install_dir_path.len; // +1 for semicolon
    if (new_path_len > 2047) {
        terminal.printError("Failed to add '{s}' to PATH: PATH length would exceed 2047 characters.\n", .{install_dir_path});
        terminal.printColored(.yellow, "Add manually:\n", .{});
        terminal.printColored(.white, "1. Open Control Panel -> System -> Advanced system settings -> Environment Variables\n", .{});
        terminal.printColored(.white, "2. Edit 'Path' under 'User variables' and append '{s}'\n", .{install_dir_path});
        return;
    }

    // Use setx to append to user PATH
    const setx_cmd = try std.fmt.allocPrint(allocator, "setx PATH \"{s};{s}\"", .{ current_path, install_dir_path });
    defer allocator.free(setx_cmd);

    var setx_process = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", setx_cmd }, allocator);
    setx_process.stdout_behavior = .Pipe;
    setx_process.stderr_behavior = .Pipe;

    try setx_process.spawn();

    // Capture output
    var stdout = std.ArrayListUnmanaged(u8){};
    defer stdout.deinit(allocator);
    var stderr = std.ArrayListUnmanaged(u8){};
    defer stderr.deinit(allocator);

    try setx_process.collectOutput(allocator, &stdout, &stderr, 1024 * 1024);
    const term = try setx_process.wait();

    if (term == .Exited and term.Exited == 0) {
        terminal.printColored(.green, "✅ Successfully added '{s}' to user PATH.\n", .{install_dir_path});
        terminal.printColored(.cyan, "🔄 Restart your terminal to apply changes.\n", .{});
    } else {
        terminal.printError("Failed to add '{s}' to PATH. Error output: {s}\n", .{ install_dir_path, stderr.items });
        terminal.printColored(.yellow, "Add manually:\n", .{});
        terminal.printColored(.white, "1. Open Control Panel -> System -> Advanced system settings -> Environment Variables\n", .{});
        terminal.printColored(.white, "2. Edit 'Path' under 'User variables' and append '{s}'\n", .{install_dir_path});
    }
}

fn updateUnixPath(allocator: std.mem.Allocator, install_dir_path: []const u8) !void {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch ".";
    defer if (!std.mem.eql(u8, home, ".")) allocator.free(home);

    // Try common shell profiles
    const shell_profiles = [_][]const u8{ ".bashrc", ".zshrc", ".bash_profile", ".profile" };
    var profile_updated = false;

    for (shell_profiles) |profile| {
        const profile_path = try std.fs.path.join(allocator, &[_][]const u8{ home, profile });
        defer allocator.free(profile_path);

        // Check if profile exists
        const profile_file = std.fs.cwd().openFile(profile_path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => continue, // Try next profile
            else => return err,
        };
        defer profile_file.close();

        // Read existing content to avoid duplicates
        const content = try profile_file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        const export_line = try std.fmt.allocPrint(allocator, "export PATH=\"{s}:$PATH\"", .{install_dir_path});
        defer allocator.free(export_line);

        // Check if the export line already exists
        if (std.mem.indexOf(u8, content, export_line)) |_| {
            // Already exists in this profile
            terminal.printColored(.green, "✅ PATH already configured in ~/{s}\n", .{profile});
            profile_updated = true;
            break;
        }

        // Append the export line
        try profile_file.seekTo(try profile_file.getEndPos());
        try profile_file.writer().print("\n# Added by ziglet installer\n{s}\n", .{export_line});

        terminal.printColored(.green, "✅ Added '{s}' to PATH in ~/{s}\n", .{ install_dir_path, profile });
        terminal.printColored(.cyan, "🔄 Run 'source ~/{s}' or restart your terminal to apply changes.\n", .{profile});
        profile_updated = true;
        break;
    }

    if (!profile_updated) {
        terminal.printColored(.yellow, "❌ Could not find a suitable shell profile to update.\n", .{});
        terminal.printColored(.white, "Add to PATH manually: export PATH=\"{s}:$PATH\"\n", .{install_dir_path});
    }
}
