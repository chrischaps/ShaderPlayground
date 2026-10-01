-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/pixelate", params = { pixelSize = 4 } },
        { enabled = true, id = "effects/bloom", params = { intensity = 0.6, threshold = 0.5 } },
        { enabled = true, id = "effects/crt", params = { curvature = 0.18, lineCount = 200, persistence = 0.6 } },
    },
    desc = "Flat-color geometry on a curved, glowing tube.",
    gallery = true,
    name = "Arcade Cabinet",
    order = 4,
    source = { id = "lua/geometry", params = { count = 10 } },
    version = 1,
}
