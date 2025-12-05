const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define the target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    // Create a module for the library
    const root = b.addModule("ziglet", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const factory_example_mod = b.addModule("factory_example", .{
        .root_source_file = b.path("examples/factory.zig"),
        .target = target,
        .optimize = optimize,
    });

    const plain_example_mod = b.addModule("plain_example", .{
        .root_source_file = b.path("examples/plain.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add factory example
    const factory_example = b.addExecutable(.{
        .name = "factory",
        .root_module = factory_example_mod,
    });

    // Add plain example
    const plain_example = b.addExecutable(.{
        .name = "plain",
        .root_module = plain_example_mod,
    });

    factory_example.root_module.addImport("ziglet", root);
    b.installArtifact(factory_example);

    plain_example.root_module.addImport("ziglet", root);
    b.installArtifact(plain_example);

    const lib = b.addLibrary(.{
        .root_module = root,
        .name = "ziglet",
    });

    b.installArtifact(lib);

    // Add a test step
    const tests = b.addTest(.{ .root_module = root, .name = "ziglet-tests" });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Add run step for factory and plain module
    const run_cmd = b.addRunArtifact(factory_example);
    const run_plain_cmd = b.addRunArtifact(plain_example);
    if (b.args) |args| {
        run_cmd.addArgs(args);
        run_plain_cmd.addArgs(args);
    }
    const run_step = b.step("run_factory", "Run the factory example");
    const run_plain_step = b.step("run_plain", "Run the plain example");
    run_step.dependOn(&run_cmd.step);
    run_plain_step.dependOn(&run_plain_cmd.step);
}
