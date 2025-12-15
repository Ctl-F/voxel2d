const sdl = @import("sdl.zig");
const std = @import("std");
const core = @import("core.zig");

var shader_cache: ?std.AutoHashMap(ShaderID, u32);

pub const ShaderID = enum(u32) {
    Circle = 0,
};

const ShaderSources = [_]struct { vsrc: [:0]const u8, fsrc: [:0]const u8 }{.{
    .vsrc = @embedFile("include/circle.vtx.glsl"),
    .fsrc = @embedFile("include/circle.frg.glsl"),
}};

pub fn request_shader(id: ShaderID) !u32 {
    if (shader_cache == null) {
        shader_cache = std.AutoHashMap(ShaderID, u32).init(core.BaseAllocator);
    }

    if (shader_cache.?.get(id)) |pid| {
        return pid;
    }

    const spid = try compile_shader(id);
    try shader_cache.?.put(id, spid);
    return spid;
}

fn compile_shader(id: ShaderID) !u32 {
    const gl = sdl.gl;

    const sources = ShaderSources[@intFromEnum(id)];

    const vert = try compile_gl_shader(gl.GL_VERTEX_SHADER, sources.vsrc);
    defer gl.glDeleteShader(vert);

    const frag = try compile_gl_shader(gl.GL_FRAGMENT_SHADER, sources.fsrc);
    defer gl.glDeleteShader(frag);

    const prog = try link_gl_shader(vert, frag);
    return prog;
}

fn link_gl_shader(vert: u32, frag: u32) !u32 {
    const gl = sdl.gl;
    const prog = gl.glCreateProgram();
    errdefer gl.glDeleteProgram(prog);

    gl.glAttachShader(prog, vert);
    defer gl.glDetachShader(prog, vert);

    gl.glAttachShader(prog, frag);
    defer gl.glDetachShader(prog, frag);

    gl.glLinkProgram(prog);

    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;

    gl.glGetProgramiv(prog, gl.GL_LINK_STATUS, &success);
    if (success == gl.GL_FALSE) {
        gl.glGetProgramInfoLog(prog, infoLog.len, null, &infoLog[0]);
        std.debug.print("Shader Linker Error: {s}\n", .{infoLog});
        return error.ShaderLinkError;
    }

    return prog;
}

fn compile_gl_shader(kind: c_int, source: [:0]const u8) !u32 {
    const gl = sdl.gl;
    const shader = gl.glCreateShader(kind);
    errdefer gl.glDeleteShader(shader);

    gl.glShaderSource(shader, 1, source.ptr, null);
    gl.glCompileShader(shader);

    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, &success);
    if (success == gl.GL_FALSE) {
        gl.glGetShaderInfoLog(shader, infoLog.len, null, &infoLog[0]);
        std.debug.print("Shader Error: {s}\n", .{infoLog});
        return error.ShaderCompileError;
    }

    return shader;
}
