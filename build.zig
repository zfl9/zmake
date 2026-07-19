const std = @import("std");

// used in "src/ZMake.zig"
pub const zcdb = @import("zcdb");

// public API
pub const ZMake = @import("src/ZMake.zig");
pub const Pipeline = @import("src/Pipeline.zig");
pub const Symlink = @import("src/Symlink.zig");

pub fn build(_: *std.Build) void {
    // please @import("zmake") directly in your build.zig file
}
