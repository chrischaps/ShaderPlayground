// Noise toolkit: hashes, value/gradient noise, fbm, voronoi, curl.
// Hashes are sine-free (after Dave Hoskins) so they stay stable on all GPUs.

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Gradient noise in roughly -1..1
float gradientNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 ga = hash22(i) * 2.0 - 1.0;
    vec2 gb = hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 gc = hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
    vec2 gd = hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
    float va = dot(ga, f);
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    return 1.4 * mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}

// Fractal Brownian motion: octaves of gradient noise, each rotated to hide grid artifacts.
float fbm(vec2 p, int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        sum += amp * gradientNoise(p);
        p = rot * p * 2.02 + vec2(17.1, 9.2);
        amp *= 0.5;
    }
    return sum;
}

// Voronoi: x = distance to nearest feature, y = distance to the cell border,
// zw = id of the nearest cell.
vec4 voronoi(vec2 p, float jitter, float t) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    vec2 mg, mr;
    float md = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g);
        o = 0.5 + 0.5 * sin(t + TAU * o) * jitter;
        vec2 r = g + o - f;
        float d = dot(r, r);
        if (d < md) { md = d; mr = r; mg = g; }
    }
    float border = 8.0;
    for (int j = -2; j <= 2; j++)
    for (int i = -2; i <= 2; i++) {
        vec2 g = mg + vec2(float(i), float(j));
        vec2 o = hash22(n + g);
        o = 0.5 + 0.5 * sin(t + TAU * o) * jitter;
        vec2 r = g + o - f;
        if (dot(mr - r, mr - r) > 0.00001)
            border = min(border, dot(0.5 * (mr + r), normalize(r - mr)));
    }
    return vec4(sqrt(md), border, n + mg);
}

// Divergence-free flow field from the curl of a noise potential.
vec2 curlNoise(vec2 p) {
    const float e = 0.01;
    float n1 = gradientNoise(p + vec2(0.0, e));
    float n2 = gradientNoise(p - vec2(0.0, e));
    float n3 = gradientNoise(p + vec2(e, 0.0));
    float n4 = gradientNoise(p - vec2(e, 0.0));
    return vec2(n1 - n2, -(n3 - n4)) / (2.0 * e);
}
