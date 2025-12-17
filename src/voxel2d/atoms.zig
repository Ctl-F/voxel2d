const std = @import("std");
const sdl = @import("sdl.zig");
const core = @import("core.zig");
const simd_options = @import("SIMD_Options");

pub const ElementID = u16; // we could probably get by with just u8
pub const AtomID = u32;
pub const NullAtom: AtomID = @bitCast(@as(i32, -1)); // 0xFFFFFFFF or longer depending on if we change the backing type for AtomID
pub const ValenceCount = u3; // 0-7, so ValenceCount+1 will be the actual total number of valence connections
const MaxBondsPerAtom = 8;

/// Represents the fields of an atom
/// note that these are going to be stored separately
/// and loading the full view of an atom (this struct)
/// should be avoided unless actually necessary.
pub const Atom = struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    element: ElementID,
    valence_bonds: []AtomID,
};

pub const Region = struct {
    xMin: f32,
    yMin: f32,
    xMax: f32,
    yMax: f32,
};

pub const AtomManager = struct {
    const This = @This();
    pub const Handle = u32;

    allocator: std.mem.Allocator,
    sparse_atoms: std.AutoHashMap(Handle, AtomID),
    reverse_sparse_atoms: std.AutoHashMap(AtomID, Handle), // not sure of a better way to do this
    dense_atoms: AtomBuffer,
    head: AtomID,
    next_handle: Handle,
    instances: DrawInstanceBuffer,
    active_instances_buffer: []AtomID,
    active_instances: []AtomID,
    active_region: Region,

    pub fn init(allocator: std.mem.Allocator, count: AtomID) !This {
        const MaxBondCount = count * MaxBondsPerAtom;

        var atom_buffer: AtomBuffer = undefined;

        atom_buffer.velocities_x = try allocator.alloc(f32, count);
        errdefer allocator.free(atom_buffer.velocities_x);

        atom_buffer.velocities_y = try allocator.alloc(f32, count);
        errdefer allocator.free(atom_buffer.velocities_y);

        atom_buffer.positions_x = try allocator.alloc(f32, count);
        errdefer allocator.free(atom_buffer.positions_x);

        atom_buffer.positions_y = try allocator.alloc(f32, count);
        errdefer allocator.free(atom_buffer.positions_y);

        atom_buffer.elements = try allocator.alloc(ElementID, count);
        errdefer allocator.free(atom_buffer.elements);

        atom_buffer.valence_bond_offsets = try allocator.alloc(AtomID, count);
        errdefer allocator.free(atom_buffer.valence_bond_offsets);

        atom_buffer.valence_bond_counts = try allocator.alloc(ValenceCount, count);
        errdefer allocator.free(atom_buffer.valence_bond_counts);

        const BatchSize = count / 4;
        var instances: DrawInstanceBuffer = undefined;

        instances.x = try allocator.alloc(f32, BatchSize);
        errdefer allocator.free(instances.x);

        instances.y = try allocator.alloc(f32, BatchSize);
        errdefer allocator.free(instances.y);

        instances.radius = try allocator.alloc(f32, BatchSize);
        errdefer allocator.free(instances.radius);

        instances.color = try allocator.alloc(f32, BatchSize * DrawInstanceBuffer.ColorChannelCount);
        errdefer allocator.free(instances.color);

        atom_buffer.bonds = try allocator.alloc(AtomID, MaxBondCount);
        errdefer allocator.free(atom_buffer.bonds);
        @memset(atom_buffer.bonds, NullAtom);

        const active_instances = try allocator.alloc(AtomID, count);
        errdefer allocator.free(active_instances);

        for (0..count) |idx| {
            atom_buffer.valence_bond_offsets[idx] = @intCast(idx * MaxBondsPerAtom);
            atom_buffer.valence_bond_counts[idx] = 0; // update this when creating based off of ElementID
        }

        return This{
            .allocator = allocator,
            .dense_atoms = atom_buffer,
            .sparse_atoms = std.AutoHashMap(Handle, AtomID).init(allocator),
            .reverse_sparse_atoms = std.AutoHashMap(AtomID, Handle).init(allocator),
            .head = 0,
            .next_handle = 1,
            .active_instances_buffer = active_instances,
            .active_instances = &.{},
        };
    }

    /// don't use this unless you need to since this will load the whole atom
    /// prefer only loading the fields that you actually need it all
    pub fn load(this: *const This, where: Handle, to: *Atom) !void {
        if (this.sparse_atoms.get(where)) |dense_index| {
            to.position = .{ this.dense_atoms.positions_x[dense_index], this.dense_atoms.positions_y[dense_index] };
            to.velocity = .{ this.dense_atoms.velocities_x[dense_index], this.dense_atoms.velocities_y[dense_index] };
            to.element = this.dense_atoms.elements[dense_index];
            // TODO: load valence bonds
        } else {
            return error.OutOfBounds;
        }
    }

    pub fn set(this: *This, atom: Handle, what: Atom) !void {
        if (this.sparse_atoms.get(atom)) |dense_index| {
            this.dense_atoms.positions_x[dense_index] = what.position[0];
            this.dense_atoms.positions_y[dense_index] = what.position[1];
            this.dense_atoms.velocities_x[dense_index] = what.velocity[0];
            this.dense_atoms.velocities_y[dense_index] = what.velocity[1];
            this.dense_atoms.elements[dense_index] = what.element;
            //TODO: bonds through a different mechanism
        } else {
            return error.NotFound;
        }
    }

    pub fn request(this: *This) !Handle {
        if (this.head >= this.dense_atoms.elements.len) {
            return error.OutOfMemory;
        }
        const newAtomID = this.head;
        const newHandle = this.next_handle;

        this.head += 1;
        this.next_handle += 1;

        try this.sparse_atoms.put(newHandle, newAtomID);
        errdefer _ = this.sparse_atoms.remove(newHandle);

        try this.reverse_sparse_atoms.put(newAtomID, newHandle);
        errdefer _ = this.reverse_sparse_atoms.remove(newAtomID);

        return newHandle;
    }

    pub fn free(this: *This, handle: Handle) void {
        if (this.sparse_atoms.get(handle)) |dense_idx| {
            if (dense_idx == this.head - 1) {
                this.reverse_sparse_atoms.remove(dense_idx);
                this.sparse_atoms.remove(handle);
                this.head -= 1;
                return;
            }

            const end = this.head - 1;
            const endHandle = this.reverse_sparse_atoms.get(end) orelse unreachable; // bug if the item does not exist in reverse_* but does exist in sparse_*

            this.sparse_atoms.remove(handle);
            this.reverse_sparse_atoms.remove(dense_idx);

            this.reverse_sparse_atoms.put(endHandle, dense_idx);

            this.dense_atoms.destory_all_bonds(dense_idx);
            this.dense_atoms.shift(end, dense_idx);
        } else {
            // do nothing,
            return;
        }
    }

    pub fn deinit(this: *This) void {
        this.allocator.free(this.dense_atoms.elements);
        this.allocator.free(this.dense_atoms.positions_x);
        this.allocator.free(this.dense_atoms.positions_y);
        this.allocator.free(this.dense_atoms.velocities_x);
        this.allocator.free(this.dense_atoms.velocities_y);
        this.allocator.free(this.dense_atoms.valence_bond_counts);
        this.allocator.free(this.dense_atoms.valence_bond_offsets);
        this.allocator.free(this.dense_atoms.bonds);

        this.allocator.free(this.instances.x);
        this.allocator.free(this.instances.y);
        this.allocator.free(this.instances.radius);
        this.allocator.free(this.instances.color);

        this.reverse_sparse_atoms.deinit();
        this.sparse_atoms.deinit();
    }

    inline fn in_range(v: f32, min: f32, max: f32) bool {
        return min <= v and v <= max;
    }

    fn bitmask(comptime N: usize, mask: @Vector(N, bool)) u32 {
        var value: u32 = 0;

        inline for (0..N) |i| {
            if (mask[i]) {
                value |= @as(u32, 1) << @as(u5, @intCast(i));
            }
        }

        return mask;
    }

    inline fn push_active_instance(this: *This, atom: AtomID) void {
        this.active_instances_buffer[this.active_instances.len] = atom;
        this.active_instances = this.active_instances_buffer[0 .. this.active_instances.len + 1];
    }

    pub inline fn physics_step(this: *This, dt: f32) void {
        return _physics_step(simd_options.SIMD_LANES, this, dt);
    }

    fn _physics_step(comptime SIMD_LANES: usize, this: *This, dt: f32) void {
        const atom_count: usize = this.head;
        const straglers = atom_count % SIMD_LANES;

        this.active_instances = &.{};

        for (0..straglers) |idx| {
            const xx = this.dense_atoms.positions_x[idx];
            const yy = this.dense_atoms.positions_y[idx];

            if (!in_range(xx, this.active_region.xMin, this.active_region.xMax) or !in_range(yy, this.active_region.yMin, this.active_region.yMax)) {
                continue;
            }

            this.dense_atoms.positions_x[idx] = xx + this.dense_atoms.velocities_x[idx] * dt;
            this.dense_atoms.positions_y[idx] = yy + this.dense_atoms.velocities_y[idx] * dt;

            this.push_active_instance(idx);
        }

        const dts: @Vector(SIMD_LANES, f32) = @splat(dt);

        const min_x: @Vector(SIMD_LANES, f32) = @splat(this.active_region.xMin);
        const max_x: @Vector(SIMD_LANES, f32) = @splat(this.active_region.xMax);
        const min_y: @Vector(SIMD_LANES, f32) = @splat(this.active_region.yMin);
        const max_y: @Vector(SIMD_LANES, f32) = @splat(this.active_region.yMax);

        var cursor: usize = straglers;
        while (cursor < atom_count) : (cursor += SIMD_LANES) {
            const positions_x: @Vector(SIMD_LANES, f32) = this.dense_atoms.positions_x[cursor..][0..SIMD_LANES].*;
            const positions_y: @Vector(SIMD_LANES, f32) = this.dense_atoms.positions_y[cursor..][0..SIMD_LANES].*;

            const mask_x: @Vector(SIMD_LANES, bool) = (positions_x >= min_x) and (positions_x <= max_x);
            const mask_y: @Vector(SIMD_LANES, bool) = (positions_y >= min_y) and (positions_y <= max_y);
            const mask = mask_x and mask_y;

            const velocities_x: @Vector(SIMD_LANES, f32) = this.dense_atoms.velocities_x[cursor..][0..SIMD_LANES].*;
            const velocities_y: @Vector(SIMD_LANES, f32) = this.dense_atoms.velocities_y[cursor..][0..SIMD_LANES].*;

            const new_x = positions_x + velocities_x * dts;
            const new_y = positions_y + velocities_y * dts;

            this.dense_atoms.positions_x[cursor..][0..SIMD_LANES].* = @select(f32, mask, new_x, positions_x);
            this.dense_atoms.positions_y[cursor..][0..SIMD_LANES].* = @select(f32, mask, new_y, positions_y);

            inline for (0..SIMD_LANES) |lane| {
                if (mask[lane]) {
                    this.push_active_instance(cursor + lane);
                }
            }
        }

        // TODO: Collisions, Gravity and bonding
        // TODO: Spatial tracking
    }

    const AtomBuffer = struct {
        const ABT = @This();

        positions_x: []f32,
        positions_y: []f32,
        velocities_x: []f32,
        velocities_y: []f32,
        elements: []ElementID,
        valence_bond_offsets: []AtomID,
        valence_bond_counts: []ValenceCount,
        // not a per atom buffer
        bonds: []AtomID,

        inline fn shift(this: *ABT, from: AtomID, to: AtomID) void {
            this.relocate_bonds(from, to);

            this.positions_x[to] = this.positions_x[from];
            this.positions_y[to] = this.positions_y[from];
            this.velocities_x[to] = this.velocities_x[from];
            this.velocities_y[to] = this.velocities_y[from];
            this.elements[to] = this.elements[from];
            this.valence_bond_offsets[to] = this.valence_bond_offsets[from];
            this.valence_bond_counts[to] = this.valence_bond_counts[from];
        }

        /// if a bond can be formed between these two atoms it will form it
        /// and return true
        /// if false is returned, the bond cannot be formed and was not formed
        /// this assumes that proximity checks have already been performed
        inline fn bond_between(this: *ABT, a: AtomID, b: AtomID) bool {
            const a_bond = this.find_free_valence(a) orelse return false;
            const b_bond = this.find_free_valence(b) orelse return false;

            this.bonds[a_bond] = b;
            this.bonds[b_bond] = a;
            return true;
        }

        fn relocate_bonds(this: *ABT, old: AtomID, new: AtomID) void {
            const start: usize = @intCast(this.valence_bond_offsets[old]);
            const count: usize = @intCast(this.valence_bond_counts[old]);

            for (this.bonds[start..(start + count)]) |bonded| {
                const back_ref = this.find_valence_bond(bonded, old) orelse unreachable;
                this.bonds[back_ref] = new;
            }
        }

        inline fn destory_all_bonds(this: *ABT, atom: AtomID) void {
            const start: usize = @intCast(this.valence_bond_offsets[atom]);
            const count: usize = @intCast(this.valence_bond_counts[atom]);

            for (this.bonds[start..(start + count)], 0..) |bond, idx| {
                if (bond == NullAtom) continue;

                const bond_to_me = this.find_valence_bond(bond, atom) orelse unreachable; // a bug if A points to B but B does not point back to A

                this.bonds[start + idx] = NullAtom;
                this.bonds[bond_to_me] = NullAtom;
            }
        }

        inline fn destroy_bond(this: *ABT, a: AtomID, b: AtomID) void {
            const a_to_b = this.find_valence_bond(a, b) orelse return;
            const b_to_a = this.find_valence_bond(b, a) orelse unreachable; // it's a bug if A points to B but B does not point to A

            this.bonds[a_to_b] = NullAtom;
            this.bonds[b_to_a] = NullAtom;
        }

        inline fn find_valence_bond(this: *ABT, atom: AtomID, bonded: AtomID) ?AtomID {
            const start: usize = @intCast(this.valence_bond_offsets[atom]);
            const count: usize = @intCast(this.valence_bond_counts[atom]);

            return for (this.bonds[start..(start + count)], 0..) |valence, idx| {
                if (valence == bonded) {
                    break @intCast(start + idx);
                }
            } else null;
        }

        inline fn find_free_valence(this: *ABT, atom: AtomID) ?AtomID {
            const start: usize = @intCast(this.valence_bond_offsets[atom]);
            const count: usize = @intCast(this.valence_bond_counts[atom]);

            return for (this.bonds[start..(start + count)], 0..) |valence, idx| {
                if (valence == NullAtom) {
                    break @intCast(start + idx);
                }
            } else null;
        }
    };
};

