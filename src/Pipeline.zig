const std = @import("std");
const Pipeline = @This();

b: *std.Build,
last_step: ?*std.Build.Step,
cwd: ?std.Build.LazyPath,

pub const InitOptions = struct {
    cwd: ?std.Build.LazyPath = null,
};

pub fn init(b: *std.Build, options: InitOptions) Pipeline {
    return .{
        .b = b,
        .last_step = null,
        .cwd = options.cwd,
    };
}

pub const CommandOptions = struct {
    name: ?[]const u8 = null,
    /// tell zig that it has no side effects
    ignore_stdout: bool = true,
};

/// push a system command into the pipeline
pub fn add_command(self: *Pipeline, program: []const u8, options: CommandOptions) *std.Build.Step.Run {
    const b = self.b;

    const command = b.addSystemCommand(&.{program});

    if (self.cwd) |cwd|
        command.setCwd(cwd);

    if (options.name) |name|
        command.setName(name);

    if (options.ignore_stdout)
        _ = command.captureStdOut();

    self.add_step(&command.step);

    return command;
}

/// push a step into the pipeline
pub fn add_step(self: *Pipeline, step: *std.Build.Step) void {
    if (self.last_step) |last_step|
        step.dependOn(last_step);
    self.last_step = step;
}

pub fn get_last_step(self: *const Pipeline) *std.Build.Step {
    return self.last_step orelse
        @panic("get_last_step() called before any steps were added");
}
