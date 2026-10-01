// @name Invert
// @category Color
// @desc Negative image, or flip lightness only
// @about RGB inversion turns the image into a photographic negative, with
// @about complementary hues. Lightness-only inversion converts to HSV, flips
// @about the value and converts back, so a red apple stays red but dark
// @about becomes light.

#include "lib/color.glsl"

uniform float amount; // default=1 min=0 max=1
uniform int   mode;   // enum=RGB,Lightness default=RGB

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    vec3 inv;
    if (mode == 0) {
        inv = 1.0 - c;
    } else {
        vec3 h = rgb2hsv(clamp(c, 0.0, 1.0));
        h.z = 1.0 - h.z;
        inv = hsv2rgb(h);
    }
    return vec4(mix(c, inv, amount), 1.0) * color;
}
