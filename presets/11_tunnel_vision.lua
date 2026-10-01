-- Shader Playground preset
return {
    chain = {
        { enabled = true, id = "effects/feedback_trails", params = { hueShift = 0.012, persistence = 0.93, spin = 0.008, zoom = 1.015 } },
        { enabled = true, id = "effects/bloom", params = { intensity = 0.8, threshold = 0.5 } },
    },
    desc = "Video feedback: drifting lights folding into a spiral.",
    gallery = true,
    name = "Tunnel Vision",
    order = 11,
    source = { id = "lua/orbs", params = { count = 40, size = 0.8, spread = 0.9 } },
    version = 1,
}
