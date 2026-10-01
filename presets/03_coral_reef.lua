-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/color_grade", params = { saturation = 1.15, vibrance = 0.2, warmth = 0.2 } },
        { enabled = true, id = "effects/bloom", params = { intensity = 0.5, threshold = 0.7 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.7 } },
    },
    desc = "Gray-Scott chemistry growing like coral. Drag to seed new growth.",
    gallery = true,
    name = "Coral Reef",
    order = 3,
    source = { id = "sources/reaction_diffusion", params = { pattern = 0 } },
    version = 1,
}
