// @name Dither
// @category Retro
// @desc Ordered dithering to classic hardware palettes
// @about Limited palettes fake in-between colors by mixing neighboring pixels.
// @about A Bayer matrix gives each pixel a threshold from a fixed pattern of
// @about offsets. Adding that offset before snapping to the nearest palette
// @about color makes the pattern's density follow the brightness. "Noise"
// @about uses interleaved gradient noise, which gives a less regular grain.

uniform int   palette;    // enum="Game Boy,PICO-8,CGA,1-bit,Sepia,Per-channel" default=0
uniform int   method;     // enum=Bayer,Noise,None default=Bayer
uniform float pixelSize;  // default=3 min=1 max=12 step=1 tip="Chunky pixels"
uniform float spread;     // default=0.5 min=0 max=1.5 tip="Strength of the dither pattern"
uniform float brightness; // default=0 min=-0.5 max=0.5
uniform float contrast;   // default=1.1 min=0.5 max=2

const vec3 GB[4] = vec3[4](vec3(0.06, 0.22, 0.06), vec3(0.19, 0.38, 0.19), vec3(0.55, 0.67, 0.06), vec3(0.61, 0.74, 0.06));
const vec3 CGA[4] = vec3[4](vec3(0.0), vec3(0.33, 1.0, 1.0), vec3(1.0, 0.33, 1.0), vec3(1.0));
const vec3 ONEBIT[2] = vec3[2](vec3(0.08, 0.07, 0.1), vec3(0.94, 0.91, 0.84));
const vec3 SEPIA[4] = vec3[4](vec3(0.13, 0.09, 0.07), vec3(0.42, 0.3, 0.21), vec3(0.74, 0.6, 0.44), vec3(0.97, 0.91, 0.8));
const vec3 PICO[16] = vec3[16](
    vec3(0.0), vec3(0.114, 0.169, 0.325), vec3(0.494, 0.145, 0.325), vec3(0.0, 0.529, 0.318),
    vec3(0.671, 0.322, 0.212), vec3(0.373, 0.341, 0.310), vec3(0.761, 0.765, 0.780), vec3(1.0, 0.945, 0.910),
    vec3(1.0, 0.0, 0.302), vec3(1.0, 0.639, 0.0), vec3(1.0, 0.925, 0.153), vec3(0.0, 0.894, 0.212),
    vec3(0.161, 0.678, 1.0), vec3(0.514, 0.463, 0.612), vec3(1.0, 0.467, 0.659), vec3(1.0, 0.8, 0.667));

float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }
float ign(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }

float dist2(vec3 a, vec3 b) { vec3 d = a - b; return dot(d * d, vec3(0.3, 0.59, 0.11)); }

vec3 nearest(vec3 c) {
    vec3 best = vec3(0.0);
    float bd = 1e9;
    if (palette == 0) { for (int i = 0; i < 4; i++) { float d = dist2(c, GB[i]); if (d < bd) { bd = d; best = GB[i]; } } }
    else if (palette == 1) { for (int i = 0; i < 16; i++) { float d = dist2(c, PICO[i]); if (d < bd) { bd = d; best = PICO[i]; } } }
    else if (palette == 2) { for (int i = 0; i < 4; i++) { float d = dist2(c, CGA[i]); if (d < bd) { bd = d; best = CGA[i]; } } }
    else if (palette == 3) { for (int i = 0; i < 2; i++) { float d = dist2(c, ONEBIT[i]); if (d < bd) { bd = d; best = ONEBIT[i]; } } }
    else if (palette == 4) { for (int i = 0; i < 4; i++) { float d = dist2(c, SEPIA[i]); if (d < bd) { bd = d; best = SEPIA[i]; } } }
    else { best = floor(c * 4.0 + 0.5) / 4.0; }
    return best;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 cell = floor(sc / pixelSize);
    vec2 cuv = (cell + 0.5) * pixelSize / iResolution.xy;
    vec3 c = Texel(tex, cuv).rgb;
    c = (c - 0.5) * contrast + 0.5 + brightness;
    // Luminance-only palettes compare on gray so the dither reads clearly
    if (palette == 0 || palette == 3 || palette == 4) c = vec3(luma(c));

    float th = 0.5;
    if (method == 0) th = bayer8(cell);
    else if (method == 1) th = ign(cell + float(iFrame % 64) * 5.588238);
    float steps = palette == 1 ? 6.0 : (palette == 3 ? 1.5 : 3.0);
    if (method != 2) c += (th - 0.5) * spread / steps * 1.5;
    return vec4(nearest(clamp(c, 0.0, 1.0)), 1.0) * color;
}
