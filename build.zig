pub const Vita = @This();

builder: *Build,
vita_dep: *Build.Dependency,
vita_toolchain: *Build.Dependency,
target: std.Build.ResolvedTarget,

const VitaTarget: std.Target.Query = .{
    .cpu_arch = .thumb,
    .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a9 },
    .os_tag = .freestanding,
    .abi = .eabihf,
};

pub fn init(b: *Build, vita_dep: *Build.Dependency) Vita {
    const target = b.resolveTargetQuery(VitaTarget);

    return .{
        .builder = b,
        .vita_dep = vita_dep,
        .vita_toolchain = vita_dep.builder.dependency("vita_toolchain", .{ .optimize = .ReleaseFast }),
        .target = target,
    };
}

const PackageOptions = struct {
    name: []const u8,
    title_id: []const u8,
    version: std.SemanticVersion,
    parental_level: usize,
    optimize: std.builtin.OptimizeMode,
    root_source_file: ?LazyPath = null,
};

pub fn addPackage(self: *const Vita, options: PackageOptions) Package {
    const b = self.builder;
    const vita_toolchain = self.vita_toolchain;

    const exe_mod = b.createModule(.{
        .target = self.target,
        .optimize = options.optimize,
        .root_source_file = options.root_source_file,
    });

    const exe = b.addExecutable(.{
        .name = options.name,
        .root_module = exe_mod,
    });

    const vita_elf_create = b.addRunArtifact(vita_toolchain.artifact("vita-elf-create"));
    // vita_elf_create.addArg("-n"); // TODO: add .vitalink section
    vita_elf_create.addArtifactArg(exe);
    const velf = vita_elf_create.addOutputFileArg(std.fmt.allocPrint(b.allocator, "{s}.velf", .{options.name}) catch @panic("OOM"));

    const vita_make_fself = b.addRunArtifact(vita_toolchain.artifact("vita-make-fself"));
    vita_make_fself.addFileArg(velf);
    const vita_self = vita_make_fself.addOutputFileArg(std.fmt.allocPrint(b.allocator, "{s}.self", .{options.name}) catch @panic("OOM"));

    const vita_mksfoex = b.addRunArtifact(vita_toolchain.artifact("vita-mksfoex"));
    vita_mksfoex.addArgs(&.{
        "-d",
        std.fmt.allocPrint(b.allocator, "PARENTAL_LEVEL={d}", .{options.parental_level}) catch @panic("OOM"),
        "-s",
        // TODO: check if proper semver is supported
        "APP_VER=01.00",
        // std.fmt.allocPrint(b.allocator, "0{d}.{d}.{d}", .{ options.version.major, options.version.minor, options.version.patch }) catch @panic("OOM"),
        "-s",
        std.mem.concat(b.allocator, u8, &.{ "TITLE_ID=", options.title_id }) catch @panic("OOM"),
        options.name, // TODO: pretty name
    });
    const sfo = vita_mksfoex.addOutputFileArg(std.fmt.allocPrint(b.allocator, "{s}.vpk_param.sfo", .{options.name}) catch @panic("OOM"));

    const vita_pack_vpk = b.addRunArtifact(vita_toolchain.artifact("vita-pack-vpk"));
    // TODO: more metadata
    vita_pack_vpk.addArg("-s");
    vita_pack_vpk.addFileArg(sfo);
    vita_pack_vpk.addArg("-b");
    vita_pack_vpk.addFileArg(vita_self);
    const vpk = vita_pack_vpk.addOutputFileArg(std.fmt.allocPrint(b.allocator, "{s}.vpk", .{options.name}) catch @panic("OOM"));

    return Package{
        .vita = self,
        .root_module = exe_mod,
        .artifact = exe,
        .velf = velf,
        .self = vita_self,
        .vpk = vpk,
    };
}

const Package = struct {
    vita: *const Vita,
    artifact: *Compile,
    root_module: *Module,
    velf: LazyPath,
    self: LazyPath,
    vpk: LazyPath,

    pub fn linkSystemModule(self: Package, stub: stubs.Stubs) void {
        self.artifact.linkLibrary(self.vita.vita_dep.artifact(@tagName(stub)));
    }

    pub fn installVpk(self: Package, b: *std.Build) void {
        const name = std.mem.concat(b.allocator, u8, &.{ "bin/", self.artifact.name, ".vpk" }) catch @panic("oom");
        b.getInstallStep().dependOn(&b.addInstallFile(self.vpk, name).step);
    }

    pub fn installVelf(self: Package, b: *std.Build) void {
        const name = std.mem.concat(b.allocator, u8, &.{ "bin/", self.artifact.name, ".velf" }) catch @panic("oom");
        b.getInstallStep().dependOn(&b.addInstallFile(self.velf, name).step);
    }

    pub fn installSelf(self: Package, b: *std.Build) void {
        const name = std.mem.concat(b.allocator, u8, &.{ "bin/", self.artifact.name, ".self" }) catch @panic("oom");
        b.getInstallStep().dependOn(&b.addInstallFile(self.self, name).step);
    }
};

pub fn build(b: *std.Build) void {
    const stubs_build_gen_dep = b.dependency("stubs_build_gen", .{});
    const vita_toolchain = b.dependency("vita_toolchain", .{ .optimize = .ReleaseFast });
    const vita_headers = b.dependency("vita-headers", .{});

    const vita_libs_gen = b.addRunArtifact(vita_toolchain.artifact("vita-libs-gen-2"));
    vita_libs_gen.addPrefixedDirectoryArg("-yml=", vita_headers.path("db/"));
    const stubs_dir = vita_libs_gen.addPrefixedOutputDirectoryArg("-output=", "stubs/");

    const stubs_build_run = b.addRunArtifact(stubs_build_gen_dep.artifact("stubs_build_gen"));
    stubs_build_run.addFileArg(stubs_dir.path(b, "/makefile"));
    stubs_build_run.addFileArg(b.path("build/stubs.zig"));

    const update_stubs_step = b.step("update-stubs", "");
    update_stubs_step.dependOn(&stubs_build_run.step);

    const target = b.resolveTargetQuery(VitaTarget);
    stubs.build(b, target, stubs_dir);
}

const std = @import("std");
const Build = std.Build;
const Compile = Build.Step.Compile;
const Module = Build.Module;
const LazyPath = Build.LazyPath;

pub const GenerateLibcFile = @import("build/GenerateLibcFile.zig");
pub const stubs = @import("build/stubs.zig");
