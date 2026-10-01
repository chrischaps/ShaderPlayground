--[[
    Lua source: Geometry - rotating translucent squares and rings.
    Hard edges and flat colors: good for testing pixelate, edges and dither.
]]

local lg = love.graphics

local function hsv(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v else return v, p, q end
end

return {
    name = "Geometry",
    category = "Scenes",
    desc = "Rotating squares and rings in flat color",
    about = "Hard edges and flat fills show exactly how an effect treats boundaries, which makes this scene ideal for pixelate, edge detection, dithering and posterize.",
    params = {
        { name = "count", type = "int", default = 8, min = 1, max = 24 },
        { name = "speed", type = "float", default = 0.5, min = -2, max = 2 },
        { name = "rings", type = "bool", default = true },
        { name = "hue", type = "float", default = 0, min = 0, max = 1 },
        { name = "background", type = "vec3", hint = "color", default = { 0.12, 0.16, 0.28 } },
    },
    draw = function(s, w, h, t, v)
        local bg = v.background
        lg.clear(bg[1], bg[2], bg[3], 1)
        local scale = math.min(w, h) / 720
        lg.push()
        lg.translate(w / 2, h / 2)
        lg.scale(scale)
        if v.rings then
            lg.setLineWidth(6)
            for i = 1, 6 do
                local r, g, b = hsv(v.hue + 0.5 + i * 0.04, 0.4, 0.95)
                lg.setColor(r, g, b, 0.5)
                lg.circle("line", 0, 0, 120 + i * 70 + math.sin(t * 1.3 + i) * 12, 96)
            end
        end
        for i = 1, v.count do
            lg.push()
            lg.rotate(t * v.speed + i * math.pi / v.count)
            local size = 80 + i * (260 / v.count)
            local r, g, b = hsv(v.hue + i / v.count, 0.7, 0.85)
            lg.setColor(r, g, b, 0.55)
            lg.rectangle("fill", -size / 2, -size / 2, size, size)
            lg.pop()
        end
        lg.pop()
        lg.setColor(1, 1, 1, 1)
    end,
}
