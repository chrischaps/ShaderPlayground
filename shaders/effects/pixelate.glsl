// @name Pixelate
// @category Retro
// @desc Chunky pixels, with optional LED dots or a pixel grid
// @about The screen is divided into blocks, and every pixel in a block copies
// @about the color at the block's center. Sampling the center (not the corner)
// @about keeps the image from creeping as the block size changes. The shape
// @about option masks each block into a square, rounded LED or grid cell.

uniform float pixelSize; // default=8 min=1 max=64 step=1 tip="Block size in output pixels"
uniform int   shape;     // enum=Square,LED,Grid default=Square
uniform float gap;       // default=0.15 min=0 max=0.5 tip="Space between dots / grid lines"
uniform vec3  background; // color default=#0a0a0f tip="Color between dots"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 px = uv * iResolution.xy;
    vec2 cell = floor(px / pixelSize);
    vec2 centerUV = (cell + 0.5) * pixelSize / iResolution.xy;
    vec3 c = Texel(tex, centerUV).rgb;

    vec2 f = fract(px / pixelSize) - 0.5; // -0.5..0.5 inside the block
    float mask = 1.0;
    float aa = 1.0 / max(pixelSize, 1.0);
    if (shape == 1) {
        float r = length(f);
        mask = 1.0 - smoothstep(0.5 - gap - aa, 0.5 - gap + aa, r);
    } else if (shape == 2) {
        vec2 e = smoothstep(0.5 - gap * 0.5 - aa, 0.5 - gap * 0.5 + aa, abs(f));
        mask = 1.0 - max(e.x, e.y);
    }
    if (pixelSize < 3.0) mask = 1.0;
    return vec4(mix(background, c, mask), 1.0) * color;
}
