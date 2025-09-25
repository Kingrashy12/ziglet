# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- **API Changes**: The `parse()` function now requires a second parameter `builder_commands: ?[]const *CommandBuilder` when using factory pattern
- **Action Functions**: All command action functions must now accept `ActionArg` struct instead of separate args and options parameters
- **Option Definition**: Options are now defined using `CLIOption` struct with more structured fields

### Examples

- Added comprehensive examples in `examples/` directory demonstrating global options, multiple commands, and factory pattern usage
