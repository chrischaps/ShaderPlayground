-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/color_grade", params = { fade = 0.06, saturation = 1.1, warmth = 0.5 } },
        { enabled = true, id = "effects/vhs", params = { bleed = 0.9, wobble = 0.7 } },
        { enabled = true, id = "effects/chromatic_aberration", params = { strength = 0.006 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.5 } },
    },
    desc = "A sunrise someone taped off the TV one summer.",
    gallery = true,
    name = "VHS Summer",
    order = 8,
    source = { id = "lua/image", params = { drift = 0.5, image = 0 } },
    version = 1,
}
