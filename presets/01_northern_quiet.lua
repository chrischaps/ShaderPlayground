-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/bloom", params = { halo = 0.8, intensity = 0.7, threshold = 0.35 } },
        { enabled = true, id = "effects/film_grain", params = { intensity = 0.06 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.6, radius = 0.75 } },
    },
    desc = "Aurora over a ridge, softly glowing. A calm place to start.",
    gallery = true,
    name = "Northern Quiet",
    order = 1,
    source = { id = "sources/aurora", params = {} },
    version = 1,
}
