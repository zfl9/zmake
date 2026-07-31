const std = @import("std");
const CopyFile = @This();

pub const base_id: std.Build.Step.Id = .custom;

step: std.Build.Step,
source: std.Build.LazyPath,
dest_dir: std.Build.LazyPath,
filename: []const u8,

pub fn create(
    b: *std.Build,
    source: std.Build.LazyPath,
    dest_dir: std.Build.LazyPath,
    filename: []const u8,
) *CopyFile {
    const self = b.allocator.create(CopyFile) catch @panic("OOM");
    self.* = .{
        .step = .init(.{
            .id = base_id,
            .name = b.fmt("copy {s}", .{filename}),
            .owner = b,
            .makeFn = make,
        }),
        .source = source.dupe(b),
        .dest_dir = dest_dir.dupe(b),
        .filename = b.dupe(filename),
    };

    source.addStepDependencies(&self.step);
    dest_dir.addStepDependencies(&self.step);

    return self;
}

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const self: *CopyFile = @fieldParentPtr("step", step);

    const src_path = self.source.getPath3(b, step);
    const dst_dir_path = self.dest_dir.getPath3(b, step);

    // the sub_path is absolute for generated outputs
    const dst_dir_abs = dst_dir_path.sub_path;

    // ensure the destination directory exists (no-op if already exists)
    std.fs.cwd().makePath(dst_dir_abs) catch |err| {
        return step.fail("unable to create directory '{s}': {s}", .{
            dst_dir_abs, @errorName(err),
        });
    };

    var dst_dir = std.fs.cwd().openDir(dst_dir_abs, .{}) catch |err| {
        return step.fail("unable to open directory '{s}': {s}", .{
            dst_dir_abs, @errorName(err),
        });
    };
    defer dst_dir.close();

    std.fs.cwd().copyFile(src_path.sub_path, dst_dir, self.filename, .{}) catch |err| {
        return step.fail("unable to copy file '{s}' to '{s}/{s}': {s}", .{
            src_path.sub_path, dst_dir_abs, self.filename, @errorName(err),
        });
    };
}

test "compile-check" {
    _ = &base_id;
    _ = &create;
    _ = &make;
}
