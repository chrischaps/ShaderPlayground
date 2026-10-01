// @name Motion Smear
// @category Time
// @desc Long-exposure ghosting of anything that moves
// @about A running average over time: each frame mixes in a little of the
// @about new image and keeps the rest from the last output (iFeedback). Still
// @about things look unchanged and moving things leave soft ghosts. The mix is
// @about scaled by frame time, so the look is the same at any frame rate.

uniform float amount; // default=0.85 min=0 max=0.99 step=0.005 tip="How much of the past to keep"

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 prev = Texel(iFeedback, uv).rgb;
    if (iFrame == 0) prev = Texel(tex, uv).rgb;
    float keep = pow(amount, iTimeDelta * 60.0);
    vec3 c = mix(Texel(tex, uv).rgb, prev, keep);
    return vec4(c, 1.0) * color;
}