pub const AtomRenderer = struct {
    const This = @This();

    universe: *AtomManager,
    context: OpenGLContext,

    pub fn init(universe: *AtomManager) This {
        const gl = sdl.gl;
        var ctx: OpenGLContext = undefined;

        gl.glGenVertexArrays(1, &ctx.vao);
        gl.glBindVertexArray(ctx.vao);

        gl.glGenBuffers(ctx.buffers.len, &ctx.buffers[0]);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, ctx.buffers[OpenGLContext.VBO]);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ctx.buffers[OpenGLContext.IBO]);

        const QUAD_VERTS = [_]f32{
            //x,   y,    z,    u,   v
            -0.5, -0.5, 0.0, 0.0, 0.0,
            0.5,  -0.5, 0.0, 1.0, 0.0,
            -0.5, 0.5,  0.0, 0.0, 1.0,
            0.5,  0.5,  0.0, 1.0, 1.0,
        };
        const QUAD_IDXS = [_]u32{ 0, 1, 2, 1, 2, 3 };

        gl.glBufferData(gl.GL_ARRAY_BUFFER, QUAD_VERTS.len * @sizeOf(f32), &QUAD_VERTS[0], gl.GL_STATIC_DRAW);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, QUAD_IDXS.len * @sizeOf(u32), &QUAD_IDXS[0], gl.GL_STATIC_DRAW);

        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(0));
        gl.glEnableVertexAttribArray(0);

        gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
        gl.glEnableVertexAttribArray(1);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, ctx.buffers[OpenGLContext.OBX]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, 0, null, gl.GL_DYNAMIC_DRAW);
        gl.glVertexAttribPointer(2, 1, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32), @ptrFromInt(0));
        gl.glVertexAttribDivisor(2, 1);
        gl.glEnableVertexAttribArray(2);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, ctx.buffers[OpenGLContext.OBY]);
        gl.glVertexAttribPointer(3, 1, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32), @ptrFromInt(0));
        gl.glVertexAttribDivisor(3, 1);
        gl.glEnableVertexAttribArray(3);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, ctx.buffers[OpenGLContext.OBRadius]);
        gl.glVertexAttribPointer(4, 1, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32), @ptrFromInt(0));
        gl.glVertexAttribDivisor(4, 1);
        gl.glEnableVertexAttribArray(4);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, ctx.buffers[OpenGLContext.OBColor]);
        gl.glVertexAttribPointer(5, 3, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(f32) * 3, @ptrFromInt(0));
        gl.glVertexAttribDivisor(5, 1);
        gl.glEnableVertexAttribArray(5);

        gl.glBindVertexArray(0);

        return .{
            .universe = universe,
            .context = ctx,
        };
    }

    pub fn render_step(this: *This, instances: DrawInstanceBuffer) void {
        const gl = sdl.gl;

        gl.glBindVertexArray(this.context.vao);

        //TODO: look into a ring-buffer/double-buffer for these buffers
        //TODO: look into gl.glMapBufferRange over gl.glBufferSubData

        // orphan approach for possible optimization
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, this.context.buffers[OpenGLContext.OBX]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(instances.len * @sizeOf(f32)), null, gl.GL_DYNAMIC_DRAW);
        gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, @intCast(instances.len * @sizeOf(f32)), instances.x.ptr);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, this.context.buffers[OpenGLContext.OBY]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(instances.len * @sizeOf(f32)), null, gl.GL_DYNAMIC_DRAW);
        gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, @intCast(instances.len * @sizeOf(f32)), instances.y.ptr);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, this.context.buffers[OpenGLContext.OBRadius]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(instances.len * @sizeOf(f32)), null, gl.GL_DYNAMIC_DRAW);
        gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, @intCast(instances.len * @sizeOf(f32)), instances.radius.ptr);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, this.context.buffers[OpenGLContext.OBColor]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(instances.len * @sizeOf(f32) * 3), null, gl.GL_DYNAMIC_DRAW);
        gl.glBufferSubdata(gl.GL_ARRAY_BUFFER, 0, @intCast(instances.len * @sizeOf(f32) * 3), instances.color.ptr);

        gl.glDrawElementsInstanced(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, null, @intCast(instances.len));
    }

    const OpenGLContext = struct {
        const VBO: usize = 0;
        const IBO: usize = 1;

        /// per instance buffers
        const OBX: usize = 2;
        const OBY: usize = 3;
        const OBRadius: usize = 4;
        const OBColor: usize = 5;
        const BufferCount = 6;

        vao: u32,
        buffers: [BufferCount]u32,
        programID: u32,
    };
};

pub const DrawInstanceBuffer = struct {
    const ColorChannelCount = 3;

    x: []f32,
    y: []f32,
    radius: []f32,
    color: []f32,
};
