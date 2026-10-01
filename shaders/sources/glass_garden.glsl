// @name Glass Garden
// @category Raymarched
// @desc Iridescent blobs merging above a mirror floor (drag to orbit)
// @about A raymarcher: for every pixel a ray steps forward by the distance to
// @about the nearest surface, which a signed distance function (SDF) reports.
// @about The blobs are spheres joined with a smooth minimum so they flow into
// @about each other. Lighting adds soft shadows, ambient occlusion, a
// @about Fresnel rim and a thin-film rainbow, like a soap bubble. The floor
// @about marches a second, reflected ray.
// @scale 0.75

#include "lib/sdf.glsl"

uniform float speed;       // default=0.5 min=0 max=2
uniform int   count;       // default=5 min=1 max=8 tip="Number of blobs"
uniform float blend;       // default=0.45 min=0.05 max=1 tip="How readily blobs merge"
uniform float iridescence; // default=1 min=0 max=2 tip="Thin-film rainbow strength"
uniform vec3  tint;        // color default=#c9d2ff
uniform vec3  skyTop;      // color default=#231a3d
uniform vec3  skyBottom;   // color default=#05040b
uniform float orbit;       // default=0.12 min=-1 max=1 tip="Automatic camera orbit speed"
uniform bool  ring;        // default=true
uniform int   steps;       // default=110 min=32 max=256 tip="March steps (quality vs speed)"

float sceneObj(vec3 p) {
    float t = iTime * speed;
    float d = 1e9;
    for (int i = 0; i < 8; i++) {
        if (i >= count) break;
        float fi = float(i);
        vec3 c = vec3(sin(t * 0.7 + fi * 1.7) * 1.15,
                      1.05 + sin(t * 0.9 + fi * 2.3) * 0.45,
                      cos(t * 0.6 + fi * 1.1) * 1.15);
        float r = 0.34 + 0.14 * sin(fi * 3.1 + 0.5);
        d = smin(d, sdSphere(p - c, r), blend);
    }
    if (ring) {
        vec3 q = p - vec3(0.0, 1.05, 0.0);
        q.xz = rot2(t * 0.3) * q.xz;
        q.yz = rot2(0.5 + 0.2 * sin(t * 0.4)) * q.yz;
        d = smin(d, sdTorus(q, vec2(1.55, 0.05)), blend * 0.4);
    }
    return d;
}

float scene(vec3 p, out float mat) {
    float o = sceneObj(p);
    float f = p.y;
    mat = o < f ? 1.0 : 0.0;
    return min(o, f);
}

float sceneD(vec3 p) { float m; return scene(p, m); }

vec3 normalAt(vec3 p) {
    const vec2 k = vec2(1.0, -1.0);
    const float e = 0.0015;
    return normalize(k.xyy * sceneD(p + k.xyy * e) + k.yyx * sceneD(p + k.yyx * e) +
                     k.yxy * sceneD(p + k.yxy * e) + k.xxx * sceneD(p + k.xxx * e));
}

float march(vec3 ro, vec3 rd, int maxSteps, out float mat) {
    float t = 0.0;
    mat = -1.0;
    for (int i = 0; i < 256; i++) {
        if (i >= maxSteps) break;
        float m;
        float d = scene(ro + rd * t, m);
        if (d < 0.0008 * t) { mat = m; return t; }
        t += d;
        if (t > 40.0) break;
    }
    return -1.0;
}

float softShadow(vec3 ro, vec3 rd) {
    float res = 1.0;
    float t = 0.02;
    for (int i = 0; i < 48; i++) {
        float h = sceneObj(ro + rd * t);
        res = min(res, 10.0 * h / t);
        t += clamp(h, 0.02, 0.3);
        if (res < 0.002 || t > 8.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

float ao(vec3 p, vec3 n) {
    float occ = 0.0, sca = 1.0;
    for (int i = 1; i <= 5; i++) {
        float h = 0.03 * float(i);
        occ += (h - sceneD(p + n * h)) * sca;
        sca *= 0.8;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

vec3 skyCol(vec3 rd) {
    vec3 c = mix(skyBottom, skyTop, smoothstep(-0.1, 0.8, rd.y));
    vec3 L = normalize(vec3(0.5, 0.6, -0.6));
    c += vec3(1.0, 0.85, 0.7) * pow(max(dot(rd, L), 0.0), 24.0) * 0.6;
    return c;
}

vec3 shadeObj(vec3 p, vec3 rd, vec3 n, bool cheap) {
    vec3 L = normalize(vec3(0.5, 0.6, -0.6));
    float ndl = max(dot(n, L), 0.0);
    float sh = cheap ? 1.0 : softShadow(p + n * 0.01, L);
    float occ = cheap ? 1.0 : ao(p, n);
    float ndv = clamp(dot(n, -rd), 0.0, 1.0);
    float fres = pow(1.0 - ndv, 4.0);
    vec3 h = normalize(L - rd);
    float spec = pow(max(dot(n, h), 0.0), 90.0) * sh;
    vec3 film = 0.5 + 0.5 * cos(TAU * (ndv * 1.6 + vec3(0.0, 0.33, 0.67) + iTime * speed * 0.05));
    vec3 refl = skyCol(reflect(rd, n));
    vec3 col = tint * (0.08 + 0.55 * ndl * sh) * occ;
    col += refl * (0.12 + 0.88 * fres) * occ;
    col += film * iridescence * (0.15 + 0.6 * fres) * occ;
    col += spec * vec3(1.0, 0.95, 0.9) * 1.5;
    return col;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = centered(uv);
    p.y = -p.y;

    float a = iTime * orbit + (iMouse.x - 0.5) * TAU;
    float elev = mix(0.25, 2.6, 1.0 - iMouse.y);
    vec3 ro = vec3(cos(a) * 5.6, elev, sin(a) * 5.6);
    vec3 ta = vec3(0.0, 0.95, 0.0);
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(p.x * uu + p.y * vv + 1.5 * ww);

    float mat;
    float t = march(ro, rd, steps, mat);
    vec3 col = skyCol(rd);
    if (t > 0.0) {
        vec3 pos = ro + rd * t;
        if (mat > 0.5) {
            col = shadeObj(pos, rd, normalAt(pos), false);
        } else {
            // Mirror floor with a faint grid, fading into the distance
            vec3 n = vec3(0.0, 1.0, 0.0);
            vec3 r = reflect(rd, n);
            float m2;
            float t2 = march(pos + n * 0.01, r, steps / 2, m2);
            vec3 rc = t2 > 0.0 && m2 > 0.5 ? shadeObj(pos + r * t2, r, normalAt(pos + r * t2), true) : skyCol(r);
            vec2 g = abs(fract(pos.xz) - 0.5);
            float grid = smoothstep(0.48, 0.5, max(g.x, g.y)) * 0.08;
            float sh = softShadow(pos + n * 0.01, normalize(vec3(0.5, 0.6, -0.6)));
            float fres = 0.25 + 0.75 * pow(1.0 - max(-rd.y, 0.0), 5.0);
            col = skyBottom * 0.6 * (0.4 + 0.6 * sh) + rc * fres * 0.7 + grid * tint;
            col = mix(col, skyCol(rd), smoothstep(8.0, 30.0, t));
        }
    }
    return vec4(col, 1.0);
}
