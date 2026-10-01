// @name Monochrome
// @category Color
// @desc Grayscale with a tint, like a toned photographic print
// @about Converts to luminance using the Rec. 709 weights, because our eyes
// @about are most sensitive to green and least to blue. Shadows and highlights
// @about can then be tinted separately, the way sepia or cyanotype prints were.

uniform float amount;     // default=1 min=0 max=1
uniform vec3  shadows;    // color default=#2a1d14 tip="Color of the dark tones"
uniform vec3  highlights; // color default=#ffe9c4 tip="Color of the light tones"
uniform float contrast;   // default=1.1 min=0.5 max=2

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    float g = clamp((luma(c) - 0.5) * contrast + 0.5, 0.0, 1.0);
    vec3 toned = mix(shadows, highlights, g);
    return vec4(mix(c, toned, amount), 1.0) * color;
}
