-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/god_rays", params = { intensity = 1.1, light = { 0.5, 0.05 }, reach = 0.9, sun = 0.6, threshold = 0.55 } },
        { enabled = true, id = "effects/film_grain", params = { intensity = 0.07 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.8 } },
    },
    desc = "Light falling through colored glass in a quiet chapel.",
    gallery = true,
    name = "Stained Light",
    order = 9,
    source = { id = "sources/stained_glass", params = {} },
    version = 1,
}
