//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
pub const core = @import("voxel2d/core.zig");
pub const sdl = @import("voxel2d/sdl.zig");
pub const atom = @import("voxel2d/atoms.zig");
pub const Color = sdl.Color;
pub const assets = @import("voxel2d/asset.zig");
