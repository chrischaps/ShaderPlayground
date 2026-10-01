// @name Bloom
// @category Light
// @desc Multi-pass glow around bright areas
// @about Bright pixels are pulled out with a soft threshold, then blurred at
// @about half and quarter resolution with separable Gaussians (horizontal
// @about pass, then vertical). The two blur sizes are layered so the glow has
// @about a tight core and a wide halo. Working at low resolution makes huge
// @about blurs cheap.

#include "lib/blur.glsl"

uniform float threshold; // default=0.6 min=0 max=2 step=0.01 tip="Brightness where glow begins"
uniform float knee;      // default=0.3 min=0.01 max=1 tip="Softness of the threshold"
uniform float radius;    // default=1.5 min=0.5 max=4 tip="Blur spread"
uniform float intensity; // default=0.9 min=0 max=3
uniform float halo;      // default=0.6 min=0 max=2 tip="Strength of the wide, low-res layer"
uniform vec3  tint;      // color default=#ffffff
uniform int   blend;     // enum=Add,Screen default=Screen

//@pass bright in=input scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 s = Texel(tex, uv).rgb;
    float l = max(s.r, max(s.g, s.b));
    float w = smoothstep(threshold - knee, threshold + knee, l);
    return vec4(s * w, 1.0);
}

//@pass blurH1 in=bright scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(iTexel.x * radius, 0.0));
}

//@pass blurV1 in=blurH1 scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(0.0, iTexel.y * radius));
}

//@pass blurH2 in=blurV1 scale=0.125
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(iTexel.x * radius, 0.0));
}

//@pass blurV2 in=blurH2 scale=0.125
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(0.0, iTexel.y * radius));
}

//@pass composite in=input
uniform Image blurV1;
uniform Image blurV2;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 s = Texel(tex, uv).rgb;
    vec3 b = (Texel(blurV1, uv).rgb + Texel(blurV2, uv).rgb * halo) * tint * intensity;
    vec3 outc = blend == 0 ? s + b : 1.0 - (1.0 - clamp(s, 0.0, 1.0)) * (1.0 - clamp(b, 0.0, 1.0));
    return vec4(outc, 1.0) * color;
}
