-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/color_grade", params = { contrast = 1.2, exposure = 0.8 } },
        { enabled = true, id = "effects/halftone", params = { size = 7 } },
    },
    desc = "Aurora seen from orbit, run through a four-color press.",
    gallery = true,
    name = "Press Proof",
    order = 12,
    source = { id = "lua/image", params = { drift = 0.3, image = 2 } },
    version = 1,
}
