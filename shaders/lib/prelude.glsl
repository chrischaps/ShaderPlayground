// Shader Playground prelude: included automatically before every pass.
//
// Coordinates: `uv` (the effect() texture coords) runs 0..1 with the origin
// at the TOP-LEFT, the way LÖVE draws. `screen_coords` is in output pixels.
//
// Auto uniforms (do not redeclare these in your shader):
uniform float iTime;        // seconds since start (fixed-step while recording)
uniform float iTimeDelta;   // seconds since last frame
uniform int   iFrame;       // frames since this node (re)started; 0 = first frame
uniform vec3  iResolution;  // this pass's output size in pixels; z = width/height
uniform vec2  iTexel;       // 1.0 / size of this pass's input texture
uniform vec4  iMouse;       // xy: mouse in uv space; z: 1 while held; w: 1 on click frame
uniform Image iSource;      // the source image, before any effects
uniform Image iInput;       // this node's input (the previous node's output)
uniform Image iFeedback;    // this node's own output from the previous frame
uniform Image iPrev;        // this pass's previous frame (persist passes)

#define PI  3.14159265359
#define TAU 6.28318530718

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Aspect-corrected coordinates centered on the screen: y in -0.5..0.5
vec2 centered(vec2 uv) {
    vec2 p = uv - 0.5;
    p.x *= iResolution.z;
    return p;
}
