// @name Ink Flow
// @category Simulation
// @desc Marbled ink carried by a swirling current (drag to stir)
// @about Ink lives in a persistent buffer. Each frame every pixel looks
// @about backward along a flow field to see where its ink came from
// @about (semi-Lagrangian advection). The flow is the curl of noise, which
// @about guarantees swirls without sinks or sources, so the ink folds into
// @about marbled ribbons instead of piling up. Drifting emitters keep adding
// @about color while the old ink slowly fades.

#include "lib/noise.glsl"
#include "lib/color.glsl"

uniform float flow;     // default=0.18 min=0 max=0.6 tip="Current strength"
uniform float scale;    // default=1.6 min=0.3 max=5 tip="Size of the eddies"
uniform float emit;     // default=1 min=0 max=3 tip="Ink added by the emitters"
uniform int   emitters; // default=3 min=0 max=6
uniform float fade;     // default=0.08 min=0 max=1 tip="How quickly old ink disappears"
uniform int   palette;  // enum=Ember,Rainbow,Lagoon,Dusk,Coral,Neon default=Lagoon
uniform vec3  paper;    // color default=#06060c
uniform float exposure; // default=1.2 min=0.2 max=4

//@pass ink in=self format=rgba16f
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    if (iFrame == 0) {
        // start with a faint marbled wash so the first frames aren't empty
        vec2 q = uv * vec2(iResolution.z, 1.0) * 2.2;
        float n = fbm(q + fbm(q * 1.3, 3) * 1.5, 4);
        vec3 seed = namedPalette(n * 0.8 + 0.2, palette) * smoothstep(-0.1, 0.5, n) * 0.6;
        return vec4(seed, 1.0);
    }
    float dt = min(iTimeDelta, 1.0 / 20.0);
    vec2 asp = vec2(iResolution.z, 1.0);
    vec2 p = uv * asp * scale;
    float t = iTime * 0.06;
    vec2 vel = curlNoise(p + vec2(t, -t * 0.7)) + 0.5 * curlNoise(p * 2.3 - t);
    vel = vel / asp * flow * 0.12;

    // look backward along the flow
    vec3 ink = Texel(tex, uv - vel * dt * 6.0).rgb;
    ink *= 1.0 - fade * dt;

    // drifting emitters
    for (int i = 0; i < 6; i++) {
        if (i >= emitters) break;
        float fi = float(i);
        vec2 c = 0.5 + vec2(0.36 * sin(iTime * (0.13 + fi * 0.031) + fi * 2.1),
                            0.33 * sin(iTime * (0.17 + fi * 0.023) + fi * 4.0));
        float d = length((uv - c) * asp);
        vec3 col = namedPalette(fi / 6.0 + iTime * 0.015, palette);
        ink += col * smoothstep(0.035, 0.0, d) * emit * dt * 3.0;
    }
    // mouse brush
    if (iMouse.z > 0.5) {
        float d = length((uv - iMouse.xy) * asp);
        ink += namedPalette(iTime * 0.1, palette) * smoothstep(0.03, 0.0, d) * dt * 8.0;
    }
    return vec4(ink, 1.0);
}

//@pass show in=ink
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 ink = Texel(tex, uv).rgb;
    vec3 col = paper + (1.0 - exp(-ink * exposure));
    return vec4(col, 1.0);
}
