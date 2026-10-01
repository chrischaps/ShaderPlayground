--[[
    Parameter model shared by GLSL shaders and Lua sources.

    A param *def* describes a knob:
        name, label, tip, type (glsl type), kind, default, min, max, step,
        log, options (enum labels), hidden

    kind is what the UI renders:
        float, int, bool, enum, color, xy, vec, angle

    Values live on nodes, keyed by param name:
        number (float/int/enum/angle), boolean (bool), {x,y[,z,w]} (xy/vec/color)

    Params.get() is the single read path for "the value right now" so that
    modulation (LFOs, audio) can hook in later without touching callers.
]]

local Params = {}

local VEC_SIZE = { vec2 = 2, vec3 = 3, vec4 = 4 }
Params.VEC_SIZE = VEC_SIZE

local function copy(v)
    if type(v) == "table" then
        local t = {}
        for i = 1, #v do t[i] = v[i] end
        return t
    end
    return v
end
Params.copy = copy

local function clampNum(x, lo, hi)
    if lo and x < lo then x = lo end
    if hi and x > hi then x = hi end
    return x
end

-- "paperColor" / "line_count" -> "Paper color" / "Line count"
function Params.humanize(name)
    local s = name:gsub("_+$", ""):gsub("_", " ")
    s = s:gsub("(%l)(%u)", function(a, b) return a .. " " .. b:lower() end)
    return (s:gsub("^%l", string.upper))
end

-- Turn whatever the parser / a Lua source declared into a complete def.
-- `raw` fields: name, type, hint, default, min, max, step, label, tip, options
function Params.normalize(raw)
    local def = {
        name = raw.name,
        label = raw.label and Params.humanize(raw.label) or Params.humanize(raw.name),
        tip = raw.tip,
        type = raw.type or "float",
        hidden = raw.hidden or raw.hint == "hidden",
    }
    local hint = raw.hint
    local t = def.type

    if t == "bool" then
        def.kind = "bool"
        def.default = raw.default == true or raw.default == 1
    elseif t == "int" then
        if raw.options then
            def.kind = "enum"
            def.options = raw.options
            def.min, def.max = 0, #raw.options - 1
            local d = raw.default
            if type(d) == "string" then
                for i, o in ipairs(raw.options) do
                    if o == d then d = i - 1 end
                end
            end
            def.default = type(d) == "number" and d or 0
            def.step = 1
        else
            def.kind = "int"
            def.min = raw.min or 0
            def.max = raw.max or 10
            def.step = raw.step or 1
            def.default = raw.default or def.min
        end
    elseif t == "float" then
        def.kind = hint == "angle" and "angle" or "float"
        if hint == "angle" then
            def.min = raw.min or 0
            def.max = raw.max or (math.pi * 2)
        else
            def.min = raw.min or 0
            def.max = raw.max or 1
        end
        def.log = hint == "log"
        def.default = type(raw.default) == "number" and raw.default or def.min
        def.step = raw.step or (def.max - def.min) / 100
    elseif VEC_SIZE[t] then
        local n = VEC_SIZE[t]
        local isColor = hint == "color" or (raw.isHex and n >= 3)
        if isColor then
            def.kind = "color"
            def.min, def.max = 0, 1
        elseif n == 2 and (hint == "xy" or hint == nil) then
            def.kind = "xy"
            def.min = raw.min or 0
            def.max = raw.max or 1
        else
            def.kind = "vec"
            def.min = raw.min or 0
            def.max = raw.max or 1
        end
        local d = {}
        local src = type(raw.default) == "table" and raw.default or nil
        for i = 1, n do
            if src and src[i] then
                d[i] = src[i]
            elseif isColor then
                d[i] = 1
            elseif type(raw.default) == "number" then
                d[i] = raw.default
            else
                d[i] = def.kind == "xy" and (def.min + def.max) * 0.5 or def.min
            end
        end
        def.default = d
        def.step = raw.step or (def.max - def.min) / 100
        def.size = n
    else
        def.kind = "unsupported"
        def.hidden = true
    end
    return def
end

