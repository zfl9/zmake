const std = @import("std");
const CopyFile = @This();

pub const base_id: std.Build.Step.Id = .custom;

step: std.Build.Step,
src_file: std.Build.LazyPath,
dest_file: std.Build.LazyPath,

pub fn create(
    b: *std.Build,
    src_file: std.Build.LazyPath,
    dest_dir: std.Build.LazyPath,
    dest_filename: []const u8,
) *CopyFile {
    const self = b.allocator.create(CopyFile) catch @panic("OOM");

    self.* = .{
        .step = .init(.{
            .id = base_id,
            .name = b.fmt("copy {s}", .{dest_filename}),
            .owner = b,
            .makeFn = make,
        }),
        .src_file = src_file.dupe(b),
        .dest_file = dest_dir.path(b, dest_filename),
    };

    src_file.addStepDependencies(&self.step);
    dest_dir.addStepDependencies(&self.step);

    return self;
}

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const self: *CopyFile = @fieldParentPtr("step", step);

    const src_file = self.src_file.getPath3(b, step);
    const dest_file = self.dest_file.getPath3(b, step);

    const status = try std.fs.Dir.updateFile(src_file.root_dir.handle, src_file.sub_path, dest_file.root_dir.handle, dest_file.sub_path, .{});
    if (status == .fresh)
        step.result_cached = true;
}

test "compile-check" {
    _ = &base_id;
    _ = &create;
    _ = &make;
}
