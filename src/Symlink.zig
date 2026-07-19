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

    var path_buf1: [std.fs.max_path_bytes]u8 = undefined;
    const build_root = try b.build_root.handle.realpath(".", &path_buf1);

    const symlink_path = b.pathResolve(&.{ build_root, self.symlink_filename });
    const symlink_path_dir = std.fs.path.dirname(symlink_path).?;

    var path_buf2: [std.fs.max_path_bytes]u8 = undefined;
    const target_path_raw = self.point_to_path.getPath3(b, step);
    const target_path_abs = try target_path_raw.root_dir.handle.realpath(target_path_raw.sub_path, &path_buf2);

    // convert the target_path to a relative path
    const target_path_rel = try std.fs.path.relative(b.allocator, symlink_path_dir, target_path_abs);

    // make sure the symlink's directory exists
    if (std.fs.path.dirname(self.symlink_filename)) |dirname| {
        b.build_root.handle.makePath(dirname) catch |err| {
            return step.fail("unable to make path '{s}': {s}", .{
                symlink_path_dir, @errorName(err),
            });
        };
    }

    // delete the old symlink if it exists
    b.build_root.handle.deleteFile(self.symlink_filename) catch |err| switch (err) {
        error.FileNotFound => {}, // that's fine
        else => return step.fail("unable to delete old symlink '{s}': {s}", .{
            symlink_path, @errorName(err),
        }),
    };

    b.build_root.handle.symLink(target_path_rel, self.symlink_filename, .{ .is_directory = true }) catch |err| {
        return step.fail("unable to create symlink '{s}' pointing to '{s}': {s}", .{
            symlink_path, target_path_rel, @errorName(err),
        });
    };
}
