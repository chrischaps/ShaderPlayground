// @name Heat Haze
// @category Lens
// @desc Shimmering air rising from below; hold the mouse for ripples
// @about Hot air bends light, so the image behind it wobbles. Two layers of
// @about noise scrolling upward give a small offset to every pixel, strongest
// @about near the bottom where the heat is. Holding the mouse on the image
// @about sends out rings of displacement, like a pebble dropped in water.

#include "lib/noise.glsl"

uniform float strength; // default=0.006 min=0 max=0.03 step=0.0005
uniform float scale;    // default=7 min=1 max=30
uniform float speed;    // default=1.2 min=0 max=5
uniform float rise;     // default=0.8 min=0 max=1 tip="Concentrate the heat near the bottom"
uniform bool  ripples;  // default=true tip="Hold the mouse on the image to make ripples"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 asp = vec2(iResolution.z, 1.0);
    vec2 p = uv * asp * scale;
    float t = iTime * speed;
    vec2 n = vec2(gradientNoise(p + vec2(0.0, t)), gradientNoise(p * 1.37 + vec2(5.2, t * 1.21)));
    float mask = mix(1.0, pow(uv.y, 1.5) * 1.8, rise);
    vec2 offset = n * strength * mask;

    if (ripples && iMouse.z > 0.5) {
        vec2 d = (uv - iMouse.xy) * asp;
        float r = length(d);
        float wave = sin(r * 90.0 - iTime * 14.0) * exp(-r * 7.0);
        offset += (r > 0.0 ? d / r : vec2(0.0)) / asp * wave * 0.012;
    }
    return Texel(tex, uv + offset) * color;
}
