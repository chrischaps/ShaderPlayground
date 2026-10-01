// @name Edge Detect
// @category Paint
// @desc Sobel edges as white lines, ink outlines, or neon
// @about The Sobel operator measures how quickly brightness changes, by
// @about comparing the 3x3 neighborhood on the left with the right and the top
// @about with the bottom. Strong changes are edges. Those can be drawn alone,
// @about inked over the image, or glowing over a darkened copy.

uniform int   mode;      // enum=Edges,Ink,Neon default=Ink
uniform float threshold; // default=0.15 min=0 max=1 tip="Minimum edge strength"
uniform float width;     // default=1 min=0.5 max=4 tip="Line width in pixels"
uniform vec3  lineColor; // color default=#14101e
uniform float darken;    // default=0.75 min=0 max=1 tip="Neon mode: darken the image underneath"

float L(Image t, vec2 uv) { return luma(Texel(t, uv).rgb); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 e = iTexel * width;
    float tl = L(tex, uv + vec2(-e.x, -e.y)), t = L(tex, uv + vec2(0.0, -e.y)), tr = L(tex, uv + vec2(e.x, -e.y));
    float l  = L(tex, uv + vec2(-e.x, 0.0)),                                     r  = L(tex, uv + vec2(e.x, 0.0));
    float bl = L(tex, uv + vec2(-e.x,  e.y)), b = L(tex, uv + vec2(0.0,  e.y)), br = L(tex, uv + vec2(e.x,  e.y));
    float gx = tl + 2.0 * l + bl - tr - 2.0 * r - br;
    float gy = tl + 2.0 * t + tr - bl - 2.0 * b - br;
    float g = length(vec2(gx, gy));
    float edge = smoothstep(threshold, threshold + 0.15, g);

    vec3 c = Texel(tex, uv).rgb;
    vec3 outc;
    if (mode == 0) {
        outc = vec3(edge);
    } else if (mode == 1) {
        outc = mix(c, lineColor, edge);
    } else {
        // Neon: hue taken from the edge direction
        float a = atan(gy, gx);
        vec3 hue = 0.5 + 0.5 * cos(a + vec3(0.0, 2.094, 4.188));
        outc = c * (1.0 - darken) + hue * edge * 1.5;
    }
    return vec4(outc, 1.0) * color;
}
