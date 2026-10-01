--[[
    Frosted-glass backdrop: a heavily blurred, low-res copy of the output
    that the UI panels draw behind their tint, so the art glows through.
    Downsample in halves (to avoid shimmer), then a separable blur.
]]

local lg = love.graphics

local Backdrop = {}

local shader
local canvases = {}
local srcW, srcH
local frame = 0

local BLUR = [[
uniform vec2 dir;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * 0.2270270270;
    c += Texel(tex, uv + dir * 1.3846153846) * 0.3162162162;
    c += Texel(tex, uv - dir * 1.3846153846) * 0.3162162162;
    c += Texel(tex, uv + dir * 3.2307692308) * 0.0702702703;
    c += Texel(tex, uv - dir * 3.2307692308) * 0.0702702703;
    return c;
}
]]

function Backdrop.init()
    shader = lg.newShader(BLUR)
end

local function ensure(w, h)
    if srcW == w and srcH == h then return end
    for _, c in pairs(canvases) do c:release() end
    canvases = {}
    srcW, srcH = w, h
    local ww, hh = w, h
    for i = 1, 3 do
        ww, hh = math.max(4, math.floor(ww / 2)), math.max(4, math.floor(hh / 2))
        canvases[i] = lg.newCanvas(ww, hh)
    end
    canvases.blurA = lg.newCanvas(ww, hh)
    canvases.blurB = lg.newCanvas(ww, hh)
end

function Backdrop.update(source)
    frame = frame + 1
    local w, h = source:getDimensions()
    ensure(w, h)
    lg.push("all")
    lg.setBlendMode("replace", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    local prev = source
    for i = 1, 3 do
        local c = canvases[i]
        lg.setCanvas(c)
        local pw, ph = prev:getDimensions()
        lg.draw(prev, 0, 0, 0, c:getWidth() / pw, c:getHeight() / ph)
        prev = c
    end
    local bw, bh = canvases.blurA:getDimensions()
    lg.setShader(shader)
    for _ = 1, 2 do
        lg.setCanvas(canvases.blurA)
        shader:send("dir", { 1.6 / bw, 0 })
        lg.draw(prev)
        lg.setCanvas(canvases.blurB)
        shader:send("dir", { 0, 1.6 / bh })
        lg.draw(canvases.blurA)
        prev = canvases.blurB
    end
    lg.pop()
end

function Backdrop.image()
    return canvases.blurB
end

return Backdrop
