--[[
    Lua source: Image - a bundled or dropped image, with a slow Ken Burns
    drift so stills feel alive under time-based effects.
]]

local Images = require("src.images")
local lg = love.graphics

return {
    name = "Image",
    category = "Images",
    desc = "A photo or any image you drop on the window",
    about = "Drop any PNG or JPG onto the window to use it here. The slow pan and zoom (the 'Ken Burns' effect, named after the documentary maker) gives still images motion, so time-based effects have something to work with.",
    params = {
        { name = "image", type = "int", options = Images.names, default = 0 },
        { name = "fit", type = "int", options = { "Cover", "Contain" }, default = 0 },
        { name = "drift", type = "float", default = 0.25, min = 0, max = 1, tip = "Slow pan and zoom" },
        { name = "zoom", type = "float", default = 1, min = 0.5, max = 3 },
    },
    draw = function(s, w, h, t, v)
        lg.clear(0.03, 0.03, 0.04, 1)
        local img = Images.get(v.image)
        if not img then
            lg.setColor(0.6, 0.6, 0.7, 1)
            local msg = "Drop an image onto the window"
            local f = lg.getFont()
            lg.print(msg, math.floor(w / 2 - f:getWidth(msg) / 2), math.floor(h / 2))
            return
        end
        local iw, ih = img:getDimensions()
        local scale = v.fit == 0 and math.max(w / iw, h / ih) or math.min(w / iw, h / ih)
        local d = v.drift
        local z = v.zoom * (1 + d * 0.08 * (1 + math.sin(t * 0.11)))
        local px = math.sin(t * 0.07) * d * 0.04 * w
        local py = math.cos(t * 0.05) * d * 0.03 * h
        lg.setColor(1, 1, 1, 1)
        lg.draw(img, w / 2 + px, h / 2 + py, 0, scale * z, scale * z, iw / 2, ih / 2)
    end,
}
