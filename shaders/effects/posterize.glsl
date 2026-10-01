// @name Posterize
// @category Color
// @desc Reduce each channel to a few flat levels
// @about Each color channel is snapped to the nearest of N levels. This is
// @about done in a gamma-adjusted space, because our eyes see brightness
// @about non-linearly; evenly spaced steps there look evenly spaced.

uniform float levels; // default=6 min=2 max=32 step=1
uniform float gamma;  // default=0.8 min=0.3 max=2 tip="Spacing of the levels (lower = more dark levels)"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = clamp(Texel(tex, uv).rgb, 0.0, 1.0);
    c = pow(c, vec3(gamma));
    c = floor(c * levels + 0.5) / levels;
    c = pow(c, vec3(1.0 / gamma));
    return vec4(c, 1.0) * color;
}
