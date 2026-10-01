// @name Halftone
// @category Paint
// @desc CMYK print dots on paper
// @about Printing presses can only lay down ink or no ink, so they fake tone
// @about with dots that grow and shrink. Each of cyan, magenta, yellow and
// @about black gets its own grid, rotated to a different angle (15°, 75°, 0°
// @about and 45°) so the grids don't interfere with each other. Inks multiply
// @about onto the paper, the way they do on a real page.

uniform float size;     // default=8 min=3 max=40 step=0.5 tip="Dot spacing in pixels"
uniform float rotation; // angle default=0 tip="Extra rotation of all screens"
uniform int   mode;     // enum=CMYK,Mono default=CMYK
uniform vec3  paper;    // color default=#f5f0e4
uniform vec3  ink;      // color default=#141218 tip="Ink color in mono mode"
uniform float gain;     // default=1 min=0.5 max=1.6 tip="Dot gain: how much ink spreads"

vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

float inkAmount(vec3 c, int channel) {
    if (mode == 1) return 1.0 - luma(c);
    float k = 1.0 - max(c.r, max(c.g, c.b));
    float inv = 1.0 / max(1.0 - k, 1e-4);
    if (channel == 0) return (1.0 - c.r - k) * inv;
    if (channel == 1) return (1.0 - c.g - k) * inv;
    if (channel == 2) return (1.0 - c.b - k) * inv;
    return k;
}

// Coverage (0..1) of one screen at this pixel. Large dots overlap their
// neighbors' cells, so the 3×3 surrounding dots are all checked.
float screen(Image tex, vec2 sc, float angle, int channel) {
    vec2 p = rot(sc, angle);
    vec2 base = floor(p / size);
    float cover = 0.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 cell = base + vec2(float(i), float(j)) + 0.5;
        vec2 center = rot(cell * size, -angle);
        vec3 c = Texel(tex, center / iResolution.xy).rgb;
        float r = sqrt(clamp(inkAmount(c, channel) * gain, 0.0, 1.0)) * size * 0.75;
        float d = length(p - cell * size);
        cover = max(cover, smoothstep(r + 0.75, r - 0.75, d));
    }
    return cover;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 col = paper;
    if (mode == 1) {
        col = mix(paper, ink, screen(tex, sc, 0.785 + rotation, 3));
    } else {
        col *= mix(vec3(1.0), vec3(0.0, 0.68, 0.94), screen(tex, sc, 0.262 + rotation, 0));
        col *= mix(vec3(1.0), vec3(0.93, 0.0, 0.55), screen(tex, sc, 1.309 + rotation, 1));
        col *= mix(vec3(1.0), vec3(1.0, 0.94, 0.0), screen(tex, sc, 0.0 + rotation, 2));
        col *= mix(vec3(1.0), vec3(0.12, 0.11, 0.13), screen(tex, sc, 0.785 + rotation, 3));
    }
    return vec4(col, 1.0) * color;
}
