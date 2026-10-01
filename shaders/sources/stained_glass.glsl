// @name Stained Glass
// @category Generative
// @desc Slowly shifting Voronoi panes, lit from behind
// @about A Voronoi diagram splits the plane into cells, one per scattered
// @about point, each owning the space closest to it. The distance to the
// @about nearest cell border gives the lead lines. Every pane takes a color
// @about from its cell id, gets a little texture from noise, and is brighter
// @about where a slow sweep of light passes behind the glass.

#include "lib/noise.glsl"
#include "lib/color.glsl"

uniform float cells;    // default=7 min=2 max=24 tip="Panes across the screen height"
uniform float lead;     // default=0.06 min=0.01 max=0.2 tip="Thickness of the lead lines"
uniform float motion;   // default=0.3 min=0 max=2 tip="How much the panes shift"
uniform int   palette;  // enum=Ember,Rainbow,Lagoon,Dusk,Coral,Neon default=Ember
uniform float texture_; // default=0.5 min=0 max=1 label=texture tip="Glass imperfections"
uniform float sweep;    // default=0.15 min=0 max=1 tip="Speed of the light passing behind"
uniform vec3  leadColor; // color default=#120d0a

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = centered(uv) * cells;
    vec4 v = voronoi(p, 0.85, iTime * motion);
    vec2 id = v.zw;
    float h = hash12(id);

    vec3 glass = namedPalette(h * 0.85 + 0.1, palette);
    glass = mix(glass, glass * glass * 1.6, 0.4);
    // glass texture: ripples and seeds
    float n = fbm(p * 3.0 + id * 1.7, 4);
    glass *= 1.0 + (n * 0.35) * texture_;
    // brighter toward each pane's center, like thicker glass in the middle
    glass *= 0.75 + 0.5 * smoothstep(0.0, 0.5, v.y);

    // a slow beam of light sweeping across
    float a = iTime * sweep;
    vec2 dir = vec2(cos(a), sin(a * 0.7));
    float beam = 0.55 + 0.45 * sin(dot(centered(uv), dir) * 3.0 - iTime * sweep * 2.0);
    glass *= 0.35 + 1.0 * beam;

    // lead lines with a soft highlight along their edge
    float edge = smoothstep(lead, lead + 0.02, v.y);
    float hl = smoothstep(lead + 0.05, lead, v.y) * edge;
    vec3 col = mix(leadColor, glass, edge);
    col += hl * glass * 0.4;
    return vec4(col, 1.0);
}
