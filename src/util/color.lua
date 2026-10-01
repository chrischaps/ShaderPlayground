--[[
    Color helpers: HSV <-> RGB, hex parsing/formatting, easing.
]]

local Color = {}

function Color.hsvToRgb(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

function Color.rgbToHsv(r, g, b)
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local d = max - min
    local h = 0
    if d > 0 then
        if max == r then h = ((g - b) / d) % 6
        elseif max == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    local s = max > 0 and d / max or 0
    return h, s, max
end

function Color.toHex(r, g, b)
    local function c(x) return math.floor(math.max(0, math.min(1, x)) * 255 + 0.5) end
    return string.format("#%02x%02x%02x", c(r), c(g), c(b))
end

function Color.fromHex(s)
    s = s:gsub("^#", "")
    if #s == 3 then
        s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
    end
    if not s:match("^%x%x%x%x%x%x%x?%x?$") then return nil end
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    local a = #s == 8 and tonumber(s:sub(7, 8), 16) / 255 or nil
    return r, g, b, a
end

function Color.lerp(a, b, t)
    return a + (b - a) * t
end

-- Frame-rate independent exponential approach (for UI animation).
function Color.approach(current, target, rate, dt)
    return target + (current - target) * math.exp(-rate * dt)
end

function Color.with(c, alpha)
    return { c[1], c[2], c[3], alpha }
end

return Color
