pub const GenerateLibcFile = @This();

step: Build.Step,

libc_file: Build.GeneratedFile,

include_dir: ?LazyPath,
sys_include_dir: ?LazyPath,
crt_dir: ?LazyPath,
msvc_lib_dir: ?LazyPath,
kernel32_lib_dir: ?LazyPath,
gcc_dir: ?LazyPath,

pub fn create(owner: *Build, name: []const u8) *GenerateLibcFile {
    const self = owner.allocator.create(GenerateLibcFile) catch @panic("OOM");
    self.* = .{
        .step = .init(.{
            .id = .custom,
            .name = name,
            .owner = owner,
            .makeFn = make,
        }),
        .libc_file = .{ .step = &self.step },
        .include_dir = null,
        .sys_include_dir = null,
        .crt_dir = null,
        .msvc_lib_dir = null,
        .kernel32_lib_dir = null,
        .gcc_dir = null,
    };
    return self;
}

fn make(step: *Build.Step, options: Build.Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const arena = b.allocator;
    const self: *GenerateLibcFile = @fieldParentPtr("step", step);
    step.clearWatchInputs();

    var man = b.graph.cache.obtain();
    defer man.deinit();

    var content = std.array_list.Managed(u8).init(arena);
    defer content.deinit();

    man.hash.add(self.include_dir != null);
    if (self.include_dir) |include_dir| {
        const path = include_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("include_dir={s}\n", .{path});
    } else {
        try content.writer().print("include_dir=\n", .{});
    }

    man.hash.add(self.sys_include_dir != null);
    if (self.sys_include_dir) |sys_include_dir| {
        const path = sys_include_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("sys_include_dir={s}\n", .{path});
    } else {
        try content.writer().print("sys_include_dir=\n", .{});
    }

    man.hash.add(self.crt_dir != null);
    if (self.crt_dir) |crt_dir| {
        const path = crt_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("crt_dir={s}\n", .{path});
    } else {
        try content.writer().print("crt_dir=\n", .{});
    }

    man.hash.add(self.msvc_lib_dir != null);
    if (self.msvc_lib_dir) |msvc_lib_dir| {
        const path = msvc_lib_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("msvc_lib_dir={s}\n", .{path});
    } else {
        try content.writer().print("msvc_lib_dir=\n", .{});
    }

    man.hash.add(self.kernel32_lib_dir != null);
    if (self.kernel32_lib_dir) |kernel32_lib_dir| {
        const path = kernel32_lib_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("kernel32_lib_dir={s}\n", .{path});
    } else {
        try content.writer().print("kernel32_lib_dir=\n", .{});
    }

    man.hash.add(self.gcc_dir != null);
    if (self.gcc_dir) |gcc_dir| {
        const path = gcc_dir.getPath2(b, step);
        man.hash.addBytes(path);
        try content.writer().print("gcc_dir={s}\n", .{path});
    } else {
        try content.writer().print("gcc_dir=\n", .{});
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        const name = "o" ++ std.fs.path.sep_str ++ digest ++ ".txt";
        self.libc_file.path = try b.cache_root.join(arena, &.{name});
        step.result_cached = true;
        return;
    }

    const digest = man.final();
    const name = "o" ++ std.fs.path.sep_str ++ digest ++ ".txt";

    const file = try b.cache_root.handle.createFile(name, .{});
    defer file.close();
    try file.writeAll(content.items);

    self.libc_file.path = try b.cache_root.join(arena, &.{name});

    try step.writeManifest(&man);
}

pub fn getLibcFile(self: *const GenerateLibcFile) LazyPath {
    return .{
        .generated = .{
            .file = &self.libc_file,
        },
    };
}

pub fn setInclueDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.include_dir = lp;
    lp.addStepDependencies(&self.step);
}

pub fn setSysInclueDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.sys_include_dir = lp;
    lp.addStepDependencies(&self.step);
}

pub fn setCrtDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.crt_dir = lp;
    lp.addStepDependencies(&self.step);
}

pub fn setMsvcLibDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.msvc_lib_dir = lp;
    lp.addStepDependencies(&self.step);
}

pub fn setKernel32LibDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.kernel32_lib_dir = lp;
    lp.addStepDependencies(&self.step);
}

pub fn setGccDir(self: *GenerateLibcFile, lp: LazyPath) void {
    self.gcc_dir = lp;
    lp.addStepDependencies(&self.step);
}

const std = @import("std");
const Build = std.Build;
const LazyPath = Build.LazyPath;
