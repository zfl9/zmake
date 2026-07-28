const std = @import("std");

/// please @import("zmake") directly in your build.zig file
pub fn build(_: *std.Build) void {}

// public API
pub const ZMake = @import("src/ZMake.zig");
pub const Pipeline = @import("src/Pipeline.zig");
pub const Symlink = @import("src/Symlink.zig");
pub const PatchCDB = @import("src/PatchCDB.zig");
pub const GenFileProxy = @import("src/GenFileProxy.zig");

test {
    _ = &ZMake;
    _ = &Pipeline;
    _ = &Symlink;
    _ = &PatchCDB;
    _ = &GenFileProxy;
}
