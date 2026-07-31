const std = @import("std");
const assert = std.debug.assert;
const GenFileProxy = @This();

pub const base_id: std.Build.Step.Id = .custom;

step: std.Build.Step,
genfile: std.Build.GeneratedFile,
underlying: *const std.Build.GeneratedFile,

pub fn proxy_for(b: *std.Build, underlying_path: std.Build.LazyPath, depends: []const *std.Build.Step) std.Build.LazyPath {
    if (underlying_path != .generated)
        std.debug.panic("GenFileProxy.proxy_for() only accepts GeneratedFile, got {s}", .{@tagName(underlying_path)});

    const gen_file_proxy = create(b, underlying_path.generated.file);

    // inject dependencies
    for (depends) |dep|
        gen_file_proxy.step.dependOn(dep);

    return .{
        .generated = .{
            .file = gen_file_proxy,
            .up = underlying_path.generated.up,
            .sub_path = underlying_path.generated.sub_path,
        },
    };
}

pub fn create(b: *std.Build, underlying: *const std.Build.GeneratedFile) *std.Build.GeneratedFile {
    const self = b.allocator.create(GenFileProxy) catch @panic("OOM");
    self.* = .{
        .step = .init(.{
            .id = base_id,
            .name = b.fmt("gen_file_proxy {s}", .{underlying.step.name}),
            .owner = b,
            .makeFn = make,
        }),
        .genfile = .{
            .step = &self.step,
        },
        .underlying = underlying,
    };
    self.step.dependOn(underlying.step);
    return &self.genfile;
}

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    _ = options;
    const self: *GenFileProxy = @fieldParentPtr("step", step);

    assert(self.underlying.path != null);
    self.genfile.path = self.underlying.path;

    self.step.result_cached = self.underlying.step.result_cached;
}

test "compile-check" {
    _ = &base_id;
    _ = &proxy_for;
    _ = &create;
    _ = &make;
}
