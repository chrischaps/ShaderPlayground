-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/bloom", params = { intensity = 1.1, threshold = 0.7, tint = { 0.85, 0.8, 1 } } },
        { enabled = true, id = "effects/color_grade", params = { contrast = 1.15, exposure = 0.3, highlights = { 0.62, 0.5, 0.42 }, shadows = { 0.36, 0.45, 0.62 }, tonemap = 1 } },
        { enabled = true, id = "effects/chromatic_aberration", params = { strength = 0.004 } },
        { enabled = true, id = "effects/film_grain", params = { intensity = 0.045 } },
    },
    desc = "Raymarched glass under studio light, graded cool and warm.",
    gallery = true,
    name = "Neon Noir",
    order = 2,
    source = { id = "sources/glass_garden", params = { skyTop = { 0.16, 0.08, 0.3 } } },
    version = 1,
}
