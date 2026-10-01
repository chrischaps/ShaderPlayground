// Separable Gaussian blur helpers.
// blur9 takes 5 bilinear taps that cover 9 texels (weights from a 9-tap kernel).
// `dir` is the step between texels, e.g. vec2(iTexel.x * radius, 0.0).

vec4 blur9(Image tex, vec2 uv, vec2 dir) {
    vec4 c = Texel(tex, uv) * 0.2270270270;
    c += Texel(tex, uv + dir * 1.3846153846) * 0.3162162162;
    c += Texel(tex, uv - dir * 1.3846153846) * 0.3162162162;
    c += Texel(tex, uv + dir * 3.2307692308) * 0.0702702703;
    c += Texel(tex, uv - dir * 3.2307692308) * 0.0702702703;
    return c;
}

// 13-tap (7 fetches) for wider, smoother kernels.
vec4 blur13(Image tex, vec2 uv, vec2 dir) {
    vec4 c = Texel(tex, uv) * 0.1964825501511404;
    c += Texel(tex, uv + dir * 1.411764705882353) * 0.2969069646728344;
    c += Texel(tex, uv - dir * 1.411764705882353) * 0.2969069646728344;
    c += Texel(tex, uv + dir * 3.2941176470588234) * 0.09447039785044732;
    c += Texel(tex, uv - dir * 3.2941176470588234) * 0.09447039785044732;
    c += Texel(tex, uv + dir * 5.176470588235294) * 0.010381362401148057;
    c += Texel(tex, uv - dir * 5.176470588235294) * 0.010381362401148057;
    return c;
}
