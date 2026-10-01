// @name Color Grade
// @category Color
// @desc Exposure, white balance, split toning and film tone mapping
// @about The grading steps a colorist works through, in their usual order.
// @about Exposure scales light in stops (each stop doubles it). White balance
// @about shifts warm/cool and green/magenta. Contrast pivots around middle
// @about gray. Vibrance boosts muted colors more than saturated ones. Split
// @about toning tints the shadows and highlights separately. A tone curve
// @about (ACES or Reinhard) rolls bright values off gently instead of clipping.

#include "lib/color.glsl"

uniform float exposure;    // default=0 min=-3 max=3 step=0.05 tip="In photographic stops"
uniform float warmth;      // default=0 min=-1 max=1 label=temperature tip="Cool ↔ warm"
uniform float tint;        // default=0 min=-1 max=1 tip="Green ↔ magenta"
uniform float contrast;    // default=1 min=0.5 max=2
uniform float saturation;  // default=1 min=0 max=2
uniform float vibrance;    // default=0 min=-1 max=1 tip="Saturation that spares already-vivid colors"
uniform vec3  shadows;     // color default=#808080 tip="Shadow tint (gray = none)"
uniform vec3  highlights;  // color default=#808080 tip="Highlight tint (gray = none)"
uniform float fade;        // default=0 min=0 max=0.3 tip="Lift the blacks, like faded film"
uniform int   tonemap;     // enum=None,ACES,Reinhard default=None

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    c *= exp2(exposure);
    c = temperature(c, warmth);
    c *= vec3(1.0 + 0.05 * tint, 1.0 - 0.08 * tint, 1.0 + 0.05 * tint);

    if (tonemap == 1) c = acesFilm(c);
    else if (tonemap == 2) c = c / (1.0 + c);

    c = (c - 0.5) * contrast + 0.5;
    float l = luma(c);
    c = mix(vec3(l), c, saturation);
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    c = mix(vec3(l), c, 1.0 + vibrance * (1.0 - sat));

    // split toning: offsets from neutral gray, weighted by luminance
    float lc = clamp(l, 0.0, 1.0);
    c += (shadows - 0.5) * 0.6 * (1.0 - smoothstep(0.0, 0.55, lc));
    c += (highlights - 0.5) * 0.6 * smoothstep(0.45, 1.0, lc);

    c = mix(vec3(fade), vec3(1.0), clamp(c, 0.0, 10.0));
    return vec4(c, 1.0) * color;
}
