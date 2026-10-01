// @name Toon
// @category Paint
// @desc Cel shading: flat bands of light with inked outlines
// @about Cartoon shading has a few flat tones per color instead of smooth
// @about gradients. This keeps each pixel's hue but snaps its brightness to a
// @about few soft-edged bands, boosts saturation, and draws ink lines where a
// @about Sobel filter finds edges.

#include "lib/color.glsl"

uniform float bands;      // default=4 min=2 max=10 step=1
uniform float softness;   // default=0.15 min=0 max=0.5 tip="Blend between bands"
uniform float saturation; // default=1.35 min=0 max=2.5
uniform float outline;    // default=1 min=0 max=3 tip="Line width (0 = none)"
uniform float threshold;  // default=0.25 min=0.02 max=1
uniform vec3  inkColor;   // color default=#15121c

float L(Image t, vec2 uv) { return luma(Texel(t, uv).rgb); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = clamp(Texel(tex, uv).rgb, 0.0, 1.0);
    vec3 hsv = rgb2hsv(c);
    float v = hsv.z * bands;
    float f = fract(v);
    float stepped = (floor(v) + smoothstep(0.5 - softness, 0.5 + softness, f)) / bands;
    hsv.z = clamp(stepped + 0.5 / bands, 0.0, 1.0);
    hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
    vec3 col = hsv2rgb(hsv);

    if (outline > 0.0) {
        vec2 e = iTexel * outline;
        float gx = L(tex, uv + vec2(-e.x, 0.0)) - L(tex, uv + vec2(e.x, 0.0));
        float gy = L(tex, uv + vec2(0.0, -e.y)) - L(tex, uv + vec2(0.0, e.y));
        float gd1 = L(tex, uv - e) - L(tex, uv + e);
        float gd2 = L(tex, uv + vec2(e.x, -e.y)) - L(tex, uv + vec2(-e.x, e.y));
        float g = sqrt(gx * gx + gy * gy + 0.5 * (gd1 * gd1 + gd2 * gd2));
        col = mix(col, inkColor, smoothstep(threshold, threshold + 0.1, g));
    }
    return vec4(col, 1.0) * color;
}
