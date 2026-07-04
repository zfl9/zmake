const std = @import("std");

// public API
pub const Pipeline = @import("src/Pipeline.zig");
pub const ZMake = @import("src/ZMake.zig");

pub fn build(_: *std.Build) void {
    // please @import("zmake") directly in your build.zig file
}
