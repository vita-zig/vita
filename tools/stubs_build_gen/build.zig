const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tree_sitter_host_dep = b.dependency("tree_sitter", .{
        .target = b.graph.host,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("treez", tree_sitter_host_dep.module("treez"));

    const exe = b.addExecutable(.{
        .name = "stubs_build_gen",
        .root_module = exe_mod,
    });
    exe.linkLibC();

    const exe_check = b.addExecutable(.{
        .name = "foo",
        .root_module = exe_mod,
    });
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);

    b.installArtifact(exe);
}
