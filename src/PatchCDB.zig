const std = @import("std");
const PatchCDB = @This();

pub const base_id: std.Build.Step.Id = .custom;

step: std.Build.Step,
cdb_path: std.Build.LazyPath,

pub fn create(b: *std.Build, cdb_path: std.Build.LazyPath) *PatchCDB {
    const self = b.allocator.create(PatchCDB) catch @panic("OOM");
    self.* = .{
        .step = .init(.{
            .id = base_id,
            .name = "patch_cdb",
            .owner = b,
            .makeFn = make,
        }),
        .cdb_path = cdb_path.dupe(b),
    };
    self.cdb_path.addStepDependencies(&self.step);
    return self;
}

const Entry = struct {
    directory: []const u8,
    file: []const u8,
    arguments: ?[]const []const u8 = null,
    command: ?[]const u8 = null,
    output: ?[]const u8 = null,
};

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const self: *PatchCDB = @fieldParentPtr("step", step);

    const cdb_path = self.cdb_path.getPath2(b, step);
    const cdb_maxsize = 50 * 1024 * 1024;
    const cdb_content = std.fs.cwd().readFileAlloc(b.allocator, cdb_path, cdb_maxsize) catch |err| {
        return step.fail("unable to read '{s}': {s}", .{ cdb_path, @errorName(err) });
    };

    // read as json
    const cdb_parsed: std.json.Parsed([]Entry) = std.json.parseFromSlice(
        []Entry,
        b.allocator,
        cdb_content,
        .{ .ignore_unknown_fields = true },
    ) catch |err| {
        return step.fail("unable to parse '{s}': {s}", .{ cdb_path, @errorName(err) });
    };
    defer cdb_parsed.deinit();

    var ok = true;

    // replace the argv[0] with clang, remove -mcpu=*
    for (cdb_parsed.value) |*entry| {
        if (entry.arguments) |arguments| {
            if (std.mem.eql(u8, arguments[0], "clang"))
                continue;
            ok = false;
            var argv: std.ArrayList([]const u8) = .empty;
            defer argv.deinit(b.allocator);
            try argv.ensureTotalCapacity(b.allocator, arguments.len);
            argv.appendAssumeCapacity("clang");
            for (arguments[1..]) |arg| {
                if (!std.mem.startsWith(u8, arg, "-mcpu="))
                    argv.appendAssumeCapacity(arg);
            }
            entry.arguments = try argv.toOwnedSlice(b.allocator);
        } else if (entry.command) |_| {
            return step.fail("please use the `arguments` field instead of the `command` field", .{});
        }
    }

    // fast path: nothing to patch
    if (ok) {
        step.result_cached = true;
        return;
    }

    const cdb_file = std.fs.cwd().createFile(cdb_path, .{}) catch |err| {
        return step.fail("unable to open '{s}': {s}", .{ cdb_path, @errorName(err) });
    };
    defer cdb_file.close();

    var writer = cdb_file.writer(try b.allocator.alloc(u8, 64 * 1024));

    try writer.interface.writeAll("[");
    for (cdb_parsed.value, 0..) |entry, i| {
        if (i == 0) {
            try writer.interface.writeAll("\n  ");
        } else {
            try writer.interface.writeAll(",\n  ");
        }
        try std.json.Stringify.value(entry, .{ .emit_null_optional_fields = false }, &writer.interface);
    }
    try writer.interface.writeAll("\n]\n");
    try writer.interface.flush();
}
