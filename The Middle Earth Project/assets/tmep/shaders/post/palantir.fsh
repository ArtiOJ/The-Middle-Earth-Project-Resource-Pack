#version 330

#extension GL_ARB_separate_shader_objects : require

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform SamplerInfo {
    vec2 OutSize;
    vec2 InSize;
};

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 centered = texCoord - vec2(0.5);

    float aspect = InSize.x / InSize.y;

    vec2 circular = centered;
    circular.x *= aspect;

    float radius = length(circular);

    vec2 direction = vec2(
        circular.x / aspect,
        circular.y
    ) / max(radius, 0.00001);

    // Control this in screen pixels.
    float maxShiftPixels = 50.0;

    // Desired radial chromatic shift, strongest at corners/outer edges.
    float edgeAmount = clamp(radius * radius * 4.0, 0.0, 1.0);
    vec2 desiredOffset = direction * (maxShiftPixels / InSize) * edgeAmount;

    // Distance to the nearest screen edge, in source-texture pixels.
    vec2 edgeDistancePixels = min(texCoord, vec2(1.0) - texCoord) * InSize;

    // Need enough room for BOTH the red (+offset) and blue (-offset) lookups.
    float availablePixels = min(edgeDistancePixels.x, edgeDistancePixels.y);

    // Fade offset down within a small band surrounding the screen border.
    // Must be slightly larger than maxShiftPixels.
    float fadeWidthPixels = maxShiftPixels + 2.0;
    float edgeFade = smoothstep(0.0, fadeWidthPixels, availablePixels);

    vec2 offset = desiredOffset * edgeFade;

    // Tiny clamp only protects against floating-point boundary rounding.
    vec2 halfTexel = 0.5 / InSize;
    vec2 minUV = halfTexel;
    vec2 maxUV = vec2(1.0) - halfTexel;

    vec2 uvR = clamp(texCoord + offset, minUV, maxUV);
    vec2 uvB = clamp(texCoord - offset, minUV, maxUV);

    float red = texture(InSampler, uvR).r;
    float green = texture(InSampler, texCoord).g;
    float blue = texture(InSampler, uvB).b;

    fragColor = vec4(red, green, blue, 1.0);
}