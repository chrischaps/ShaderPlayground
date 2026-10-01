-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/god_rays", params = { intensity = 0.8, light = { 0.5, 0.5 }, reach = 0.6, sun = 0, threshold = 0.3 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.85, radius = 0.6 } },
    },
    desc = "A Julia set morphing slowly, its filaments catching the light.",
    gallery = true,
    name = "Deep Field",
    order = 5,
    source = { id = "sources/fractal_drift", params = { palette = 3, speed = 0.25 } },
    version = 1,
}
