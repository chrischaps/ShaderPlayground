// @name Reaction-Diffusion
// @category Simulation
// @desc Gray-Scott chemistry growing coral, spots and mazes (drag to seed)
// @about Two virtual chemicals spread out at different speeds. B consumes A to
// @about make more B, A is fed in, and B slowly dies off. That's all, yet these
// @about rules grow coral, cell division and fingerprint mazes, the same
// @about mechanism Alan Turing proposed for animal markings. The simulation
// @about runs 12 steps per frame in a persistent buffer, and the render pass
// @about lights the result as if it had depth.

#include "lib/noise.glsl"

uniform int   pattern;    // enum=Coral,Mitosis,Worms,Spots,Maze,Custom default=Coral
uniform float feed;       // default=0.055 min=0.01 max=0.1 step=0.0005 tip="Custom pattern: feed rate"
uniform float kill;       // default=0.062 min=0.045 max=0.07 step=0.0005 tip="Custom pattern: kill rate"
uniform float variation;  // default=0.3 min=0 max=1 tip="Vary the chemistry across the screen"
uniform float brush;      // default=0.03 min=0.005 max=0.1 tip="Seeding brush size"
uniform vec3  colorA;     // color default=#0b0a1a
uniform vec3  colorB;     // color default=#ff7a59
uniform vec3  colorC;     // color default=#ffe8c2
uniform float relief;     // default=1 min=0 max=3 tip="Fake lighting depth"

vec2 params(vec2 uv) {
    vec2 fk;
    if (pattern == 0) fk = vec2(0.0545, 0.062);
    else if (pattern == 1) fk = vec2(0.0367, 0.0649);
    else if (pattern == 2) fk = vec2(0.078, 0.061);
    else if (pattern == 3) fk = vec2(0.035, 0.065);
    else if (pattern == 4) fk = vec2(0.029, 0.057);
    else fk = vec2(feed, kill);
    float n = gradientNoise(uv * 2.5 + 3.1);
    fk.x += n * 0.006 * variation;
    fk.y += gradientNoise(uv * 2.0 - 7.3) * 0.0015 * variation;
    return fk;
}

//@pass sim in=self iterations=12 scale=0.5 format=rgba32f wrap=repeat
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    if (iFrame == 0) {
        // Seed: mostly A, with scattered droplets of B
        vec2 cell = floor(uv * vec2(iResolution.z, 1.0) * 14.0);
        float h = hash12(cell);
        vec2 c = (cell + 0.5) / (vec2(iResolution.z, 1.0) * 14.0);
        float d = length((uv - c) * vec2(iResolution.z, 1.0));
        float b = (h > 0.82 && d < 0.02) ? 1.0 : 0.0;
        b = max(b, step(length((uv - 0.5) * vec2(iResolution.z, 1.0)), 0.04));
        return vec4(1.0, b, 0.0, 1.0);
    }
    if (iTimeDelta <= 0.0) return Texel(tex, uv);   // paused: hold the state
    vec2 e = iTexel;
    vec2 s = Texel(tex, uv).rg;
    vec2 lap = -s
        + 0.2 * (Texel(tex, uv + vec2(e.x, 0.0)).rg + Texel(tex, uv - vec2(e.x, 0.0)).rg
               + Texel(tex, uv + vec2(0.0, e.y)).rg + Texel(tex, uv - vec2(0.0, e.y)).rg)
        + 0.05 * (Texel(tex, uv + e).rg + Texel(tex, uv - e).rg
                + Texel(tex, uv + vec2(e.x, -e.y)).rg + Texel(tex, uv + vec2(-e.x, e.y)).rg);
    vec2 fk = params(uv);
    float a = s.r, b = s.g;
    float abb = a * b * b;
    a += 1.0 * lap.r - abb + fk.x * (1.0 - a);
    b += 0.5 * lap.g + abb - (fk.y + fk.x) * b;

    if (iMouse.z > 0.5) {
        float d = length((uv - iMouse.xy) * vec2(iResolution.z, 1.0));
        if (d < brush) b = 1.0;
    }
    return vec4(clamp(a, 0.0, 1.0), clamp(b, 0.0, 1.0), 0.0, 1.0);
}

//@pass render in=sim
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float b = Texel(tex, uv).g;
    vec2 e = iTexel * 1.5;
    float bx = Texel(tex, uv + vec2(e.x, 0.0)).g - Texel(tex, uv - vec2(e.x, 0.0)).g;
    float by = Texel(tex, uv + vec2(0.0, e.y)).g - Texel(tex, uv - vec2(0.0, e.y)).g;
    vec3 n = normalize(vec3(-bx * relief * 4.0, -by * relief * 4.0, 1.0));
    vec3 L = normalize(vec3(-0.5, -0.6, 0.8));
    float diff = max(dot(n, L), 0.0);
    float spec = pow(max(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);

    float v = smoothstep(0.1, 0.45, b);
    vec3 col = mix(colorA, colorB, v);
    col = mix(col, colorC, smoothstep(0.3, 0.6, b));
    col *= 0.55 + 0.6 * diff;
    col += spec * 0.35 * v;
    return vec4(col, 1.0);
}