function Params.defaultValue(def)
    return copy(def.default)
end

function Params.clamp(def, v)
    local k = def.kind
    if k == "bool" then
        return v == true
    elseif k == "enum" then
        if type(v) ~= "number" then return def.default end
        -- options may grow at runtime (e.g. dropped images)
        return clampNum(math.floor(v + 0.5), 0, math.max(0, #def.options - 1))
    elseif k == "int" then
        if type(v) ~= "number" then return def.default end
        return clampNum(math.floor(v + 0.5), def.min, def.max)
    elseif k == "float" or k == "angle" then
        if type(v) ~= "number" then return def.default end
        return clampNum(v, def.min, def.max)
    elseif k == "color" or k == "xy" or k == "vec" then
        if type(v) ~= "table" then return copy(def.default) end
        local out = {}
        for i = 1, def.size do
            local x = tonumber(v[i]) or def.default[i]
            out[i] = clampNum(x, def.min, def.max)
        end
        return out
    end
    return v
end

-- Is a stored value compatible with this def (used when a shader reloads)?
function Params.compatible(def, v)
    local k = def.kind
    if k == "bool" then return type(v) == "boolean" end
    if k == "color" or k == "xy" or k == "vec" then
        return type(v) == "table" and #v == def.size
    end
    return type(v) == "number"
end

-- The value used for rendering at time t. Modulation will hook in here.
function Params.get(node, def, t)
    local v = node.values[def.name]
    if v == nil then v = def.default end
    return v
end

-- Nudge a value by `steps` steps (keyboard / wheel). Returns new value.
function Params.nudge(def, v, steps, fine)
    local k = def.kind
    if k == "bool" then
        return not v
    elseif k == "enum" then
        local n = #def.options
        return (math.floor(v + steps) % n)
    elseif k == "int" then
        return Params.clamp(def, v + steps * (def.step or 1))
    elseif k == "float" or k == "angle" then
        local step = def.step or 0.01
        if fine then step = step * 0.1 end
        return Params.clamp(def, v + steps * step)
    elseif k == "color" then
        -- brightness nudge: scale all channels
        local out = copy(v)
        local f = 1 + steps * (fine and 0.01 or 0.05)
        for i = 1, 3 do out[i] = math.max(0, math.min(1, out[i] * f + (steps > 0 and 0.002 or 0))) end
        return out
    elseif k == "xy" or k == "vec" then
        local out = copy(v)
        local step = (def.step or 0.01) * (fine and 0.1 or 1)
        out[1] = math.max(def.min, math.min(def.max, out[1] + steps * step))
        return out
    end
    return v
end

-- Send a value to a compiled shader. `has` is the per-shader uniform cache.
function Params.send(shader, has, def, v)
    if not has(def.name) then return end
    local k = def.kind
    if k == "int" or k == "enum" then
        shader:send(def.name, math.floor(v + 0.5))
    elseif k == "bool" then
        if def.type == "bool" then
            shader:send(def.name, v and true or false)
        else
            shader:send(def.name, v and 1 or 0)
        end
    else
        shader:send(def.name, v)
    end
end

function Params.format(def, v)
    local k = def.kind
    if k == "bool" then return v and "on" or "off" end
    if k == "enum" then return def.options[(v or 0) + 1] or tostring(v) end
    if k == "int" then return tostring(math.floor(v + 0.5)) end
    if k == "angle" then return string.format("%d°", math.floor(math.deg(v) + 0.5)) end
    if k == "float" then
        local range = math.abs((def.max or 1) - (def.min or 0))
        if range >= 100 then return string.format("%.1f", v) end
        if range >= 10 then return string.format("%.2f", v) end
        if range >= 0.1 then return string.format("%.3f", v) end
        return string.format("%.4f", v)
    end
    if k == "color" then
        local c = v
        return string.format("#%02x%02x%02x",
            math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    end
    if type(v) == "table" then
        local parts = {}
        for i = 1, #v do parts[i] = string.format("%.2f", v[i]) end
        return table.concat(parts, ", ")
    end
    return tostring(v)
end

return Params
