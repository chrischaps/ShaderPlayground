-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/bloom", params = { intensity = 0.4, threshold = 0.6 } },
        { enabled = true, id = "effects/vignette", params = { intensity = 0.55 } },
    },
    desc = "Ink folding on a slow current. Drag to stir.",
    gallery = true,
    name = "Marbling",
    order = 10,
    source = { id = "sources/ink_flow", params = { emit = 1.6, emitters = 5, fade = 0.04, flow = 0.24 } },
    version = 1,
}
