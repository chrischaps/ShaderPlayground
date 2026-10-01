--[[
    Gallery (attract) mode: cycles curated presets full-screen with slow
    crossfades and a quiet caption. Any key or click returns to the editor.
    Uses its own pair of pipelines so the editing session is untouched.
]]

local Pipeline = require("src.render.pipeline")
local Presets = require("src.presets")
local Registry = require("src.shaderlib.registry")
local Clock = require("src.clock")
local Theme = require("src.ui.theme")

local lg = love.graphics

local Gallery = { active = false }

local App
local HOLD = 18      -- seconds per piece
local FADE = 3       -- crossfade seconds

local list, index
local current, nextP
local timer, fade
local clockA, clockB

function Gallery.init(app)
    App = app
end

local function newPipeline(info)
    local p = Pipeline.new({ width = lg.getWidth(), height = lg.getHeight(), renderScale = App.pipeline.renderScale })
    local preset = Presets.read(info)
    if preset then Presets.apply(p, preset, Registry) end
    p.info = info
    p.preset = preset
    return p
end

function Gallery.start()
    list = {}
    for _, info in ipairs(Presets.list()) do
        if info.gallery then list[#list + 1] = info end
    end
    if #list == 0 then
        App.toast("No gallery presets (set gallery = true in a preset)", "warn")
        return
    end
    index = 1
    current = newPipeline(list[index])
    clockA = Clock.new()
    timer, fade = 0, nil
    Gallery.active = true
    Gallery.captionT = 0
    love.mouse.setVisible(false)
end

function Gallery.stop()
    Gallery.active = false
    love.mouse.setVisible(true)
    if current then current:destroy() end
    if nextP then nextP:destroy() end
    current, nextP = nil, nil
end

function Gallery.update(dt)
    timer = timer + dt
    Gallery.captionT = Gallery.captionT + dt
    clockA:update(dt)
    local W, H = lg.getDimensions()
    current:setOutputSize(W, H)
    local ctxA = { time = clockA.time, dt = clockA.dt, mouse = { 0.5, 0.5, 0, 0 } }
    current:update(clockA.dt, ctxA)

    if not nextP and timer > HOLD and #list > 1 then
        index = index % #list + 1
        nextP = newPipeline(list[index])
        clockB = Clock.new()
        fade = 0
    end
    if nextP then
        clockB:update(dt)
        nextP:setOutputSize(W, H)
        nextP:update(clockB.dt, { time = clockB.time, dt = clockB.dt, mouse = { 0.5, 0.5, 0, 0 } })
        fade = fade + dt / FADE
        if fade >= 1 then
            current:destroy()
            current, clockA = nextP, clockB
            nextP, fade = nil, nil
            timer = 0
            Gallery.captionT = 0
        end
    end
end

local function caption(p, alpha)
    if not p.preset or alpha <= 0 then return end
    local name = p.preset.name or ""
    local desc = p.preset.desc or ""
    local x, y = 48, lg.getHeight() - 110
    lg.setColor(0, 0, 0, 0.35 * alpha)
    lg.setFont(Theme.fonts.big)
    lg.print(name, x + 1, y + 2)
    lg.setColor(1, 1, 1, 0.92 * alpha)
    lg.print(name, x, y)
    lg.setFont(Theme.fonts.caption)
    lg.setColor(1, 1, 1, 0.6 * alpha)
    lg.print(desc, x, y + 42)
    -- the chain, as a quiet breadcrumb
    local parts = {}
    if p.source then parts[#parts + 1] = p.source.entry.name end
    for _, n in ipairs(p.chain) do
        if n.enabled then parts[#parts + 1] = n.entry.name end
    end
    lg.setFont(Theme.fonts.small)
    lg.setColor(1, 1, 1, 0.38 * alpha)
    lg.print(table.concat(parts, "  →  "), x, y + 70)
end

function Gallery.draw()
    local W, H = lg.getDimensions()
    lg.clear(0, 0, 0, 1)
    current:render({ time = clockA.time, dt = clockA.dt, mouse = { 0.5, 0.5, 0, 0 } })
    current:draw(0, 0, W, H)
    if nextP then
        nextP:render({ time = clockB.time, dt = clockB.dt, mouse = { 0.5, 0.5, 0, 0 } })
        local t = fade * fade * (3 - 2 * fade)
        lg.push("all")
        lg.setColor(1, 1, 1, t)
        lg.setBlendMode("alpha", "alphamultiply")
        local ow, oh = nextP.outputCanvas:getDimensions()
        lg.draw(nextP.outputCanvas, 0, 0, 0, W / ow, H / oh)
        lg.pop()
    end
    -- Caption fades in after a beat, out before the next piece.
    local c = Gallery.captionT
    local a = math.min(1, math.max(0, (c - 1.5) / 1.5)) * math.min(1, math.max(0, (HOLD - 1 - c) / 2))
    caption(current, a)
end

return Gallery
