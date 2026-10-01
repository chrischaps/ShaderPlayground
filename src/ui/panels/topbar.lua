--[[
    Top bar: identity, transport, view controls, capture.
]]

local UI = require("src.ui.core")
local W = require("src.ui.widgets")
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local Capture = require("src.capture")

local lg = love.graphics
local C = Theme.colors
local M = Theme.metrics

local TopBar = {}
local App

function TopBar.init(app)
    App = app
end

local function logo(x, y, s)
    -- Two softly orbiting discs: source and effect, in the two accent colors.
    local t = UI.time()
    local cx, cy = x + s / 2, y + s / 2
    local r = s * 0.24
    local a1, a2 = C.accent, C.accent2
    lg.setBlendMode("add", "alphamultiply")
    lg.setColor(a2[1], a2[2], a2[3], 0.8)
    lg.circle("fill", cx + math.cos(t * 0.8) * r * 0.5, cy + math.sin(t * 0.8) * r * 0.5, r, 32)
    lg.setColor(a1[1], a1[2], a1[3], 0.8)
    lg.circle("fill", cx - math.cos(t * 0.8) * r * 0.5, cy - math.sin(t * 0.8) * r * 0.5, r, 32)
    lg.setBlendMode("alpha", "alphamultiply")
end

local function fpsGraph(x, y, w, h)
    local hist = App.fpsHistory
    local n = #hist
    if n < 2 then return end
    local pts = {}
    for i, dt in ipairs(hist) do
        local ms = math.min(50, dt * 1000)
        pts[#pts + 1] = x + (i - 1) / 89 * w
        pts[#pts + 1] = y + h - (ms / 50) * h
    end
    -- 16.7 ms line
    lg.setColor(1, 1, 1, 0.08)
    local ly = y + h - (16.7 / 50) * h
    lg.line(x, ly, x + w, ly)
    lg.setColor(C.accent[1], C.accent[2], C.accent[3], 0.7)
    lg.setLineWidth(1.2)
    lg.line(pts)
end

local function timeString(t)
    local m = math.floor(t / 60)
    local s = t - m * 60
    return string.format("%02d:%05.2f", m, s)
end

function TopBar.draw()
    local sw = lg.getWidth()
    local x, y = M.margin, M.margin
    local w, h = sw - M.margin * 2, M.topBarH
    UI.panel(x, y, w, h)

    local cy = y + h / 2
    -- Identity
    logo(x + 10, y + 9, 28)
    UI.textMid("Shader Playground", x + 44, y, h, Theme.fonts.title, C.text)
    local titleW = Theme.fonts.title:getWidth("Shader Playground")
    local px = x + 44 + titleW + 18

    -- Responsive layout: drop the FPS graph, then the preset name, when narrow.
    local TRANSPORT_W, RIGHT_W, FPS_W = 262, 380, 120
    local presetW = App.currentPreset and math.min(180, Theme.fonts.small:getWidth(App.currentPreset)) + 12 or 0
    local showFps, showPreset = true, App.currentPreset ~= nil
    local function free()
        return (x + w - RIGHT_W - (showFps and FPS_W or 0)) - (px + (showPreset and presetW or 0))
    end
    if free() < TRANSPORT_W + 24 then showFps = false end
    if free() < TRANSPORT_W + 24 then showPreset = false end
    TopBar.showFps = showFps
    if showPreset then
        UI.textMid(App.currentPreset, px, y, h, Theme.fonts.small, C.textFaint, "left", 180)
    end

    -- Transport: centered when there's room, otherwise in the free space
    local clock = App.clock
    local bs = 30
    local leftEdge = px + (showPreset and presetW or 0) + 12
    local rightEdge = x + w - RIGHT_W - (showFps and FPS_W or 0) - 12
    local tx = math.floor(math.max(leftEdge, math.min(rightEdge - TRANSPORT_W, x + w / 2 - TRANSPORT_W / 2)))
    local by = math.floor(cy - bs / 2)
    if W.iconButton("tb:play", clock.paused and Icons.play or Icons.pause, tx, by, bs,
        { tip = clock.paused and "Play (P)" or "Pause (P)" }) then
        clock:togglePause()
    end
    if W.iconButton("tb:step", Icons.step, tx + bs + 2, by, bs, { tip = "Step one frame (.)" }) then
        clock:step(1)
    end
    if W.iconButton("tb:rewind", Icons.reset, tx + (bs + 2) * 2, by, bs, { tip = "Restart time and simulations" }) then
        clock:reset()
        if App.pipeline.source then App.pipeline.source:restart() end
        for _, n in ipairs(App.pipeline.chain) do n:restart() end
    end
    UI.rect(C.surface, tx + (bs + 2) * 3 + 4, by + 2, 92, bs - 4, 6)
    UI.textMid(timeString(clock.time), tx + (bs + 2) * 3 + 4, by, bs, Theme.fonts.mono,
        clock.paused and C.warn or C.text, "center", 92)
    local speeds = {}
    local speedIndex = 2
    for i, s in ipairs(App.SPEEDS) do
        speeds[i] = s .. "×"
        if s == clock.speed then speedIndex = i - 1 end
    end
    local ni, ch = W.dropdown("tb:speed", speeds, speedIndex, tx + (bs + 2) * 3 + 102, by + 2, 64, bs - 4,
        { font = Theme.fonts.small })
    if ch then clock.speed = App.SPEEDS[ni + 1] end
    UI.tooltip("tb:speed", "Playback speed")

    -- Right side: perf, view, capture
    local rx = x + w - 10
    local function rightIcon(id, icon, tip, opts)
        rx = rx - bs
        opts = opts or {}
        opts.tip = tip
        local clicked = W.iconButton(id, icon, rx, by, bs, opts)
        rx = rx - 2
        return clicked
    end

    if rightIcon("tb:gallery", Icons.gallery, "Gallery mode (G): a slow show of curated presets") then
        require("src.gallery").start()
    end
    local rec = Capture.recording
    if rightIcon("tb:rec", rec and Icons.stop or Icons.record, rec and "Stop recording (F9)" or
        "Record (F9): fixed-step 30 fps, saved as PNGs + GIF/MP4 via ffmpeg",
        { color = C.record, active = rec ~= nil, activeBg = { C.record[1], C.record[2], C.record[3], 0.2 } }) then
        App.toggleRecording()
    end
    if rightIcon("tb:shot", Icons.camera, "Screenshot (F12) · Shift+F12 includes the UI") then
        App.screenshot(false)
    end
    rx = rx - 8
    if rightIcon("tb:bypass", Icons.bypass, "Bypass all effects (Space)", { active = App.pipeline.bypass }) then
        App.pipeline.bypass = not App.pipeline.bypass
    end
    if rightIcon("tb:compare", Icons.compare, "Compare before/after (C): drag the divider", { active = App.compare }) then
        App.compare = not App.compare
    end
    rx = rx - 8

    -- Output size
    local outLabels = {}
    for i, m in ipairs(App.OUTPUT_MODES) do outLabels[i] = m.label end
    rx = rx - 118
    local oi, och = W.dropdown("tb:out", outLabels, App.outputMode - 1, rx, by + 2, 118, bs - 4, { font = Theme.fonts.small })
    if och then App.setOutputMode(oi + 1) end
    UI.tooltip("tb:out", "Output size (what you see and capture)")
    rx = rx - 6

    -- Render scale
    local scaleLabels, si = {}, 0
    for i, s in ipairs(App.SCALES) do
        scaleLabels[i] = math.floor(s * 100) .. "%"
        if math.abs(s - App.pipeline.renderScale) < 0.01 then si = i - 1 end
    end
    rx = rx - 70
    local ns, sch = W.dropdown("tb:scale", scaleLabels, si, rx, by + 2, 70, bs - 4, { font = Theme.fonts.small })
    if sch then App.setRenderScale(App.SCALES[ns + 1]) end
    UI.tooltip("tb:scale", "Render scale: lower is faster for heavy shaders")
    rx = rx - 10

    -- FPS
    local fps = love.timer.getFPS()
    if TopBar.showFps then
        rx = rx - 120
        fpsGraph(rx, by + 4, 60, bs - 8)
        UI.textMid(fps .. " fps", rx + 64, by, bs, Theme.fonts.monoSmall,
            fps >= 55 and C.textDim or (fps >= 30 and C.warn or C.error), "left", 56)
    end
    if rec then
        local t = rec.frame / rec.fps
        lg.setColor(C.record)
        lg.circle("fill", rx - 20, cy, 4 + math.sin(UI.time() * 6) * 1, 16)
        UI.textMid(string.format("%.1fs", t), rx - 76, y, h, Theme.fonts.mono, C.record, "right", 50)
    end
end

return TopBar
