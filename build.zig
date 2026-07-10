const std = @import("std");

// public API
pub const ZMake = @import("src/ZMake.zig");
pub const Pipeline = @import("src/Pipeline.zig");
pub const Symlink = @import("src/Symlink.zig");
pub const PatchCDB = @import("src/PatchCDB.zig");

pub fn build(_: *std.Build) void {
    // please @import("zmake") directly in your build.zig file
}
