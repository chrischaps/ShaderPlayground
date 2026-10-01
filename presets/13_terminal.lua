-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/color_grade", params = { exposure = 1.2, contrast = 1.3 } },
        { enabled = true, id = "effects/ascii", params = { cellSize = 8, colorMode = 1, contrast = 2 } },
        { enabled = true, id = "effects/bloom", params = { intensity = 0.7, threshold = 0.4 } },
        { enabled = true, id = "effects/crt", params = { curvature = 0.1, mask = 0 } },
    },
    desc = "The glass garden as a green-screen terminal would draw it.",
    gallery = true,
    name = "Terminal",
    order = 13,
    source = { id = "sources/glass_garden", params = {} },
    version = 1,
}
