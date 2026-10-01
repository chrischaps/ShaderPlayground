// @name Radial Blur
// @category Distort
// @desc Zoom blur streaking out from a point
// @about Averages samples along the line from each pixel to the center, as if
// @about the camera zoomed while the shutter was open. A random per-pixel
// @about offset along that line trades visible banding for fine noise.

#include "lib/noise.glsl"

uniform float strength; // default=0.15 min=0 max=0.6
uniform int   samples;  // default=24 min=4 max=64
uniform vec2  center;   // xy default=0.5,0.5 tip="Blur center"
uniform float jitter;   // default=1 min=0 max=1 tip="Dither the samples to hide banding"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 dir = uv - center;
    float offset = (hash12(sc + fract(iTime) * 100.0) - 0.5) * jitter;
    vec4 result = vec4(0.0);
    for (int i = 0; i < 64; i++) {
        if (i >= samples) break;
        float t = (float(i) + offset) / float(samples);
        result += Texel(tex, center + dir * (1.0 - strength * t));
    }
    return vec4((result / float(samples)).rgb, 1.0) * color;
}
