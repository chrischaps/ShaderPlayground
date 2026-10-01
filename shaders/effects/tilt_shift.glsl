// @name Tilt-Shift
// @category Lens
// @desc A narrow band of focus that makes the world look miniature
// @about Our eyes read strong blur above and below a sharp band as a very
// @about shallow depth of field, which only happens when photographing tiny
// @about things up close. Blur radius grows with distance from the focus
// @about band and is applied as two separable Gaussian passes. A small boost
// @about to saturation and contrast completes the toy-model look.

#include "lib/blur.glsl"

uniform float focus;      // default=0.55 min=0 max=1 tip="Vertical position of the sharp band"
uniform float band;       // default=0.1 min=0 max=0.5 tip="Height of the sharp band"
uniform float blurAmount; // default=3 min=0 max=8 label=blur
uniform float saturation; // default=1.3 min=0 max=2
uniform float contrast;   // default=1.08 min=0.5 max=1.5

float amount(vec2 uv) { return smoothstep(band, band + 0.3, abs(uv.y - focus)); }

//@pass h in=input
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(iTexel.x * blurAmount * amount(uv), 0.0));
}

//@pass v in=h
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return blur13(tex, uv, vec2(0.0, iTexel.y * blurAmount * amount(uv)));
}

//@pass grade in=v
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    c = mix(vec3(luma(c)), c, saturation);
    c = (c - 0.5) * contrast + 0.5;
    return vec4(c, 1.0) * color;
}
