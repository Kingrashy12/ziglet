# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-11-04

## Update

- **terminal.zig**:
  - Renamed `read` function to `readLine` for clarity
  - Update input filtering to allow additional characters

## [0.2.3] - 2025-11-01

## Updated

- **terminal.zig**: Added a `toLower` parameter to `read` function to convert strings to lowercase

## [0.2.0] - 2025-10-25

### Added

- **Allocator Field in ActionArg**: Added `allocator` field to `ActionArg` struct for improved memory management in action handlers
- **CLI Utilities Module**: New `cli_utils.zig` module with utility functions (`takeBool`, `takeString`, `takeNumber`) for type-safe value extraction in CLI action functions

### Changed

- **Module Renaming**: Renamed `stdout` module to `terminal` across utils and core files for better naming consistency
- **Parser Improvements**: Enhanced boolean option handling in the parser
- **Project Metadata**: Updated version to 0.2.0 and refreshed project metadata

### Removed

- **Deprecated Install File**: Removed `install.zig` file and associated functionality

## [0.1.4] - 2025-09-25

### Added

- **Global Options Support**: Added `setGlobalOptions()` method to automatically include help (`-h`, `--help`) and version (`-V`, `--version`) flags for all commands
- **Factory Pattern**: Introduced fluent API for building commands using `command().option().action().finalize()` chain
- **Multiple Option Types**: Support for `bool`, `string`, and `number` option types
- **Enhanced Help System**: Command-specific help with `--help` flag, displaying usage and options for individual commands
- **Option Validation**: Automatic validation of required options and type checking
- **Global Option Merging**: Global options are now merged with command-specific options during parsing

### Changed

- **Action Handler Signature**: Updated action handlers to use `fn (ActionArg) anyerror!void` signature with structured `ActionArg` containing `args` and `options`
- **Parse Method**: Modified `parse()` method to accept optional `builder_commands` parameter for factory pattern support

### Breaking Changes

- **Commander Removed**: The previous `Commander` API has been **removed** and replaced with the new **`CLIBuilder`**.
  - Old usage with `ziglet.Commander` has been removed.
  - Use `ziglet.CLIBuilder` for creating and managing commands.
- **API Changes**: The `parse()` function now requires a second parameter `builder_commands: ?[]const *CommandBuilder` when using factory pattern
- **Action Functions**: All command action functions must now accept `ActionArg` struct instead of separate args and options parameters
- **Option Definition**: Options are now defined using `CLIOption` struct with more structured fields

### Examples

- Added comprehensive examples in `examples/` directory demonstrating global options, multiple commands, and factory pattern usage

#### Previous usage (Commander)

```zig
var commander = try ziglet.Commander.init(allocator, "example-cli", "0.1.0", null);
defer commander.deinit();

try commander.addCommand("greet", "Greet someone", greetFn, null);
try commander.checkArgs();
try commander.executeCommand();
```

#### New usage (CLIBuilder)

```zig
var cli = CLIBuilder.init(allocator, "example-cli", "0.1.0", "A simple example CLI using CLIBuilder.");
defer cli.deinit();

cli.setGlobalOptions();

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

try cli.parse(args, null);
```
