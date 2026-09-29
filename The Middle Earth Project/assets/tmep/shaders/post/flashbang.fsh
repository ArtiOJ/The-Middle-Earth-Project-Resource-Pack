#version 330

#extension GL_ARB_separate_shader_objects : require

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D InSampler;

void main() {
    vec4 screen = texture(InSampler, texCoord);

    fragColor = vec4(
        1.0,
        1.0,
        1.0,
        screen.a
    );
}