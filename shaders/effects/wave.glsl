// @name Wave
// @category Distort
// @desc Rolling sine-wave displacement
// @about Each pixel looks up the image a little to the side of where it is.
// @about The offset is a sine of the other axis plus time, so rows and columns
// @about sway like a flag. Mirrored sampling keeps the edges from smearing.

uniform float amplitude; // default=0.02 min=0 max=0.1 step=0.001 tip="How far pixels are pushed"
uniform float frequency; // default=10 min=1 max=50 step=0.5 tip="Waves across the screen"
uniform float speed;     // default=2 min=0 max=10 step=0.1
uniform float twist;     // default=0.5 min=0 max=1 tip="Strength of the vertical wave relative to horizontal"

vec2 mirrorUV(vec2 u) { return 1.0 - abs(1.0 - mod(u, 2.0)); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 offset;
    offset.x = sin(uv.y * frequency + iTime * speed) * amplitude;
    offset.y = cos(uv.x * frequency * 0.8 + iTime * speed * 0.7) * amplitude * twist;
    return Texel(tex, mirrorUV(uv + offset)) * color;
}
