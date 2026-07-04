const std = @import("std");
const Pipeline = @This();

b: *std.Build,
cwd: std.Build.LazyPath,
last_command: ?*std.Build.Step.Run,

pub fn init(b: *std.Build, cwd: std.Build.LazyPath) Pipeline {
    return .{
        .b = b,
        .cwd = cwd,
        .last_command = null,
    };
}

pub const AddOptions = struct {
    name: ?[]const u8 = null,
};

/// the stdout is captured and ignored
pub fn add(self: *Pipeline, program: []const u8, options: AddOptions) *std.Build.Step.Run {
    const b = self.b;

    const command = b.addSystemCommand(&.{program});
    command.setCwd(self.cwd);
    _ = command.captureStdOut(); // tell zig that it has no side effects

    if (options.name) |name|
        command.setName(name);

    if (self.last_command) |last_command|
        command.step.dependOn(&last_command.step);
    self.last_command = command;

    return command;
}
