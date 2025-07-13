const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define the target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a module for the library
    const ziglet_lib = b.addLibrary(.{ .linkage = .static, .name = "ziglet", .root_module = lib_mod });

    b.installArtifact(ziglet_lib);
}
