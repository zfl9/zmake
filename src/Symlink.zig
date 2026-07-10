const std = @import("std");
const Symlink = @This();

pub const base_id: std.Build.Step.Id = .custom;

step: std.Build.Step,
symlink_filename: []const u8,
point_to_path: std.Build.LazyPath,

pub fn create(
    b: *std.Build,
    /// relative to the build root
    symlink_filename: []const u8,
    point_to_path: std.Build.LazyPath,
) *Symlink {
    if (std.fs.path.isAbsolute(symlink_filename))
        @panic("symlink path must be relative to the build root");
    if (symlink_filename.len == 0)
        @panic("symlink path must not be empty");

    const self = b.allocator.create(Symlink) catch @panic("OOM");
    self.* = .{
        .step = .init(.{
            .id = base_id,
            .name = b.fmt("symlink {s}", .{symlink_filename}),
            .owner = b,
            .makeFn = make,
        }),
        .symlink_filename = b.dupe(symlink_filename),
        .point_to_path = point_to_path.dupe(b),
    };

    // make sure the `point_to_path` is available before the `make()` is called
    self.point_to_path.addStepDependencies(&self.step);

    return self;
}

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const self: *Symlink = @fieldParentPtr("step", step);

    // convert the target_path to a relative path
    const build_root_path = b.build_root.path orelse std.process.getCwdAlloc(b.allocator) catch @panic("OOM");
    const symlink_path = std.fs.path.resolve(b.allocator, &.{ build_root_path, self.symlink_filename }) catch @panic("OOM");
    const symlink_dir_path = std.fs.path.dirname(symlink_path) orelse build_root_path;
    const raw_target_path = self.point_to_path.getPath3(b, step).toString(b.allocator) catch @panic("OOM");
    const target_path = std.fs.path.relative(b.allocator, symlink_dir_path, raw_target_path) catch @panic("OOM");

    // make sure the symlink's directory exists
    if (std.fs.path.dirname(self.symlink_filename)) |dirname| {
        b.build_root.handle.makePath(dirname) catch |err| {
            return step.fail("unable to make path '{f}{s}': {s}", .{
                b.build_root, dirname, @errorName(err),
            });
        };
    }

    // delete the old symlink if it exists
    b.build_root.handle.deleteFile(self.symlink_filename) catch |err| switch (err) {
        error.FileNotFound => {}, // that's fine
        else => return step.fail("unable to delete old symlink '{f}{s}': {s}", .{
            b.build_root, self.symlink_filename, @errorName(err),
        }),
    };

    b.build_root.handle.symLink(target_path, self.symlink_filename, .{ .is_directory = true }) catch |err| {
        return step.fail("unable to create symlink '{f}{s}' pointing to '{s}': {s}", .{
            b.build_root, self.symlink_filename, target_path, @errorName(err),
        });
    };
}
