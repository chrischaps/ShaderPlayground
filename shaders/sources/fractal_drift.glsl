// @name Fractal Drift
// @category Generative
// @desc Julia sets that morph, or a slow dive into the Mandelbrot set
// @about Each pixel is a complex number, iterated through z = z² + c until it
// @about escapes or the iteration limit runs out. In a Julia set c is fixed
// @about and drifts slowly here, morphing the shape. "Smooth" iteration counts
// @about remove the stepped bands, and orbit traps (the closest z comes to a
// @about point) add the glowing filaments.

#include "lib/color.glsl"

uniform int   mode;       // enum=Julia,Mandelbrot default=Julia
uniform int   palette;    // enum=Ember,Rainbow,Lagoon,Dusk,Coral,Neon default=Dusk
uniform float speed;      // default=0.3 min=0 max=2
uniform int   iterations; // default=180 min=32 max=600
uniform float zoom;       // default=1 min=0.3 max=6 log
uniform float glow;       // default=0.7 min=0 max=2 tip="Orbit-trap filaments"
uniform float hueShift;   // default=0 min=0 max=1
uniform int   aa;         // default=2 min=1 max=3 tip="Anti-aliasing (samples per axis)"

vec3 render(vec2 p) {
    float t = iTime * speed;
    vec2 z, c;
    if (mode == 0) {
        float a = t * 0.21 + 2.0;
        c = 0.7885 * vec2(cos(a), sin(a));
        z = p * 1.6 / zoom;
    } else {
        float depth = (0.5 - 0.5 * cos(t * 0.12)) * 8.0;
        vec2 center = vec2(-0.743643887, 0.131825904);
        c = center + p * 2.6 * exp(-depth) / zoom;
        z = vec2(0.0);
    }
    float trap = 1e9;
    float n = 0.0;
    float r2 = 0.0;
    for (int i = 0; i < 600; i++) {
        if (i >= iterations) break;
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        r2 = dot(z, z);
        trap = min(trap, abs(length(z - vec2(0.0, 0.0)) - 0.5));
        if (r2 > 256.0) break;
        n += 1.0;
    }
    if (n >= float(iterations)) {
        // inside: deep, faintly lit by the trap
        return namedPalette(trap * 2.0 + hueShift + 0.5, palette) * 0.05 * glow;
    }
    float sn = n - log2(log2(r2)) + 4.0;
    vec3 col = namedPalette(sn * 0.025 + hueShift + t * 0.02, palette);
    // fade the far outside to near-black so the set's edge glows
    col *= 0.02 + 0.98 * pow(smoothstep(1.0, 40.0, sn), 1.4);
    col += namedPalette(hueShift + 0.6, palette) * exp(-trap * 18.0) * glow * 0.6;
    return col;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 col = vec3(0.0);
    for (int j = 0; j < 3; j++)
    for (int i = 0; i < 3; i++) {
        if (i >= aa || j >= aa) continue;
        vec2 o = (vec2(float(i), float(j)) + 0.5) / float(aa) - 0.5;
        vec2 p = centered(uv + o / iResolution.xy);
        col += render(p);
    }
    col /= float(aa * aa);
    return vec4(col, 1.0);
}
