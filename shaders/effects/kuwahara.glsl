// @name Kuwahara
// @category Paint
// @desc Oil-paint smoothing that keeps edges crisp
// @about For every pixel, look at four overlapping square neighborhoods
// @about (up-left, up-right, down-left, down-right) and take the color of the
// @about calmest one, the one with the least variance. Flat regions smooth into
// @about brush-like patches, while edges survive because some neighborhood
// @about always lies on just one side of them. Sharpness blends the four
// @about softly instead of choosing just one.

uniform int   radius;    // default=5 min=2 max=10 tip="Brush size in pixels (cost grows with the square)"
uniform float sharpness; // default=8 min=1 max=18 tip="How strongly the calmest region wins"
uniform float saturation; // default=1.1 min=0 max=2

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 m[4];
    vec3 s[4];
    float n[4];
    for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); n[k] = 0.0; }

    for (int j = -10; j <= 10; j++) {
        if (j < -radius || j > radius) continue;
        for (int i = -10; i <= 10; i++) {
            if (i < -radius || i > radius) continue;
            vec3 c = Texel(tex, uv + vec2(float(i), float(j)) * iTexel).rgb;
            vec3 c2 = c * c;
            if (i <= 0 && j <= 0) { m[0] += c; s[0] += c2; n[0] += 1.0; }
            if (i >= 0 && j <= 0) { m[1] += c; s[1] += c2; n[1] += 1.0; }
            if (i <= 0 && j >= 0) { m[2] += c; s[2] += c2; n[2] += 1.0; }
            if (i >= 0 && j >= 0) { m[3] += c; s[3] += c2; n[3] += 1.0; }
        }
    }

    vec3 result = vec3(0.0);
    float wsum = 0.0;
    for (int k = 0; k < 4; k++) {
        vec3 mean = m[k] / n[k];
        vec3 var = abs(s[k] / n[k] - mean * mean);
        float sigma = var.r + var.g + var.b;
        float w = 1.0 / (1.0 + pow(sigma * 1000.0, sharpness * 0.5));
        result += mean * w;
        wsum += w;
    }
    result /= wsum;
    result = mix(vec3(luma(result)), result, saturation);
    return vec4(result, 1.0) * color;
}
