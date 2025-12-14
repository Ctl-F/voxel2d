const std = @import("std");
const sdl = @cImport(@cInclude("SDL3/SDL.h"));
const glad = @cImport(@cInclude("glad/glad.h"));

pub const gl = glad;

//[====================SECTION SDL-CORE]====================]

pub const SDLInitError = error{
    Unknown,
    SDLInit,
    OpenGLInit,
    CreateContext,
};

//[!====================SECTION SDL-CORE]====================]
//[====================SECTION WINDOW====================]

pub const VideoWindow = struct {
    window: ?*sdl.SDL_Window,
    renderer: ?*sdl.SDL_Renderer,
    context: sdl.SDL_GLContext = null, // already a nullable pointer type
};

pub const PresentBackend = enum {
    SdlRenderer,
    OpenGL,
};

pub const WindowParams = struct {
    width: c_int,
    height: c_int,
    title: ?[*c]const u8,
    backend: PresentBackend,
};

pub const WindowCreateError = error{
    WindowCreate,
    WindowInvalidArea,
};

pub fn createWindow(params: WindowParams) (SDLInitError || WindowCreateError)!VideoWindow {
    if (sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO) & sdl.SDL_INIT_VIDEO != sdl.SDL_INIT_VIDEO) {
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            return error.SDLInit;
        }
        errdefer sdl.SDL_Quit();
    }

    if (params.width <= 0 or params.height <= 0) {
        return error.WindowInvalidArea;
    }

    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);

    var window: VideoWindow = switch (params.backend) {
        .OpenGL => .{
            .window = sdl.SDL_CreateWindow(params.title orelse "voxel-window", params.width, params.height, sdl.SDL_WINDOW_OPENGL),
            .renderer = null,
        },
        .SdlRenderer => REND: {
            var win: VideoWindow = undefined;
            if (!sdl.SDL_CreateWindowAndRenderer(params.title orelse "voxel-window", params.width, params.height, 0, &win.window, &win.renderer)) {
                return error.WindowCreate;
            }
            win.context = null;
            break :REND win;
        },
    };

    if (window.window == null) {
        return error.WindowCreate;
    }
    errdefer sdl.SDL_DestroyWindow(window.window);

    if (params.backend == .OpenGL) {
        window.context = sdl.SDL_GL_CreateContext(window.window);

        if (window.context == null) {
            return error.CreateContext;
        }
        errdefer _ = sdl.SDL_GL_DestroyContext(window.context);

        _ = sdl.SDL_GL_MakeCurrent(window.window, window.context);
        _ = sdl.SDL_GL_SetSwapInterval(0);

        if (glad.gladLoadGLLoader(@ptrCast(@alignCast(&sdl.SDL_GL_GetProcAddress))) == 0) {
            return error.OpenGLInit;
        }

        glad.glViewport(0, 0, params.width, params.height);
        glad.glEnable(glad.GL_DEPTH);
    }

    return window;
}

pub fn deinit() void {
    sdl.SDL_Quit();
}

pub fn destroyWindow(window: VideoWindow) void {
    if (window.renderer != null) {
        sdl.SDL_DestroyRenderer(window.renderer);
    }
    if (window.context != null) {
        _ = sdl.SDL_GL_DestroyContext(window.context);
    }
    sdl.SDL_DestroyWindow(window.window);
}

//[!====================SECTION WINDOW====================]

//[====================SECTION RENDERING]====================]

