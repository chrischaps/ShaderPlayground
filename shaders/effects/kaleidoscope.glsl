// @name Kaleidoscope
// @category Distort
// @desc Mirror the image into rotating wedges
// @about Each pixel is converted to polar coordinates (angle and distance).
// @about The angle is folded into one wedge, flipping every other wedge as a
// @about mirror would, then turned back into a position to sample. Mirrored
// @about texture wrapping fills the edges with seamless reflections.

uniform float segments; // default=6 min=2 max=24 step=1
uniform float rotation; // angle default=0
uniform float spin;     // default=0.1 min=-2 max=2 tip="Rotation speed (radians/sec)"
uniform float zoom;     // default=1 min=0.2 max=4 log
uniform vec2  center;   // xy default=0.5,0.5

vec2 mirrorUV(vec2 u) { return 1.0 - abs(1.0 - mod(u, 2.0)); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv - center;
    p.x *= iResolution.z;
    float r = length(p) * zoom;
    float a = atan(p.y, p.x) + rotation + iTime * spin;
    float seg = TAU / segments;
    a = mod(a, seg);
    a = abs(a - seg * 0.5); // mirror inside each wedge
    vec2 q = vec2(cos(a), sin(a)) * r;
    q.x /= iResolution.z;
    return Texel(tex, mirrorUV(q + center)) * color;
}
