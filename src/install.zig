const std = @import("std");
const ArgParser = @import("lib/parser/parser.zig").ArgParser;
const terminal = @import("utils/terminal.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Set console to UTF-8 on Windows
    terminal.setWinConsole();

    // Parse command-line arguments
    var args = try std.process.argsAlloc(allocator);

    var parser = try ArgParser().init(allocator, args[0..]);
    defer parser.deinit();

    const result = try parser.parse();

    var cli_name: []const u8 = undefined;
    if (result.get("name")) |name| {
        cli_name = name;
    } else {
        var buffer: [100]u8 = undefined;
        const message = try terminal.bufPrintC("'--name' flag is required", &[_]terminal.Color{.red}, &buffer);
        std.debug.print("{s}\n", .{message});
        return;
    }

    // Determine source binary location
    const bin_path = try std.fmt.allocPrintZ(allocator, "zig-out/bin/{s}{s}", .{
        cli_name,
        if (@import("builtin").os.tag == .windows) ".exe" else "",
    });
    defer allocator.free(bin_path);

    // Detect platform
    const os_tag = @import("builtin").os.tag;

    var install_dir_path: []const u8 = undefined;
    var dest_file_name: []const u8 = undefined;

    if (os_tag == .windows) {
        // Windows install path: %USERPROFILE%\ziglet\bin\<cli_name>.exe
        const home = try std.process.getEnvVarOwned(allocator, "USERPROFILE");
        defer allocator.free(home);

        install_dir_path = try std.fs.path.joinZ(allocator, &[_][]const u8{ home, "ziglet", "bin" });
        dest_file_name = try std.fmt.allocPrintZ(allocator, "{s}.exe", .{cli_name});
    } else {
        // Unix-based install path: ~/.local/bin/<cli_name>
        const home = try std.process.getEnvVarOwned(allocator, "HOME") orelse try allocator.dupeZ(u8, ".");
        defer allocator.free(home);

        install_dir_path = try std.fs.path.joinZ(allocator, &[_][]const u8{ home, ".local", "bin" });
        dest_file_name = cli_name;
    }
    defer allocator.free(install_dir_path);
    defer allocator.free(dest_file_name);

    // Construct full install path for display
    const install_path = try std.fs.path.joinZ(allocator, &[_][]const u8{ install_dir_path, dest_file_name });
    defer allocator.free(install_path);

    // Open the current working directory
    const cwd = std.fs.cwd();

    // Verify source file exists
    cwd.access(bin_path, .{}) catch |err| {
        std.debug.print("Error: Source file {s} not found or inaccessible: {s}\n", .{ bin_path, @errorName(err) });
        return err;
    };

    // Create and open the destination directory
    var dest_dir = try cwd.makeOpenPath(install_dir_path, .{});
    defer dest_dir.close();

    // Copy the binary
    cwd.copyFile(bin_path, dest_dir, dest_file_name, .{}) catch |err| {
        std.debug.print("Error: Failed to copy {s} to {s}: {s}\n", .{ bin_path, install_path, @errorName(err) });
        return err;
    };

    var buffer: [1024]u8 = undefined;

    const buffer_result = try std.fmt.bufPrint(&buffer, "✅  Installed '{s}' to: {s}", .{ cli_name, install_path });

    var rbuffer: [1024]u8 = undefined;

    std.debug.print("{s}\n", .{try terminal.bufPrintC(buffer_result, &[_]terminal.Color{.green}, &rbuffer)});

    // Check if install_dir_path is in PATH and add if necessary
    if (std.process.getEnvVarOwned(allocator, "PATH")) |path_env| {
        defer allocator.free(path_env);
        if (!std.mem.containsAtLeast(u8, path_env, 1, install_dir_path)) {
            const wbr = try std.fmt.bufPrint(&buffer, "'{s}' is not in your PATH. Attempting to add it automatically...", .{install_dir_path});

            std.debug.print("\n⚠️  {s}:\n", .{try terminal.bufPrintC(wbr, &[_]terminal.Color{.yellow}, &rbuffer)});

            if (os_tag == .windows) {
                // Validate PATH length (Windows max is ~2047 chars for user PATH)
                const new_path_len = path_env.len + 1 + install_dir_path.len; // +1 for semicolon
                if (new_path_len > 2047) {
                    std.debug.print("❌ Failed to add '{s}' to PATH: PATH length would exceed 2047 characters.\n", .{install_dir_path});
                    std.debug.print("Add it manually:\n  1. Open Control Panel -> System -> Advanced system settings -> Environment Variables.\n  2. Edit 'Path' under 'User variables' and append '{s}'.\n", .{install_dir_path});
                    return;
                }

                // Windows: Use setx to append to user PATH
                const setx_cmd = try std.fmt.allocPrintZ(allocator, "setx PATH \"{s};{s}\"", .{ path_env, install_dir_path });
                defer allocator.free(setx_cmd);

                var setx_process = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", setx_cmd }, allocator);
                setx_process.stdout_behavior = .Pipe;
                setx_process.stderr_behavior = .Pipe;

                try setx_process.spawn();

                // Capture output for debugging
                var stdout = std.ArrayListUnmanaged(u8){};
                defer stdout.deinit(allocator);
                var stderr = std.ArrayListUnmanaged(u8){};
                defer stderr.deinit(allocator);

                try setx_process.collectOutput(allocator, &stdout, &stderr, 1024 * 1024); // 1MB max
                const term = try setx_process.wait();

                if (term.Exited == 0) {
                    std.debug.print("✅ Successfully added '{s}' to user PATH. Restart your terminal to apply changes.\n", .{install_dir_path});
                } else {
                    std.debug.print("❌ Failed to add '{s}' to PATH. Error output: {s}\n", .{ install_dir_path, stderr.items });
                    std.debug.print("Add it manually:\n  1. Open Control Panel -> System -> Advanced system settings -> Environment Variables.\n  2. Edit 'Path' under 'User variables' and append '{s}'.\n", .{install_dir_path});
                }
            } else { // Unix: Append to ~/.bashrc or ~/.zshrc
                const home = try std.process.getEnvVarOwned(allocator, "HOME") orelse ".";
                defer allocator.free(home);

                // Try common shell profiles
                const shell_profiles = [_][]const u8{ ".bashrc", ".zshrc", ".bash_profile" };
                var profile_updated = false;

                for (shell_profiles) |profile| {
                    const profile_path = try std.fs.path.joinZ(allocator, &[_][]const u8{ home, profile });
                    defer allocator.free(profile_path);

                    // Check if profile exists
                    if (std.fs.cwd().access(profile_path, .{}) catch null) |_| {
                        var file = try std.fs.cwd().openFile(profile_path, .{ .mode = .read_write });
                        defer file.close();

                        // Read existing content to avoid duplicates
                        const content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
                        defer allocator.free(content);

                        const export_line = try std.fmt.allocPrint(allocator, "\nexport PATH=\"{s}:$PATH\"\n", .{install_dir_path});
                        defer allocator.free(export_line);

                        if (!std.mem.containsAtLeast(u8, content, 1, export_line)) {
                            try file.seekTo(try file.getEndPos());
                            try file.writeAll(export_line);
                            profile_updated = true;
                            std.debug.print("✅ Added '{s}' to PATH in ~/{s}. Source the file or restart your terminal.\n", .{ install_dir_path, profile });
                            break;
                        }
                    }
                }

                if (!profile_updated) {
                    std.debug.print("❌ Could not find a suitable shell profile to update. Add to PATH manually:\n  export PATH=\"{s}:$PATH\"\n", .{install_dir_path});
                }
            }
        } else {
            std.debug.print("ℹ️  '{s}' is already in your PATH.\n", .{install_dir_path});
        }
    } else |_| {
        std.debug.print("\n⚠️  {s}\n", .{try terminal.bufPrintC("Could not detect PATH environment. You may need to update it manually.", &[_]terminal.Color{.yellow}, &buffer)});
    }
}
