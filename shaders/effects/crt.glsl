// @name CRT
// @category Retro
// @desc Curved glass, scanlines, phosphor mask and afterglow
// @about A picture tube draws the image as horizontal scanlines of glowing
// @about phosphor dots behind curved glass. This bends the image with a barrel
// @about warp, darkens the gaps between lines, multiplies by a red/green/blue
// @about mask, and keeps a fading copy of the last frame (iFeedback) so bright
// @about things leave a short afterglow.

uniform float curvature;   // default=0.12 min=0 max=0.5 tip="Barrel distortion of the glass"
uniform float scanlines;   // default=0.45 min=0 max=1 tip="Darkness between scanlines"
uniform float lineCount;   // default=240 min=60 max=720 step=1 tip="Number of scanlines"
uniform int   mask;        // enum=None,Aperture,Shadow default=Aperture tip="Phosphor layout"
uniform float maskStrength; // default=0.35 min=0 max=1
uniform float glow;        // default=0.35 min=0 max=1 tip="Light bleeding between neighbors"
uniform float persistence; // default=0.55 min=0 max=0.95 tip="Afterglow from the previous frame"
uniform float flicker;     // default=0.03 min=0 max=0.2
uniform float corner;      // default=0.04 min=0 max=0.2 tip="Rounded corner radius"

// Barrel warp (after Timothy Lottes): bulge each axis by the square of the other.
vec2 warp(vec2 uv) {
    vec2 c = uv * 2.0 - 1.0;
    vec2 k = vec2(curvature * 0.25, curvature * 0.35);
    c *= vec2(1.0 + c.y * c.y * k.x, 1.0 + c.x * c.x * k.y);
    return c * 0.5 + 0.5;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 w = warp(uv);

    // Rounded-rect screen edge
    vec2 q = abs(w - 0.5) * 2.0;
    vec2 cq = max(q - (1.0 - corner * 2.0), 0.0);
    float edge = length(cq) - corner * 2.0;
    float inside = 1.0 - smoothstep(-0.004, 0.004, max(edge, max(q.x, q.y) - 1.0));

    vec3 c = Texel(tex, w).rgb;
    // Horizontal glow from neighbours
    vec2 dx = vec2(iTexel.x * 1.5, 0.0);
    vec3 n = Texel(tex, w + dx).rgb + Texel(tex, w - dx).rgb
           + Texel(tex, w + dx * 2.5).rgb * 0.5 + Texel(tex, w - dx * 2.5).rgb * 0.5;
    c += n * glow * 0.2;

    // Scanlines: brighter pixels bloom across the gap
    float line = sin(w.y * lineCount * PI) * 0.5 + 0.5;
    float bright = luma(c);
    float s = mix(1.0, pow(line, 1.5), scanlines * (1.0 - bright * 0.5));
    c *= s * (1.0 + scanlines * 0.35);

    // Phosphor mask in output pixel space
    if (mask == 1) {
        int m = int(mod(sc.x, 3.0));
        vec3 mk = m == 0 ? vec3(1.0, 0.25, 0.25) : m == 1 ? vec3(0.25, 1.0, 0.25) : vec3(0.25, 0.25, 1.0);
        c *= mix(vec3(1.0), mk * 1.6, maskStrength);
    } else if (mask == 2) {
        float row = mod(floor(sc.y / 2.0), 2.0);
        int m = int(mod(sc.x + row * 1.5, 3.0));
        vec3 mk = m == 0 ? vec3(1.0, 0.3, 0.3) : m == 1 ? vec3(0.3, 1.0, 0.3) : vec3(0.3, 0.3, 1.0);
        c *= mix(vec3(1.0), mk * 1.5, maskStrength);
    }

    c *= 1.0 - flicker * (0.5 + 0.5 * sin(iTime * 110.0));
    c *= inside;

    // Phosphor afterglow
    vec3 prev = Texel(iFeedback, uv).rgb;
    c = max(c, prev * persistence);

    return vec4(c, 1.0) * color;
}
