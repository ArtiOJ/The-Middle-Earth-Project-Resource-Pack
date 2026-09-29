#version 330

#extension GL_ARB_separate_shader_objects : require

layout(location = 0) out vec2 texCoord;

void main() {
    vec2 uv = vec2(
        (gl_VertexIndex << 1) & 2,
        gl_VertexIndex & 2
    );

    vec4 pos = vec4(
        uv * vec2(2.0, 2.0) + vec2(-1.0, -1.0),
        0.0,
        1.0
    );

    gl_Position = pos;
    texCoord = uv;
}