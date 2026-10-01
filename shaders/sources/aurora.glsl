// @name Aurora
// @category Generative
// @desc Northern lights folding over a quiet ridge
// @about Aurora are tall, thin sheets of light hanging in the sky. Here a ray
// @about from a viewer on the ground climbs through stacked altitude layers.
// @about Wherever it crosses one of three wavy curtain paths it picks up
// @about light. Stacking the layers makes the sheets stand vertically and
// @about recede toward the horizon. Noise along each sheet makes the rays.
// @about Green low down shifting to violet higher up mirrors real aurora:
// @about oxygen glows green lower in the sky, nitrogen purple higher up.
// @scale 0.75

#include "lib/noise.glsl"

uniform float speed;     // default=0.35 min=0 max=2 tip="How fast the curtains drift"
uniform float intensity; // default=1.3 min=0 max=3
uniform float folds;     // default=1 min=0 max=2.5 tip="How much the curtains fold"
uniform float tilt;      // default=0.27 min=-0.1 max=0.5 tip="Look up (more sky) or toward the horizon"
uniform int   curtains;  // default=3 min=1 max=3
uniform vec3  lowColor;  // color default=#2dffa8
uniform vec3  highColor; // color default=#8f4dff
uniform vec3  sky;       // color default=#050a1e
uniform float stars;     // default=1 min=0 max=2
uniform bool  ridge;     // default=true tip="Mountain silhouette"

float starField(vec2 px, float t) {
    vec2 cell = floor(px / 3.0);
    float h = hash12(cell);
    if (h < 0.992) return 0.0;
    vec2 off = hash22(cell + 7.0) * 3.0;
    float d = length(px - (cell * 3.0 + off));
    float tw = 0.6 + 0.4 * sin(t * (2.0 + h * 6.0) + h * 80.0);
    return smoothstep(1.4, 0.0, d) * tw * (h - 0.992) * 125.0;
}

// Lateral offset of curtain k's path at position x along it.
float curtainPath(float x, float k, float t) {
    return fbm(vec2(x * 0.06 + t * 0.05 + k * 5.1, k * 3.7), 3) * 7.0 * folds
         + sin(x * 0.11 + k * 2.0 + t * 0.07) * 1.5 * folds;
}

vec3 auroraLight(vec3 rd, float t, vec2 sc) {
    vec3 acc = vec3(0.0);
    if (rd.y <= 0.0) return acc;
    const int LAYERS = 36;
    float jitter = hash12(sc + fract(t) * 37.0) * 0.6;
    for (int i = 0; i < LAYERS; i++) {
        float fi = (float(i) + jitter);
        float h = 1.0 + fi * 0.11;                   // altitude of this layer
        float dist = h / rd.y;
        if (dist > 70.0) break;
        vec2 q = rd.xz * dist;                       // where the ray crosses it
        float k01 = fi / float(LAYERS);
        vec3 c = mix(lowColor, highColor, smoothstep(0.05, 0.75, k01));
        for (int k = 0; k < 3; k++) {
            if (k >= curtains) break;
            float fk = float(k);
            float z0 = 4.5 + fk * 5.0;
            float dz = q.y - (z0 + curtainPath(q.x, fk, t));
            float sheet = exp(-dz * dz * 5.0);
            float rays = 0.5 + 0.5 * gradientNoise(vec2(q.x * 2.4 + fk * 13.0, t * 0.35 + fk));
            rays = rays * rays * 1.8;
            rays *= 0.6 + 0.4 * gradientNoise(vec2(q.x * 11.0, fk * 9.0 - t * 0.25));
            float bright = 0.6 + 0.4 * gradientNoise(vec2(q.x * 0.12 + t * 0.04, fk * 4.0));
            float haze = exp(-dist * 0.035);              // far curtains fade into the haze
            // each curtain's lower hem rises and falls along its length
            float hem = 1.0 + 0.9 * (0.5 + 0.5 * gradientNoise(vec2(q.x * 0.09 + fk * 7.0, t * 0.05)));
            float lower = smoothstep(hem - 0.1, hem + 0.25, h) * (1.0 + 1.5 * exp(-max(h - hem, 0.0) * 2.5));
            acc += c * sheet * max(rays, 0.0) * max(bright, 0.0) * exp(-k01 * 2.6) * haze * lower * (1.0 - fk * 0.2);
        }
    }
    return acc * 0.6;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float t = iTime * speed;
    vec2 p = centered(uv);
    p.y = -p.y;                                   // y up
    vec3 rd = normalize(vec3(p.x, p.y + tilt, 1.0));
    float yUp = 1.0 - uv.y;

    // Sky: a little lift toward the horizon
    vec3 col = mix(sky * 1.8 + vec3(0.01, 0.015, 0.03), sky * 0.45, smoothstep(0.0, 0.8, rd.y + 0.1));
    col += starField(sc, iTime) * stars * vec3(0.8, 0.85, 1.0) * smoothstep(0.0, 0.25, rd.y);

    vec3 aur = auroraLight(rd, t, sc) * intensity;
    col += aur;
    // the aurora lights the haze near the horizon
    col += lowColor * 0.04 * intensity * exp(-max(rd.y, 0.0) * 12.0);

    // Mountains, rim-lit by the aurora
    if (ridge) {
        float x = p.x;
        float ridged = 1.0 - abs(gradientNoise(vec2(x * 2.2 + 3.0, 1.7)));
        float horizon = 0.5 - tilt;               // where rd.y == 0
        float rh = horizon - 0.03 + 0.05 * fbm(vec2(x * 1.1 + 3.0, 1.7), 5) + 0.07 * ridged * ridged
                 + 0.012 * gradientNoise(vec2(x * 9.0, 4.0));
        float px = 1.0 / iResolution.y;
        float m = smoothstep(rh + px, rh - px, yUp);
        float rim = exp(-abs(yUp - rh) * 220.0) * 0.25;
        vec3 ground = mix(vec3(0.004, 0.006, 0.012), lowColor * 0.03, smoothstep(rh - 0.2, rh, yUp));
        col = mix(col, ground, m);
        col += rim * mix(lowColor, highColor, 0.3) * intensity * (1.0 - m * 0.5);
    }

    return vec4(col, 1.0);
}