pub const Color = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn fromVec(v: @Vector(4, u8)) @This() {
        return .{
            .r = v[0],
            .g = v[1],
            .b = v[2],
            .a = v[3],
        };
    }

    pub fn toColorHDR(this: @This()) ColorHDR {
        return .{
            .r = @as(f32, @floatFromInt(this.r)) / 255.0,
            .g = @as(f32, @floatFromInt(this.g)) / 255.0,
            .b = @as(f32, @floatFromInt(this.b)) / 255.0,
            .a = @as(f32, @floatFromInt(this.a)) / 255.0,
        };
    }

    pub const Clear = @This(){ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const White = @This(){ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const Black = @This(){ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const Red = @This(){ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const Green = @This(){ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const Blue = @This(){ .r = 0, .g = 0, .b = 255, .a = 255 };
    pub const Yellow = @This(){ .r = 255, .g = 255, .b = 0, .a = 255 };
    pub const Magenta = @This(){ .r = 255, .g = 0, .b = 255, .a = 255 };
    pub const Cyan = @This(){ .r = 0, .g = 255, .b = 255, .a = 255 };
    pub const Grey = @This(){ .r = 128, .g = 128, .b = 128, .a = 255 };
};

pub const ColorHDR = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn toColor(this: @This()) Color {
        return .{
            .r = @as(u8, @intFromFloat(255.0 * @min(@max(this.r, 0.0), 1.0))),
            .g = @as(u8, @intFromFloat(255.0 * @min(@max(this.g, 0.0), 1.0))),
            .b = @as(u8, @intFromFloat(255.0 * @min(@max(this.b, 0.0), 1.0))),
            .a = @as(u8, @intFromFloat(255.0 * @min(@max(this.a, 0.0), 1.0))),
        };
    }

    pub const Clear = @This(){ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const White = @This(){ .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const Black = @This(){ .r = 0, .g = 0, .b = 0, .a = 1 };
    pub const Red = @This(){ .r = 1, .g = 0, .b = 0, .a = 1 };
    pub const Green = @This(){ .r = 0, .g = 1, .b = 0, .a = 1 };
    pub const Blue = @This(){ .r = 0, .g = 0, .b = 1, .a = 1 };
    pub const Yellow = @This(){ .r = 1, .g = 1, .b = 0, .a = 1 };
    pub const Magenta = @This(){ .r = 1, .g = 0, .b = 1, .a = 1 };
    pub const Cyan = @This(){ .r = 0, .g = 1, .b = 1, .a = 1 };
    pub const Grey = @This(){ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1 };
};

pub fn refresh(window: VideoWindow) void {
    std.debug.assert(window.window != null);

    if (window.context != null) {
        _ = sdl.SDL_GL_SwapWindow(window.window);
    } else if (window.renderer != null) {
        _ = sdl.SDL_RenderPresent(window.renderer);
    } else {
        unreachable;
    }
}

pub fn setColor(handle: VideoWindow, color: Color) void {
    if (handle.context != null) {
        const fColor = color.toColorHDR();
        glad.glClearColor(fColor.r, fColor.g, fColor.b, fColor.a);
    } else if (handle.renderer != null) {
        _ = sdl.SDL_SetRenderDrawColor(handle.renderer, color.r, color.g, color.b, color.a);
    } else {
        unreachable;
    }
}

pub fn clear(window: VideoWindow) void {
    if (window.context != null) {
        glad.glClear(glad.GL_COLOR_BUFFER_BIT | glad.GL_DEPTH_BUFFER_BIT);
    } else if (window.renderer != null) {
        _ = sdl.SDL_RenderClear(window.renderer);
    } else unreachable;
}

pub fn setViewport(handle: VideoWindow, x: u32, y: u32, width: u32, height: u32) void {
    std.debug.assert(handle.renderer != null);

    const rect = sdl.SDL_Rect{
        .x = @intCast(x),
        .y = @intCast(y),
        .w = @intCast(width),
        .h = @intCast(height),
    };

    _ = sdl.SDL_SetRenderViewport(handle.renderer, &rect);
}

pub const Vertex = sdl.SDL_Vertex;
pub const Point = sdl.SDL_FPoint;

pub inline fn unwrap_point(p: Point) struct { f32, f32 } {
    return .{ p.x, p.y };
}

pub const Surface = [*c]sdl.SDL_Surface;
pub const Texture = [*c]sdl.SDL_Texture;
pub const TextureAccess = enum(c_int) {
    Static = sdl.SDL_TEXTUREACCESS_STATIC,
    Streaming = sdl.SDL_TEXTUREACCESS_STREAMING,
    Target = sdl.SDL_TEXTUREACCESS_TARGET,
};

pub const AssetError = error{
    CreateAllocError,
};

pub inline fn renderPolygon(handle: VideoWindow, texture: ?Texture, vertices: []Vertex, indices: ?[]u32) void {
    std.debug.assert(handle.renderer != null);

    const index_count: u32 = if (indices) |idx| @intCast(idx.len) else 0;
    const index_ptr: [*c]i32 = if (indices) |idx| @ptrCast(idx.ptr) else null;

    _ = sdl.SDL_RenderGeometry(
        handle.renderer,
        if (texture) |tx| tx else null,
        vertices.ptr,
        @intCast(vertices.len),
        index_ptr,
        index_count,
    );
}

pub inline fn renderCircle(handle: VideoWindow, x: f32, y: f32, radius: f32) void {
    const STEPS = 16;
    const UNIT_CIRCLE = comptime COMPUTE: {
        var angle: comptime_float = 0;
        const step = (std.math.pi * 2) / @as(comptime_float, @floatFromInt(STEPS - 1)); // we want the final iteration and the first iteration to be the same point

        var points: [STEPS]Point = undefined;
        var cursor: usize = 0;

        while (cursor < points.len) : ({
            angle += step;
            cursor += 1;
        }) {
            points[cursor] = .{
                .x = @cos(angle),
                .y = -@sin(angle),
            };
        }

        break :COMPUTE points;
    };
    var translated_points: [STEPS]Point = undefined;

    const src_view: [*]const f32 = @ptrCast(@alignCast(&UNIT_CIRCLE[0]));
    const dest_view: [*]f32 = @ptrCast(@alignCast(&translated_points[0]));

    const translation: @Vector(2, f32) = .{ x, y };
    const scale: @Vector(2, f32) = @splat(radius);

    for (0..STEPS) |idx| {
        dest_view[(idx * 2)..][0..2].* = (@as(@Vector(2, f32), src_view[(idx * 2)..][0..2].*) * scale) + translation;
    }

    _ = sdl.SDL_RenderLines(handle.renderer, &translated_points[0], @intCast(translated_points.len));
}

pub inline fn renderLineLoop(handle: VideoWindow, points: []const Point, closed: bool) void {
    std.debug.assert(handle.renderer != null);

    if (points.len < 2) {
        return;
    }

    _ = sdl.SDL_RenderLines(handle.renderer, points.ptr, @intCast(points.len));

    if (closed) {
        const x1, const y1 = unwrap_point(points[points.len - 1]);
        const x2, const y2 = unwrap_point(points[0]);
        _ = sdl.SDL_RenderLine(handle.renderer, x1, y1, x2, y2);
    }
}

pub inline fn renderLine(handle: VideoWindow, start: Point, end: Point) void {
    std.debug.assert(handle.renderer != null);
    _ = sdl.SDL_RenderLine(handle.renderer, start.x, start.y, end.x, end.y);
}

pub inline fn renderPoint(handle: VideoWindow, point: Point) void {
    std.debug.assert(handle.renderer != null);
    _ = sdl.SDL_RenderPoint(handle.renderer, point.x, point.y);
}

/// render a list of lines. If points is an odd number the last point will be ignored
pub inline fn renderLines(handle: VideoWindow, points: []const Point) void {
    var idx: usize = 1;
    while (idx < points.len) : (idx += 2) {
        renderLine(handle, points[idx - 1], points[idx]);
    }
}

pub inline fn createSurface(width: usize, height: usize) AssetError!Surface {
    const surface = sdl.SDL_CreateSurface(@intCast(width), @intCast(height), sdl.SDL_PIXELFORMAT_RGBA32);
    if (surface == null) {
        return AssetError.CreateAllocError;
    }
    return surface;
}

pub inline fn destroySurface(surface: Surface) void {
    sdl.SDL_DestroySurface(surface);
}

pub inline fn createTexture(handle: VideoWindow, kind: TextureAccess, width: usize, height: usize) AssetError!Texture {
    std.debug.assert(handle.renderer != null);
    const texture = sdl.SDL_CreateTexture(handle.renderer, sdl.SDL_PIXELFORMAT_RGBA32, @intFromEnum(kind), @intCast(width), @intCast(height));
    if (texture == null) {
        return AssetError.CreateAllocError;
    }
    return texture;
}

pub inline fn createTextureFromSurface(handle: VideoWindow, surface: Surface) AssetError!Texture {
    std.debug.assert(handle.renderer != null);

    const texture = sdl.SDL_CreateTextureFromSurface(handle.renderer, surface);
    if (texture == null) {
        return AssetError.CreateAllocError;
    }
    return texture;
}

pub inline fn destroyTexture(texture: Texture) void {
    sdl.SDL_DestroyTexture(texture);
}

pub inline fn renderSetTarget(handle: VideoWindow, target: ?Texture) void {
    std.debug.assert(handle.renderer != null);

    if (target) |t| {
        _ = sdl.SDL_SetRenderTarget(handle.renderer, t);
    } else {
        _ = sdl.SDL_SetRenderTarget(handle.renderer, null);
    }
}

//[!====================SECTION RENDERING]====================]
//[====================SECTION EVENTS]====================]

pub fn getEvent() ?Event {
    var event: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&event)) {
        return Event.fromSdlEvent(event);
    }
    return null;
}

pub const Event = union(enum) {
    quit,
    key: Keyboard,
    mouse: Mouse,
    wheel: Wheel,
    button: GamePadButton,
    axis: GamePadAxis,
    unknown,

    pub const Action = enum { Press, Release };
    pub const MouseButton = enum { Left, Right, Middle, Ext0, Ext1 };
    pub const Key = @import("key_map.zig");

    pub const Keyboard = struct {
        timestamp: u64,
        action: Action,
        key: Key.Type,
    };

    pub const Mouse = struct {
        timestamp: u64,
        action: Action,
        button: MouseButton,
        x: f32,
        y: f32,
    };

    pub const Wheel = struct {
        timestamp: u64,
        amount: i32,
    };

    pub const GamePadButton = struct {
        timestamp: u64,
    };

    pub const GamePadAxis = struct {
        timestamp: u64,
    };

    fn fromSdlEvent(event: sdl.SDL_Event) @This() {
        return switch (event.type) {
            sdl.SDL_EVENT_QUIT => .quit,
            sdl.SDL_EVENT_KEY_DOWN => makeKeyEvent(.Press, event),
            sdl.SDL_EVENT_KEY_UP => makeKeyEvent(.Release, event),
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => makeMouseEvent(.Press, event),
            sdl.SDL_EVENT_MOUSE_BUTTON_UP => makeMouseEvent(.Release, event),
            sdl.SDL_EVENT_MOUSE_WHEEL => .{
                .wheel = .{
                    .timestamp = event.wheel.timestamp,
                    .amount = event.wheel.integer_y,
                },
            },
            else => .unknown,
        };
    }

    inline fn makeKeyEvent(action: Action, event: sdl.SDL_Event) @This() {
        return .{
            .key = .{
                .action = action,
                .key = @intCast(event.key.scancode),
                .timestamp = event.key.timestamp,
            },
        };
    }

    inline fn makeMouseEvent(action: Action, event: sdl.SDL_Event) @This() {
        return .{
            .mouse = .{
                .timestamp = event.button.timestamp,
                .action = action,
                .button = mapButton(event.button.button),
                .x = event.button.x,
                .y = event.button.y,
            },
        };
    }

    fn mapButton(button: u8) MouseButton {
        return switch (button) {
            sdl.SDL_BUTTON_LEFT => .Left,
            sdl.SDL_BUTTON_RIGHT => .Right,
            sdl.SDL_BUTTON_MIDDLE => .Middle,
            4 => .Ext0,
            5 => .Ext1,
            else => .Ext1,
        };
    }
};

//[====================SECTION EVENTS]====================]
//[====================SECTION UTIL]====================]
pub inline fn getTicksNS() u64 {
    return sdl.SDL_GetTicksNS();
}
//[====================SECTION UTIL]====================]
//[====================SECTION XXXXXXXX]====================]

//[====================SECTION XXXXXXXX]====================]
