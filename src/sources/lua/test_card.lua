--[[
    Lua source: Test Card - color bars, ramps, fine lines and a grid.
    The broadcast-engineer's way to see exactly what an effect does.
]]

local lg = love.graphics

local font

local BARS = {
    { 0.75, 0.75, 0.75 }, { 0.75, 0.75, 0 }, { 0, 0.75, 0.75 }, { 0, 0.75, 0 },
    { 0.75, 0, 0.75 }, { 0.75, 0, 0 }, { 0, 0, 0.75 },
}

local function ramp(x, y, w, h, c1, c2)
    local m = lg.newMesh({
        { x, y, 0, 0, c1[1], c1[2], c1[3], 1 },
        { x + w, y, 1, 0, c2[1], c2[2], c2[3], 1 },
        { x + w, y + h, 1, 1, c2[1], c2[2], c2[3], 1 },
        { x, y + h, 0, 1, c1[1], c1[2], c1[3], 1 },
    }, "fan", "static")
    lg.setColor(1, 1, 1, 1)
    lg.draw(m)
    m:release()
end

return {
    name = "Test Card",
    category = "Scenes",
    desc = "Color bars, gradients, fine lines and a grid",
    about = "Test cards let engineers judge a signal at a glance. Bars show color handling, ramps show banding and tone curves, and the converging lines show aliasing and blur. Run any effect over this card to see exactly what it does.",
    params = {
        { name = "grid", type = "bool", default = true },
        { name = "motion", type = "float", default = 0.3, min = 0, max = 2, tip = "Speed of the moving bar" },
    },
    draw = function(s, w, h, t, v)
        if not font then font = lg.newFont(28) end
        lg.clear(0.08, 0.08, 0.08, 1)

        -- Color bars (top 55%)
        local barH = h * 0.55
        local bw = w / #BARS
        for i, c in ipairs(BARS) do
            lg.setColor(c[1], c[2], c[3], 1)
            lg.rectangle("fill", (i - 1) * bw, 0, math.ceil(bw), barH)
        end

        -- Gray and hue ramps
        local y = barH
        local rh = h * 0.08
        ramp(0, y, w, rh, { 0, 0, 0 }, { 1, 1, 1 })
        y = y + rh
        local segs = 6
        for i = 0, segs - 1 do
            local function hue(k)
                local hh = (k % 1) * 6
                local r = math.max(0, math.min(1, math.abs(hh - 3) - 1))
                local g = math.max(0, math.min(1, 2 - math.abs(hh - 2)))
                local b = math.max(0, math.min(1, 2 - math.abs(hh - 4)))
                return { r, g, b }
            end
            ramp(i * w / segs, y, w / segs + 1, rh, hue(i / segs), hue((i + 1) / segs))
        end
        y = y + rh

        -- Fine lines: frequency sweep
        local fy = y
        local fh = h - fy
        lg.setColor(0, 0, 0, 1)
        lg.rectangle("fill", 0, fy, w, fh)
        lg.setColor(1, 1, 1, 1)
        local x = 0
        local width = 8
        while x < w * 0.5 do
            lg.rectangle("fill", math.floor(x), fy, math.max(1, math.floor(width / 2)), fh)
            x = x + width
            width = math.max(2, width * 0.94)
        end
        -- Converging lines
        local cx, cy = w * 0.75, fy + fh / 2
        lg.setLineWidth(1)
        for i = 0, 47 do
            local a = i / 48 * math.pi * 2
            lg.line(cx, cy, cx + math.cos(a) * fh * 0.48, cy + math.sin(a) * fh * 0.48)
        end

        -- Skin tone and pure white/black patches
        lg.setColor(0.86, 0.66, 0.53, 1)
        lg.rectangle("fill", w * 0.52, fy + fh * 0.15, w * 0.06, fh * 0.7)
        lg.setColor(1, 1, 1, 1)
        lg.rectangle("fill", w * 0.6, fy + fh * 0.15, w * 0.04, fh * 0.7)

        -- Grid
        if v.grid then
            lg.setColor(1, 1, 1, 0.25)
            local step = math.floor(math.min(w, h) / 12)
            for gx = step, w, step do lg.line(gx + 0.5, 0, gx + 0.5, h) end
            for gy = step, h, step do lg.line(0, gy + 0.5, w, gy + 0.5) end
        end

        -- Center circle + moving bar
        lg.setColor(1, 1, 1, 0.9)
        lg.setLineWidth(3)
        lg.circle("line", w / 2, h / 2, math.min(w, h) * 0.3, 128)
        local mx = (t * v.motion * w * 0.25) % w
        lg.setColor(1, 1, 1, 1)
        lg.rectangle("fill", mx, h * 0.47, w * 0.01, h * 0.06)

        lg.setFont(font)
        local label = "SHADER PLAYGROUND"
        local tw = font:getWidth(label)
        lg.setColor(0, 0, 0, 0.7)
        lg.rectangle("fill", w / 2 - tw / 2 - 16, h * 0.22 - 8, tw + 32, font:getHeight() + 16, 6)
        lg.setColor(1, 1, 1, 1)
        lg.print(label, math.floor(w / 2 - tw / 2), math.floor(h * 0.22))
        lg.setLineWidth(1)
    end,
}
