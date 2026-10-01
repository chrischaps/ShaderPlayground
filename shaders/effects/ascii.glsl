// @name ASCII
// @category Paint
// @desc The image rebuilt from characters
// @about The screen is cut into cells and each cell's brightness picks a
// @about character, from a sparse '.' up to a dense '#'. There's no font
// @about texture: every glyph is a 5×5 bitmap packed into one integer, and
// @about the shader reads bits out of it (after movAX13h's classic Shadertoy).

uniform float cellSize;  // default=10 min=6 max=32 step=1
uniform int   colorMode; // enum=Source,Green,Amber,Ink default=Source
uniform float contrast;  // default=1.3 min=0.5 max=3
uniform vec3  background; // color default=#07080a

float glyph(int n, vec2 p) {
    // p in -1..1 inside the cell (y down)
    vec2 q = floor(p * vec2(-4.0, 4.0) + 2.5);
    if (q.x < 0.0 || q.x > 4.0 || q.y < 0.0 || q.y > 4.0) return 0.0;
    int a = int(q.x + 5.0 * q.y);
    return float((n >> a) & 1);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 cell = floor(sc / cellSize);
    vec2 cuv = (cell + 0.5) * cellSize / iResolution.xy;
    vec3 c = Texel(tex, cuv).rgb;
    float g = clamp((luma(c) - 0.5) * contrast + 0.5, 0.0, 1.0);

    int n = 0;
    if (g > 0.1) n = 4096;       // .
    if (g > 0.2) n = 65600;      // :
    if (g > 0.3) n = 332772;     // *
    if (g > 0.4) n = 15255086;   // o
    if (g > 0.5) n = 23385164;   // &
    if (g > 0.6) n = 15252014;   // 8
    if (g > 0.7) n = 13199452;   // @
    if (g > 0.8) n = 11512810;   // #

    vec2 p = mod(sc, cellSize) / cellSize * 2.0 - 1.0;
    float on = glyph(n, p * 1.1);

    vec3 ink;
    if (colorMode == 0) ink = c / max(max(c.r, max(c.g, c.b)), 0.15) * 0.95;
    else if (colorMode == 1) ink = vec3(0.3, 1.0, 0.45);
    else if (colorMode == 2) ink = vec3(1.0, 0.7, 0.2);
    else ink = vec3(0.92);
    return vec4(mix(background, ink, on), 1.0) * color;
}
