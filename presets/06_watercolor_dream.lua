-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/kuwahara", params = { radius = 6, sharpness = 9 } },
        { enabled = true, id = "effects/paper", params = { edges = 0.8, wash = 0.12 } },
    },
    desc = "A Florida sunrise, repainted in soft pigment on rough paper.",
    gallery = true,
    name = "Watercolor Dream",
    order = 6,
    source = { id = "lua/image", params = { drift = 0.3, image = 0 } },
    version = 1,
}
