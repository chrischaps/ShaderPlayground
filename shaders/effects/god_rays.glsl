// @name God Rays
// @category Light
// @desc Light streaming from a point through the bright parts of the image
// @about Volumetric light scattering as a screen-space trick. Bright pixels
// @about are extracted at half resolution, then each pixel marches toward the
// @about light, summing what it passes with a decaying weight. Bright areas
// @about between a pixel and the light streak outward as shafts. A random
// @about start offset per pixel hides the banding from the finite steps.

#include "lib/noise.glsl"

uniform vec2  light;       // xy default=0.5,0.2 tip="Light position"
uniform bool  followMouse; // default=false tip="Use the last point dragged on the image"
uniform float threshold;   // default=0.5 min=0 max=1.5 tip="Brightness that casts rays"
uniform float sun;         // default=0.4 min=0 max=2 tip="Glow injected at the light itself"
uniform float reach;       // default=0.8 min=0.1 max=1 tip="How far the rays stretch"
uniform float decay;       // default=0.97 min=0.9 max=0.999 step=0.001
uniform float intensity;   // default=1 min=0 max=4
uniform vec3  tint;        // color default=#ffeccc

vec2 lightPos() { return followMouse ? iMouse.xy : light; }

//@pass bright in=input scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    float w = smoothstep(threshold, threshold + 0.3, luma(c));
    vec2 d = (uv - lightPos()) * vec2(iResolution.z, 1.0);
    float disk = exp(-dot(d, d) * 400.0) * sun;
    return vec4(c * w + disk * tint, 1.0);
}

//@pass scatter in=bright scale=0.5
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    const int N = 80;
    vec2 delta = (uv - lightPos()) * reach / float(N);
    vec2 p = uv - delta * hash12(sc + fract(iTime) * 61.0);
    float illum = 1.0;
    vec3 sum = vec3(0.0);
    for (int i = 0; i < N; i++) {
        p -= delta;
        sum += Texel(tex, p).rgb * illum;
        illum *= decay;
    }
    return vec4(sum / float(N) * 3.0, 1.0);
}

//@pass composite in=input
uniform Image scatter;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    vec3 r = Texel(scatter, uv).rgb * tint * intensity;
    return vec4(c + r, 1.0) * color;
}
