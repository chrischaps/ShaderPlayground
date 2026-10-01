// @name Film Grain
// @category Film
// @desc Organic, luminance-aware grain
// @about Film grain is strongest in the midtones and nearly vanishes in deep
// @about blacks and clipped whites. The noise here is reseeded every frame,
// @about scaled by a midtone curve, and can be sized up for a coarse
// @about high-ISO look.

#include "lib/noise.glsl"

uniform float intensity; // default=0.12 min=0 max=0.5
uniform float size;      // default=1.5 min=1 max=6 tip="Grain size in pixels"
uniform float color;     // default=0.15 min=0 max=1 tip="Colored vs monochrome grain"
uniform float response;  // default=0.8 min=0 max=1 tip="How much grain follows the midtones"

vec4 effect(vec4 col, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    vec2 p = floor(sc / size);
    float seed = float(iFrame % 1024) * 13.37;
    // Sum two hashes for a softer, closer to Gaussian distribution
    vec3 n = (hash32(p + seed) + hash32(p * 1.7 + seed + 5.1)) - 1.0;
    n = mix(vec3(n.x), n, color);
    float l = luma(c);
    float mid = mix(1.0, 1.0 - pow(abs(l * 2.0 - 1.0), 2.0), response);
    c += n * intensity * mid;
    return vec4(c, 1.0) * col;
}
