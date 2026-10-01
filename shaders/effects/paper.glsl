// @name Paper
// @category Paint
// @desc Watercolor paper: grain, fibers and pooled pigment at edges
// @about Watercolor pigment collects where a wash dries, darkening its edges,
// @about and the paper's texture shows through everywhere. Edges are found
// @about from the luminance gradient and darkened. Fine noise and stretched
// @about noise give grain and fibers, and the image is multiplied onto a warm
// @about paper color the way pigment sits on paper.

#include "lib/noise.glsl"

uniform vec3  paperColor; // color default=#f4eddc
uniform float grain;      // default=0.5 min=0 max=1
uniform float fibers;     // default=0.4 min=0 max=1
uniform float edges;      // default=0.6 min=0 max=2 tip="Pigment pooling at the edges of shapes"
uniform float wash;       // default=0.15 min=0 max=0.6 tip="Lighten, as if the paint were diluted"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    vec2 e = iTexel * 2.0;
    float gx = luma(Texel(tex, uv + vec2(e.x, 0.0)).rgb) - luma(Texel(tex, uv - vec2(e.x, 0.0)).rgb);
    float gy = luma(Texel(tex, uv + vec2(0.0, e.y)).rgb) - luma(Texel(tex, uv - vec2(0.0, e.y)).rgb);
    float g = length(vec2(gx, gy));

    c = mix(c, vec3(1.0), wash);
    c *= 1.0 - smoothstep(0.02, 0.25, g) * 0.35 * edges;

    vec2 p = sc;
    float gr = valueNoise(p * 0.7) * 0.6 + valueNoise(p * 0.23) * 0.4;
    float fb = gradientNoise(vec2(p.x * 0.02, p.y * 0.4)) * 0.5 + 0.5;
    float texture_ = 1.0 - grain * 0.12 * (1.0 - gr) - fibers * 0.06 * fb;
    vec3 outc = c * paperColor * texture_;
    return vec4(outc, 1.0) * color;
}
