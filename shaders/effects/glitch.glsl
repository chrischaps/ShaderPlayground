// @name Glitch
// @category Distort
// @desc Corrupted blocks, torn lines and split color channels
// @about Digital glitches come from damaged data, where whole blocks decode in
// @about the wrong place. Time is quantized into steps (rate), and per step a
// @about hash decides which rectangular blocks shift, which scanlines tear and
// @about how far the color channels separate. Nothing is random between
// @about steps, so it stutters instead of flickering.

#include "lib/noise.glsl"

uniform float amount;    // default=0.45 min=0 max=1
uniform float rate;      // default=8 min=1 max=30 tip="Glitch changes per second"
uniform float blockSize; // default=0.05 min=0.01 max=0.2
uniform float split;     // default=0.012 min=0 max=0.05 tip="Color channel separation"
uniform float tear;      // default=0.5 min=0 max=1 tip="Scanline tearing"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float t = floor(iTime * rate);
    float burst = smoothstep(0.3, 0.9, hash11(t * 0.37 + 1.0)) * amount;

    vec2 bs = vec2(blockSize * 4.0, blockSize);
    vec2 block = floor(uv / bs);
    float h = hash12(block + t * 13.1);
    vec2 p = uv;
    if (h < burst * 0.35) {
        p.x += (hash12(block + t) - 0.5) * 0.25 * amount;
    }
    // scanline tearing
    float row = floor(uv.y * iResolution.y / 2.0);
    float rh = hash12(vec2(row, t));
    if (rh > 1.0 - tear * burst * 0.25) {
        p.x += (rh - 0.5) * 0.06;
    }

    float s = split * (0.3 + burst * 2.0) * (h < burst * 0.5 ? 2.0 : 1.0);
    vec3 c;
    c.r = Texel(tex, p + vec2(s, 0.0)).r;
    c.g = Texel(tex, p).g;
    c.b = Texel(tex, p - vec2(s, 0.0)).b;

    // occasional inverted or crushed blocks
    float hb = hash12(block * 1.7 + t * 3.3);
    if (hb > 1.0 - burst * 0.06) c = 1.0 - c;
    else if (hb < burst * 0.04) c = floor(c * 3.0) / 3.0;

    // block noise
    if (h < burst * 0.1) c = mix(c, vec3(hash12(sc + t)), 0.5);
    return vec4(c, 1.0) * color;
}
