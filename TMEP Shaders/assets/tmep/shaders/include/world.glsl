#ifndef TMEP_WORLD_GLSL
#define TMEP_WORLD_GLSL

#include <minecraft:globals.glsl>
#include <tmep:camera_data.glsl>

struct Camera {
    mat4 view;
    mat4 projection;
    mat4 inverseView;
    mat4 inverseProjection;
    float daytime;
    float fogStart;
    float fogEnd;
    vec3 fogColor;
    bool underwater;
    float weather;
    bool skyValid;
    bool firstPerson;
    bool valid;
};

ivec2 cameraScreenSize = ivec2(1);

float camera_slot(sampler2D scene, int slot) {
    return camera_data_decode(texelFetch(scene, camera_data_slot_pixel(slot, textureSize(scene, 0)), 0).rgb);
}

mat4 camera_matrix(sampler2D scene, int base) {
    mat4 m;
    for (int c = 0; c < 4; c++) {
        for (int r = 0; r < 4; r++) {
            m[c][r] = camera_slot(scene, base + c * 4 + r);
        }
    }
    return m;
}

Camera camera_load_lite_direct(sampler2D scene) {
    Camera camera;
    cameraScreenSize = textureSize(scene, 0);
    camera.valid = abs(camera_slot(scene, CAMERA_DATA_MAGIC_SLOT) - CAMERA_DATA_MAGIC) < 0.25;
    camera.view = camera_matrix(scene, 0);
    camera.projection = camera_matrix(scene, 16);
    camera.inverseView = mat4(1.0);
    camera.inverseProjection = mat4(1.0);
    camera.daytime = camera_slot(scene, CAMERA_DATA_DAYTIME_SLOT);
    camera.fogStart = camera_slot(scene, CAMERA_DATA_FOG_START_SLOT);
    camera.fogEnd = camera_slot(scene, CAMERA_DATA_FOG_END_SLOT);
    camera.fogColor = vec3(camera_slot(scene, CAMERA_DATA_FOG_COLOR_SLOT), camera_slot(scene, CAMERA_DATA_FOG_COLOR_SLOT + 1), camera_slot(scene, CAMERA_DATA_FOG_COLOR_SLOT + 2));
    camera.underwater = abs(camera.fogStart + 8.0) < 0.5 && camera.fogEnd <= 96.5;
    camera.weather = camera_slot(scene, CAMERA_DATA_WEATHER_SLOT);
    camera.firstPerson = camera_slot(scene, CAMERA_DATA_MARKER_DISTANCE_SLOT) < 1.5;
    camera.skyValid = camera.weather >= 0.0 && camera.weather <= 1.01 && camera.daytime >= 0.0 && camera.daytime < 24000.0;
    return camera;
}

Camera camera_load_direct(sampler2D scene) {
    Camera camera = camera_load_lite_direct(scene);
    mat3 rotation = inverse(mat3(camera.view));
    camera.inverseView = mat4(rotation);
    camera.inverseView[3] = vec4(-(rotation * camera.view[3].xyz), 1.0);
    camera.inverseProjection = inverse(camera.projection);
    return camera;
}
#ifdef CAMERA_FROM_QUAD
layout(location = 1) flat in vec4 quadCamera[19];

Camera camera_quad() {
    Camera camera;
    camera.view = mat4(quadCamera[0], quadCamera[1], quadCamera[2], quadCamera[3]);
    camera.projection = mat4(quadCamera[4], quadCamera[5], quadCamera[6], quadCamera[7]);
    camera.inverseView = mat4(quadCamera[8], quadCamera[9], quadCamera[10], quadCamera[11]);
    camera.inverseProjection = mat4(quadCamera[12], quadCamera[13], quadCamera[14], quadCamera[15]);
    camera.daytime = quadCamera[16].x;
    camera.fogStart = quadCamera[16].y;
    camera.fogEnd = quadCamera[16].z;
    camera.weather = quadCamera[16].w;
    camera.fogColor = quadCamera[17].xyz;
    camera.firstPerson = quadCamera[17].w < 1.5;
    camera.valid = quadCamera[18].x > 0.5;
    cameraScreenSize = ivec2(quadCamera[18].yz + 0.5);
    camera.underwater = abs(camera.fogStart + 8.0) < 0.5 && camera.fogEnd <= 96.5;
    camera.skyValid = camera.weather >= 0.0 && camera.weather <= 1.01 && camera.daytime >= 0.0 && camera.daytime < 24000.0;
    return camera;
}

Camera camera_load_lite(sampler2D scene) {
    Camera camera = camera_quad();
    return camera.valid ? camera : camera_load_lite_direct(scene);
}

Camera camera_load(sampler2D scene) {
    Camera camera = camera_quad();
    return camera.valid ? camera : camera_load_direct(scene);
}
#else
Camera camera_load_lite(sampler2D scene) {
    return camera_load_lite_direct(scene);
}

Camera camera_load(sampler2D scene) {
    return camera_load_direct(scene);
}
#endif

bool camera_quick_underwater(sampler2D scene) {
    cameraScreenSize = textureSize(scene, 0);
    return abs(camera_slot(scene, CAMERA_DATA_MAGIC_SLOT) - CAMERA_DATA_MAGIC) < 0.25
        && abs(camera_slot(scene, CAMERA_DATA_FOG_START_SLOT) + 8.0) < 0.5
        && camera_slot(scene, CAMERA_DATA_FOG_END_SLOT) <= 96.5;
}

bool camera_has_daytime(Camera camera) {
    return camera.daytime >= 0.0 && camera.daytime < 24000.0;
}

vec3 camera_sun_direction(Camera camera) {
    float timeOfDay = fract(camera.daytime / 24000.0 - 0.25);
    float smoothed = 0.5 - cos(timeOfDay * 3.14159265) * 0.5;
    float celestial = (timeOfDay * 2.0 + smoothed) / 3.0;
    float angle = celestial * 6.2831853;
    const float tilt = 0.6981317;
    return normalize(vec3(-sin(angle), cos(angle) * cos(tilt), cos(angle) * sin(tilt)));
}

bool camera_is_data_pixel(ivec2 pixel) {
    return camera_data_in_strip(pixel, cameraScreenSize);
}

vec3 camera_scene_color(sampler2D scene, ivec2 pixel) {
    ivec2 size = textureSize(scene, 0);
    if (camera_data_in_strip(pixel, size)) {
        pixel.y = int(CAMERA_STRIP_HEIGHT * float(size.y)) + 2;
    }
    return texelFetch(scene, pixel, 0).rgb;
}

vec3 camera_relative(Camera camera, vec2 uv, float depth) {
    vec4 view = camera.inverseProjection * vec4(uv * 2.0 - 1.0, depth, 1.0);
    view /= view.w;
    return (camera.inverseView * vec4(view.xyz, 1.0)).xyz;
}

vec3 camera_ray(Camera camera, vec2 uv) {
    vec4 far = camera.inverseProjection * vec4(uv * 2.0 - 1.0, 1e-5, 1.0);
    vec4 eye = camera.inverseProjection * vec4(0.0, 0.0, 1.0, 0.0);
    vec3 origin = abs(eye.w) > 1e-6 ? eye.xyz / eye.w : vec3(0.0);
    return normalize((camera.inverseView * vec4(far.xyz / far.w - origin, 0.0)).xyz);
}

vec3 camera_world_origin() {
    return vec3(CameraBlockPos) - CameraOffset;
}

#endif
