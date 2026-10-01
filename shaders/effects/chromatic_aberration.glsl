// @name Chromatic Aberration
// @category Lens
// @desc Spectral color fringing, radial like a cheap lens or directional
// @about Real lenses bend each wavelength by a slightly different amount, so
// @about colors land in slightly different places. Instead of a hard RGB split
// @about this samples the image several times along the offset and weights each
// @about sample by a rainbow, which gives soft, natural-looking fringes.

uniform int   mode;     // enum=Radial,Directional default=Radial
uniform float strength; // default=0.008 min=0 max=0.05 step=0.0005 tip="Distance between the red and blue images"
uniform float angle;    // angle default=0 tip="Direction (directional mode)"
uniform vec2  center;   // xy default=0.5,0.5 tip="Lens center (radial mode)"
uniform float falloff;  // default=1.5 min=0.5 max=4 tip="How quickly fringing grows toward the edges"
uniform int   samples;  // default=9 min=3 max=24 tip="More samples = smoother rainbow"

vec3 spectrum(float t) {
    // Smooth red -> green -> blue weighting that sums to roughly white.
    vec3 w = vec3(
        smoothstep(0.55, 0.0, t) + smoothstep(0.85, 1.0, t) * 0.2,
        1.0 - abs(t - 0.5) * 2.0,
        smoothstep(0.45, 1.0, t)
    );
    return max(w, 0.0);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 dir;
    if (mode == 0) {
        vec2 d = uv - center;
        d.x *= iResolution.z;
        float r = length(d);
        dir = (r > 0.0 ? d / r : vec2(0.0)) * pow(r * 1.4, falloff) * strength * 2.0;
        dir.x /= iResolution.z;
    } else {
        dir = vec2(cos(angle), sin(angle)) * strength;
    }

    vec3 sum = vec3(0.0);
    vec3 wsum = vec3(0.0);
    for (int i = 0; i < 24; i++) {
        if (i >= samples) break;
        float t = float(i) / float(samples - 1);
        vec3 w = spectrum(t);
        sum += Texel(tex, uv + dir * (t - 0.5) * 2.0).rgb * w;
        wsum += w;
    }
    return vec4(sum / wsum, 1.0) * color;
}
