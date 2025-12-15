#version 330
layout(location = 0) in vec2 vert_pos;
layout(location = 1) in vec2 vert_uv;
layout(location = 2) in float inst_x;
layout(location = 3) in float inst_y;
layout(location = 4) in float inst_rad;
layout(location = 5) in vec3 inst_color;

void main() {
    mat4 model = mat4(
            int_x * inst_rad, inst_y, 0, 0,
            0, inst_rad, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        );
}
