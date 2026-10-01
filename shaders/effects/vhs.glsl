// @name VHS
// @category Retro
// @desc Tape wobble, chroma bleed and tracking noise
// @about VHS stored brightness (luma) at much higher resolution than color
// @about (chroma), so colors smear sideways past the edges they belong to.
// @about This converts to YIQ, the color space NTSC broadcast used, blurs only
// @about the chroma horizontally, and shifts it slightly right. Each scanline
// @about wobbles with noise, the tracking band at the bottom tears, and tape
// @about noise flickers across the frame.

#include "lib/noise.glsl"

uniform float wobble;     // default=0.5 min=0 max=2 tip="Horizontal line jitter"
uniform float bleed;      // default=0.7 min=0 max=2 tip="Chroma smear"
uniform float noise;      // default=0.35 min=0 max=1 tip="Tape noise and specks"
uniform float tracking;   // default=0.5 min=0 max=1 tip="Torn band at the bottom"
uniform float saturation; // default=0.85 min=0 max=1.5
uniform float lines;      // default=240 min=120 max=480 step=1 tip="Vertical resolution of the tape"

const mat3 RGB2YIQ = mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312);
const mat3 YIQ2RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float row = floor(uv.y * lines);
    float t = iTime;

    // line wobble + occasional jolts
    float jolt = step(0.985, hash11(floor(t * 6.0))) * (hash11(floor(t * 6.0) + 3.0) - 0.5) * 0.03;
    float off = gradientNoise(vec2(row * 0.05, t * 3.0)) * 0.0025 * wobble + jolt * wobble;

    // tracking tear at the bottom
    float band = smoothstep(1.0 - 0.08 * tracking, 1.0, uv.y) * tracking;
    off += band * (hash12(vec2(row, floor(t * 30.0))) - 0.5) * 0.08;

    vec2 p = vec2(uv.x + off, uv.y);
    float y = (RGB2YIQ * Texel(tex, p).rgb).x;

    // chroma: wide horizontal blur, delayed to the right
    vec2 iq = vec2(0.0);
    float wsum = 0.0;
    for (int i = -6; i <= 6; i++) {
        float w = exp(-float(i * i) / 18.0);
        vec3 s = RGB2YIQ * Texel(tex, p + vec2((float(i) * 1.6 - 3.0) * iTexel.x * bleed * 2.0, 0.0)).rgb;
        iq += s.yz * w;
        wsum += w;
    }
    iq = iq / wsum * saturation;
    vec3 c = YIQ2RGB * vec3(y, iq);

    // tape noise: faint rolling bands + white specks
    float roll = smoothstep(0.0, 0.02, abs(fract(uv.y * 0.6 - t * 0.07) - 0.5)) ;
    c *= mix(1.0, 0.9 + 0.1 * roll, noise);
    float speck = step(1.0 - 0.0025 * noise, hash12(vec2(floor(sc.x / 2.0), row + floor(t * 60.0) * 7.0)));
    c += speck * 0.8 + band * hash12(sc + t) * 0.5;
    c += (hash12(sc + fract(t) * 100.0) - 0.5) * 0.06 * noise;

    // soft scanlines and lifted blacks
    c *= 0.94 + 0.06 * sin(uv.y * lines * PI * 2.0);
    c = c * 0.92 + 0.03;
    return vec4(c, 1.0) * color;
}
