--[[
    Lua source: Orbs - soft glowing particles drifting over a slow gradient.
    A good bright-on-dark test scene for bloom, trails and chromatic effects.

    Lua sources return a module:
        name, category, desc, about, params (same annotation fields as GLSL)
        new(w, h, values)               -> state
        update(state, dt, values, w, h, ctx)
        draw(state, w, h, time, values, ctx)
    Hot-reloaded like shaders.
]]

local lg = love.graphics

local glow -- shared radial-falloff sprite

local function makeGlow()
    if glow then return glow end
    local size = 128
    local d = love.image.newImageData(size, size)
    d:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
        local r = math.sqrt(dx * dx + dy * dy)
        local core = math.max(0, 1 - r / 0.42)
        local halo = math.max(0, 1 - r) ^ 3
        local a = math.min(1, core ^ 0.6 + halo * 0.5)
        return 1, 1, 1, a
    end)
    glow = lg.newImage(d)
    glow:setFilter("linear", "linear")
    return glow
end

local function hsv(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v else return v, p, q end
end

local M = {
    name = "Orbs",
    category = "Scenes",
    desc = "Glowing particles drifting over a slow gradient",
    about = "Drawn with ordinary LÖVE calls: each orb is a soft sprite, blended additively so overlaps brighten. Lua sources are a good place to test effects on the kinds of things a game would draw.",
    params = {
        { name = "count", type = "int", default = 60, min = 1, max = 300, tip = "Number of orbs" },
        { name = "speed", type = "float", default = 0.6, min = 0, max = 3 },
        { name = "size", type = "float", default = 1, min = 0.2, max = 3 },
        { name = "hue", type = "float", default = 0.62, min = 0, max = 1, tip = "Base hue of the palette" },
        { name = "spread", type = "float", default = 0.35, min = 0, max = 1, tip = "How far orb hues stray from the base" },
        { name = "background", type = "vec3", hint = "color", default = { 0.03, 0.03, 0.08 } },
    },
}

local function spawn(w, h)
    return {
        x = love.math.random() * w,
        y = love.math.random() * h,
        vx = (love.math.random() - 0.5) * 80,
        vy = (love.math.random() - 0.5) * 80,
        r = 6 + love.math.random() ^ 2 * 34,
        h = love.math.random(),
        phase = love.math.random() * math.pi * 2,
    }
end

function M.new(w, h, values)
    makeGlow()
    local s = { orbs = {}, w = w, h = h }
    for i = 1, 300 do s.orbs[i] = spawn(w, h) end
    return s
end

function M.update(s, dt, v, w, h)
    -- positions are stored in a resolution-independent way by rescaling
    if s.w ~= w or s.h ~= h then
        for _, o in ipairs(s.orbs) do
            o.x, o.y = o.x / s.w * w, o.y / s.h * h
        end
        s.w, s.h = w, h
    end
    local k = v.speed
    for i = 1, v.count do
        local o = s.orbs[i]
        o.x = o.x + o.vx * dt * k
        o.y = o.y + o.vy * dt * k
        o.phase = o.phase + dt * k
        if o.x < -o.r then o.x = w + o.r elseif o.x > w + o.r then o.x = -o.r end
        if o.y < -o.r then o.y = h + o.r elseif o.y > h + o.r then o.y = -o.r end
    end
end

function M.draw(s, w, h, t, v)
    local bg = v.background
    -- vertical gradient background
    local mesh = lg.newMesh({
        { 0, 0, 0, 0, bg[1], bg[2], bg[3] * 1.4 + 0.02, 1 },
        { w, 0, 1, 0, bg[1], bg[2], bg[3] * 1.4 + 0.02, 1 },
        { w, h, 1, 1, bg[1] * 0.4, bg[2] * 0.4, bg[3] * 0.4, 1 },
        { 0, h, 0, 1, bg[1] * 0.4, bg[2] * 0.4, bg[3] * 0.4, 1 },
    }, "fan", "static")
    lg.setColor(1, 1, 1, 1)
    lg.draw(mesh)
    mesh:release()

    local scale = math.min(w, h) / 720
    lg.setBlendMode("add", "alphamultiply")
    for i = 1, v.count do
        local o = s.orbs[i]
        local hue = v.hue + (o.h - 0.5) * v.spread
        local r, g, b = hsv(hue, 0.65, 1)
        local pulse = 0.75 + 0.25 * math.sin(o.phase * 2)
        local rad = o.r * v.size * scale * (0.9 + 0.1 * pulse) * 2
        lg.setColor(r, g, b, 0.55 * pulse + 0.25)
        lg.draw(glow, o.x, o.y, 0, rad / 64, rad / 64, 64, 64)
    end
    lg.setBlendMode("alpha", "alphamultiply")
end

return M
