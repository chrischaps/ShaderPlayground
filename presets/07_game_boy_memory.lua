-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/dither", params = { contrast = 1.25, palette = 0, pixelSize = 4 } },
    },
    desc = "Earthset from Orion, as a four-shade handheld would have shown it.",
    gallery = true,
    name = "Game Boy Memory",
    order = 7,
    source = { id = "lua/image", params = { drift = 0.4, image = 1 } },
    version = 1,
}
