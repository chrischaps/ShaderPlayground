// @name Vignette
// @category Film
// @desc Darkened edges that pull the eye to the center
// @about Old lenses let less light reach the corners of the frame. The
// @about darkening here grows with distance from the center through a
// @about smoothstep, and roundness decides whether that distance follows the
// @about frame's shape or a true circle.

uniform float radius;    // default=0.65 min=0.1 max=1.5 tip="Where darkening begins"
uniform float softness;  // default=0.45 min=0.01 max=1
uniform float intensity; // default=0.8 min=0 max=1
uniform float roundness; // default=0.6 min=0 max=1 tip="0 = follow the frame's aspect, 1 = circular"
uniform vec3  tint;      // color default=#000000 tip="Color of the vignette"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    vec2 d = uv - 0.5;
    d.x *= mix(1.0, iResolution.z, roundness);
    float dist = length(d) * 1.414;
    float v = smoothstep(radius - softness * 0.5, radius + softness * 0.5, dist) * intensity;
    return vec4(mix(c, tint, v), 1.0) * color;
}
