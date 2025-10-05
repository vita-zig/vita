pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var args_iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // exe
    const input = args_iter.next().?;
    const output = args_iter.next().?;

    const parser = try treez.Parser.create();
    defer parser.destroy();

    const make_langauge = try treez.Language.get("make");
    try parser.setLanguage(make_langauge);

    const input_file = try std.fs.cwd().openFile(input, .{});
    defer input_file.close();

    const output_file = try std.fs.cwd().createFile(output, .{ .truncate = true });
    defer output_file.close();

    const content = try input_file.readToEndAlloc(allocator, std.math.maxInt(usize));

    const tree = try parser.parseString(null, content);
    defer tree.destroy();

    var stubs_list = std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator);
    defer stubs_list.deinit();

    const writer = output_file.writer();

    // tree.printDotGraph(output_file);
    var root_iter = tree.getRootNode().childIterator();
    while (root_iter.next()) |child| {
        const child_type = child.getType();
        // std.debug.print("type: {s}\n", .{child_type});

        if (!std.mem.eql(u8, child_type, "variable_assignment")) continue;

        const name_child = child.getChild(0);
        const name_range = name_child.getRange();
        const name = content[name_range.start_byte..name_range.end_byte];

        if (!std.mem.endsWith(u8, name, "_OBJS")) continue;
        if (std.mem.endsWith(u8, name, "weak_OBJS")) continue;
        if (std.mem.eql(u8, name, "ALL_OBJS")) continue;
        // if (!std.mem.eql(u8, name, "SceLibKernel_OBJS")) continue;

        const targets_node = child.getChild(child.getChildCount() - 1);
        const targets_node_range = targets_node.getRange();
        const targets = content[targets_node_range.start_byte..targets_node_range.end_byte];
        var targets_iterator = std.mem.splitScalar(u8, targets, ' ');

        while (targets_iterator.next()) |target| {
            var object_file_name_iterator = std.mem.splitScalar(u8, target, '_');
            const module = object_file_name_iterator.next().?;
            const library = object_file_name_iterator.next() orelse {
                std.debug.print("failed to parse: {s}\n", .{target});
                continue;
            };
            const symbol = object_file_name_iterator.next().?;
            // _ = module;
            _ = library;
            _ = symbol;
            const gop = try stubs_list.getOrPut(module);
            if (!gop.found_existing) {
                gop.value_ptr.* = .init(allocator);
            }
            const target_assembly = try allocator.dupe(u8, target);
            target_assembly[target_assembly.len - 1] = 'S';

            try gop.value_ptr.append(target_assembly);
        }
    }

    try writer.print("const std = @import(\"std\");\n", .{});
    var stubs_iter = stubs_list.iterator();
    while (stubs_iter.next()) |entry| {
        try writer.print("pub fn build{s}(b: *std.Build, target: std.Build.ResolvedTarget, stubs_dir: std.Build.LazyPath) void {{\n", .{entry.key_ptr.*});
        try writer.print(
            \\    const mod = b.createModule(.{{
            \\        .target = target,
            \\        .optimize = .ReleaseSmall,
            \\    }});
            \\    const lib = b.addLibrary(.{{
            \\        .root_module = mod,
            \\        .name = "{s}",
            \\    }});
            \\    b.installArtifact(lib);
            \\    mod.addCSourceFiles(.{{
            \\        .root = stubs_dir,
            \\        .language = .assembly_with_preprocessor,
            \\        .flags = &.{{"-DGEN_WEAK_EXPORTS=0"}},
            \\        .files = &.{{
            \\
        , .{entry.key_ptr.*});

        for (entry.value_ptr.items) |stub| {
            try writer.print("            \"{s}\",\n", .{stub});
        }
        try writer.print("        }},\n", .{});
        try writer.print("    }});\n", .{});
        try writer.print("}}\n", .{});
    }

    try writer.print("pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, stubs_dir: std.Build.LazyPath) void {{\n", .{});
    for (stubs_list.keys()) |lib| {
        try writer.print("    build{s}(b, target, stubs_dir);\n", .{lib});
    }
    try writer.print("}}\n", .{});

    try writer.print("pub const Stubs = enum {{\n", .{});
    for (stubs_list.keys()) |lib| {
        try writer.print("    {},\n", .{std.zig.fmtId(lib)});
    }
    try writer.print("}};\n", .{});
}

const std = @import("std");
const treez = @import("treez");
