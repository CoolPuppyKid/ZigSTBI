const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zigstbi = b.addModule("zigstbi", .{ .root_source_file = b.path("src/root.zig"), .optimize = optimize, .target = target });

    zigstbi.addIncludePath(b.path("include"));
    zigstbi.addCSourceFile(.{
        .file = b.path("include/stb_image.c"),
        .flags = &.{
            "-std=c99",
        },
        .language = .c,
    });
    zigstbi.link_libc = true;

    const test_step = b.step("test", "Run tests (NO ITS NOT SHUTTING DOWN!!!)");

    const tests = b.addTest(.{ .name = "zig-stbi-tests", .root_module = zigstbi });
    tests.linkLibC();
    tests.addIncludePath(b.path("include"));
    tests.addCSourceFile(.{
        .file = b.path("include/stb_image.c"),
        .flags = &.{
            "-std=c99",
        },
        .language = .c,
    });

    b.installArtifact(tests);
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
