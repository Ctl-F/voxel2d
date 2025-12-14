const sdl = @import("sdl.zig");
const std = @import("std");

pub var GeneralPurposeAllocatorType = std.heap.GeneralPurposeAllocator(.{}).init;
pub const BaseAllocator = GeneralPurposeAllocatorType.allocator();

pub const Timer = struct {
    const This = @This();

    timestamp: u64,

    pub fn init() This {
        return .{
            .timestamp = sdl.getTicksNS(),
        };
    }

    pub inline fn reset(this: *This) void {
        this.timestamp = sdl.getTicksNS();
    }

    inline fn convert(deltaTime: u64, comptime _Ty: type) _Ty {
        const info = @typeInfo(_Ty);
        const Units = enum { Int, Float };

        const unit = switch (info) {
            .float, .comptime_float => Units.Float,
            .int, .comptime_int => Units.Int,
            else => @compileError("Invalid delta-time type"),
        };
        if (comptime unit == .Int) {
            return @as(_Ty, @intCast(round_to_nearest_ms(deltaTime)));
        } else {
            return @as(_Ty, @floatFromInt(deltaTime)) / @as(_Ty, 1_000_000_000.0);
        }
    }

    /// returns elapsed time but does not reset timer
    /// if type is a uint, result will be milliseconds
    /// if type is a float, result will be in seconds (as fraction of seconds)
    pub fn elapsed(this: *const This, comptime _Ty: type) _Ty {
        const now = sdl.getTicksNS();
        const deltaTime = now - this.timestamp;
        return convert(deltaTime, _Ty);
    }

    /// returns elapsed time resetting the timer
    /// if type is a uint, result will be milliseconds
    /// if type is a float, result will be in seconds (as fraction of seconds)
    pub inline fn delta(this: *This, comptime _Ty: type) _Ty {
        const now = sdl.getTicksNS();
        const deltaTime = now - this.timestamp;
        this.timestamp = now;
        return convert(deltaTime, _Ty);
    }

    /// v is nanoseconds
    inline fn round_to_nearest_ms(v: u64) u64 {
        const ns_to_ms_factor: u64 = 1_000_000;
        return (v + (ns_to_ms_factor / 2)) / ns_to_ms_factor;
    }
};
