--[[
    Hover preview for the library: a small live card showing what an entry
    would look like. Effects run over the current source image; sources are
    shown on their own. Try before you add.
]]

local Pipeline = require("src.render.pipeline")
local UI = require("src.ui.core")
local Theme = require("src.ui.theme")

local lg = love.graphics
local C = Theme.colors

local Preview = {}

local W, H = 288, 162
local DELAY = 0.3

local App
local pipeline, built     -- mini pipeline and the entry it was built for
local target, pos         -- entry being hovered, card anchor
local requested = false   -- a row asked for a preview this frame
local hoverT = 0

function Preview.init(app)
    App = app
end

-- Called by the library while a row is hovered.
function Preview.request(entry, x, y)
    if entry ~= target then
        target = entry
        hoverT = 0
    end
    pos = { x, y }
    requested = true
end

local function build(entry)
    if pipeline then pipeline:destroy() end
    pipeline = Pipeline.new({ width = W, height = H, renderScale = 1 })
    if entry.kind == "source" then
        pipeline:setSource(entry)
    else
        pipeline:addEffect(entry)
    end
    built = entry
end

function Preview.draw()
    local dt = UI.dt()
    hoverT = requested and (hoverT + dt) or 0
    local visible = requested and hoverT > DELAY and not App.dragEntry
    requested = false
    local alpha = UI.anim("preview:alpha", visible and 1 or 0, visible and 14 or 30)

    if alpha < 0.02 then
        if not visible and pipeline then
            pipeline:destroy()
            pipeline, built = nil, nil
        end
        return
    end
    if not target or not pos then return end
    if visible and built ~= target then build(target) end

    if pipeline then
        local ctx = { time = App.clock.time, dt = App.clock.dt, mouse = App.mouse }
        if built.kind == "effect" then
            pipeline.inputTex = App.pipeline.sourceTex
        end
        pipeline:update(ctx.dt, ctx)
        pipeline:render(ctx)
    end

    -- Card
    local pad = 8
    local cw, ch = W + pad * 2, H + pad * 2 + 62
    local x = math.floor(pos[1])
    local y = math.floor(math.max(60, math.min(lg.getHeight() - ch - 10, pos[2] - 24)))
    local e = built or target
    lg.push("all")
    UI.shadowRect(x, y, cw, ch, 10)
    lg.setColor(C.popup[1], C.popup[2], C.popup[3], 0.96 * alpha)
    lg.rectangle("fill", x, y, cw, ch, 10)
    lg.setColor(1, 1, 1, 0.08 * alpha)
    lg.setLineWidth(1)
    lg.rectangle("line", x + 0.5, y + 0.5, cw - 1, ch - 1, 10)
    if pipeline then
        lg.stencil(function() lg.rectangle("fill", x + pad, y + pad, W, H, 6) end, "replace", 1)
        lg.setStencilTest("greater", 0)
        lg.setColor(1, 1, 1, alpha)
        lg.draw(pipeline.outputCanvas, x + pad, y + pad)
        lg.setStencilTest()
    end
    local ty = y + pad + H + 8
    lg.setFont(Theme.fonts.medium)
    lg.setColor(C.text[1], C.text[2], C.text[3], alpha)
    lg.print(e.name or e.id, x + pad + 2, ty)
    lg.setFont(Theme.fonts.small)
    lg.setColor(C.textDim[1], C.textDim[2], C.textDim[3], alpha)
    lg.print(UI.fit(Theme.fonts.small, e.desc or "", W - 4), x + pad + 2, ty + 20)
    lg.setColor(C.textFaint[1], C.textFaint[2], C.textFaint[3], alpha)
    local hint = e.kind == "source" and "Click to use as the source" or "Click to add · drag into the chain"
    if e.errors then hint = "⚠ has a compile error" end
    lg.print(hint, x + pad + 2, ty + 38)
    lg.pop()
end

return Preview
