// @name Feedback Trails
// @category Time
// @desc Echoes that zoom, spin and shift hue: video feedback
// @about Point a camera at its own monitor and you get infinite tunnels. This
// @about does the same digitally: every frame, the previous output (iFeedback)
// @about is scaled, rotated and hue-shifted a little, then combined with the
// @about new image. Small changes compound frame after frame into spirals.

#include "lib/color.glsl"
#include "lib/sdf.glsl"

uniform float persistence; // default=0.9 min=0 max=0.995 step=0.001 tip="How long echoes last"
uniform float zoom;        // default=1.012 min=0.95 max=1.08 step=0.001 tip=">1 tunnels inward, <1 explodes outward"
uniform float spin;        // default=0.006 min=-0.05 max=0.05 step=0.0005 tip="Rotation per frame (radians)"
uniform float hueShift;    // default=0.008 min=0 max=0.05 step=0.0005
uniform vec2  center;      // xy default=0.5,0.5
uniform int   blend;       // enum=Lighten,Add,Mix default=Lighten

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    if (iTimeDelta <= 0.0) return Texel(iFeedback, uv); // paused: hold
    vec2 asp = vec2(iResolution.z, 1.0);
    vec2 p = (uv - center) * asp;
    p = rot2(spin) * p / zoom;
    vec2 puv = p / asp + center;
    vec3 prev = Texel(iFeedback, puv).rgb * persistence;
    if (puv.x < 0.0 || puv.x > 1.0 || puv.y < 0.0 || puv.y > 1.0) prev = vec3(0.0);
    if (hueShift > 0.0) {
        vec3 h = rgb2hsv(max(prev, 0.0));
        h.x = fract(h.x + hueShift);
        prev = hsv2rgb(h);
    }
    vec3 cur = Texel(tex, uv).rgb;
    vec3 outc;
    if (blend == 0) outc = max(cur, prev);
    else if (blend == 1) outc = min(cur + prev * 0.6, vec3(4.0));
    else outc = mix(cur, prev, persistence);
    return vec4(outc, 1.0) * color;
}
