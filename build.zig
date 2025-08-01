const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define the target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for the library
    _ = b.addModule("ziglet", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a static library
    const static_lib = b.addStaticLibrary(.{
        .name = "ziglet",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a dynamic library
    const dynamic_lib = b.addSharedLibrary(.{
        .name = "ziglet",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the static and dynamic libraries
    b.installArtifact(static_lib);
    b.installArtifact(dynamic_lib);

    // Add a test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}
