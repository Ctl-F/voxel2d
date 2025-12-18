const std = @import("std");
const v2d = @import("voxel2d");

pub fn main() !void {
    defer std.debug.assert(v2d.core.GeneralPurposeAllocatorType.deinit() != .leak);
    defer v2d.assets.release_assets();

    const window = try v2d.sdl.createWindow(.{
        .width = 1280,
        .height = 720,
        .title = null,
        .backend = .OpenGL,
    });
    defer v2d.sdl.deinit();
    defer v2d.sdl.destroyWindow(window);

    const AtomCount = 10000;

    var universe = try v2d.atom.AtomManager.init(v2d.core.BaseAllocator, AtomCount);
    defer universe.deinit();

    // const adamAtom = try universe.request();
    // try universe.set(adamAtom, .{
    //     .position = .{ 100, 100 },
    //     .velocity = .{ 10, 10 },
    //     .element = 0,
    //     .valence_bonds = &.{},
    // });

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = rng.random();

    for (0..AtomCount) |_| {
        const atom = try universe.request();
        const atom_val: v2d.atom.Atom = .{
            .position = .{
                rand.float(f32) * 1280,
                rand.float(f32) * 720,
            },
            .velocity = .{
                rand.float(f32) * 30 * (0.5 - rand.float(f32)),
                rand.float(f32) * 30 * (0.5 - rand.float(f32)),
            },
            .element = 0,
            .valence_bonds = &.{},
        };

        try universe.set(atom, atom_val);
    }

    var frameTimer = v2d.core.Timer.init();
    var printTimer = v2d.core.Timer.init();
    const printUpdate: f32 = 0.15; // seconds
    var avgFps: f32 = 0;

    var minFps: f32 = std.math.floatMax(f32);
    var maxFps: f32 = std.math.floatMin(f32);

    var skip: u32 = 0;
    const skipTarget: u32 = 5;

    MAIN: while (true) {
        while (v2d.sdl.getEvent()) |event| {
            if (event == .quit) {
                break :MAIN;
            }
        }
        const delta = frameTimer.delta(f32);
        const fps = 1.0 / @max(delta, 1e-6);
        if (skip < skipTarget) {
            skip += 1;
            avgFps += fps;

            if (skip == skipTarget) {
                avgFps /= @floatFromInt(skipTarget);
            }
        } else {
            avgFps = 0.5 * (avgFps + fps);
            minFps = @min(minFps, fps);
            maxFps = @max(maxFps, fps);

            if (printTimer.elapsed(f32) >= printUpdate) {
                printTimer.reset();
                std.debug.print("\r[Min, Avg, Max] FPS: [{}, {}, {}]", .{ minFps, avgFps, maxFps }); // don't allow for zero
            }
        }

        universe.physics_step(delta);

        v2d.sdl.setColor(window, v2d.Color.Clear);
        v2d.sdl.clear(window);

        universe.render();

        v2d.sdl.refresh(window);
    }
    std.debug.print("\n", .{});
}
