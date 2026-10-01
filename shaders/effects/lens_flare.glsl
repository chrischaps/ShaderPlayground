// @name Lens Flare
// @category Light
// @desc Ghosts and a halo reflected from bright highlights
// @about Real flares are light bouncing between lens elements; those copies
// @about land mirrored through the image center. This screen-space version
// @about (after John Chapman) flips the bright parts of the image, samples
// @about them at several points along the line through the center (the
// @about ghosts), adds a ring (the halo) and splits colors for the lens's
// @about dispersion, then blurs and adds it back.

#include "lib/blur.glsl"

uniform float threshold;  // default=0.7 min=0 max=2
uniform int   ghosts;     // default=5 min=1 max=8
uniform float dispersal;  // default=0.35 min=0.05 max=1 tip="Spacing of the ghosts"
uniform float halo;       // default=0.45 min=0 max=0.8 tip="Halo ring radius"
uniform float dispersion; // default=0.006 min=0 max=0.03 tip="Color splitting"
uniform float intensity;  // default=0.8 min=0 max=3
uniform float rainbow;    // default=0.6 min=0 max=1 tip="Color the ghosts by distance from center"

//@pass bright in=input scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    return vec4(max(c - threshold, 0.0), 1.0);
}

//@pass features in=bright scale=0.5
vec3 split(Image t, vec2 uv, vec2 dir) {
    return vec3(Texel(t, uv + dir * dispersion).r, Texel(t, uv).g, Texel(t, uv - dir * dispersion).b);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 tuv = 1.0 - uv;
    vec2 ghostVec = (0.5 - tuv) * dispersal;
    vec2 dir = normalize(ghostVec + 1e-5);
    vec3 result = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        if (i >= ghosts) break;
        vec2 o = fract(tuv + ghostVec * float(i));
        float w = pow(1.0 - clamp(length(0.5 - o) / 0.7071, 0.0, 1.0), 10.0);
        vec3 ramp = mix(vec3(1.0), 0.5 + 0.5 * cos(TAU * (length(0.5 - o) * 1.6 + vec3(0.0, 0.33, 0.67))), rainbow);
        result += split(tex, o, dir) * w * ramp;
    }
    vec2 hv = normalize(ghostVec + 1e-5) * halo;
    vec2 ho = fract(tuv + hv);
    float hw = pow(1.0 - clamp(length(0.5 - ho) / 0.7071, 0.0, 1.0), 5.0);
    result += split(tex, ho, dir) * hw;
    return vec4(result, 1.0);
}

//@pass blurH in=features scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return blur9(tex, uv, vec2(iTexel.x * 2.0, 0.0)); }

//@pass blurV in=blurH scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return blur9(tex, uv, vec2(0.0, iTexel.y * 2.0)); }

//@pass composite in=input
uniform Image blurV;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return vec4(Texel(tex, uv).rgb + Texel(blurV, uv).rgb * intensity, 1.0) * color;
}
