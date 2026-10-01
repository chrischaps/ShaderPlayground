--[[
    Overlay: toasts, the compare divider, drag ghost and hints.
]]

local UI = require("src.ui.core")
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local FS = require("src.util.fs")

local lg = love.graphics
local C = Theme.colors

local Overlay = {}
local App
local toasts = {}
local hiddenHintT = 0

local KIND_COLOR = {
    ok = C.ok, info = C.accent, warn = C.warn, error = C.error, record = C.record,
}

function Overlay.init(app)
    App = app
end

function Overlay.toast(text, kind, path)
    kind = kind or "info"
    -- collapse repeats
    for _, t in ipairs(toasts) do
        if t.text == text then
            t.age = 0
            t.count = (t.count or 1) + 1
            return
        end
    end
    table.insert(toasts, 1, { text = text, kind = kind, path = path, age = 0, life = kind == "error" and 8 or 3.5 })
    while #toasts > 5 do table.remove(toasts) end
end

function Overlay.drawCompare()
    if not App.compare then return end
    local v = App.view
    local x = v.x + v.w * App.compareSplit
    local r = UI.interact("compare:divider", x - 8, v.y, 16, v.h)
    if r.held then
        App.compareSplit = math.max(0.02, math.min(0.98, (UI.state.mx - v.x) / v.w))
    end
    if r.hot or r.held then UI.setCursor("sizewe") end
    UI.registerRect(x - 8, v.y, 16, v.h)
    lg.setColor(1, 1, 1, 0.85)
    lg.rectangle("fill", x - 0.5, v.y, 1, v.h)
    local cy = v.y + v.h / 2
    lg.setColor(0, 0, 0, 0.45)
    lg.circle("fill", x, cy, 15, 32)
    lg.setColor(1, 1, 1, 0.9)
    lg.setLineWidth(1.5)
    lg.circle("line", x, cy, 15, 32)
    lg.line(x - 4, cy - 4, x - 8, cy, x - 4, cy + 4)
    lg.line(x + 4, cy - 4, x + 8, cy, x + 4, cy + 4)
    -- labels
    local f = Theme.fonts.heading
    local labelY = v.y + v.h - 90
    lg.setFont(f)
    lg.setColor(0, 0, 0, 0.4)
    lg.rectangle("fill", x - 74, labelY - 4, 62, 20, 4)
    lg.rectangle("fill", x + 12, labelY - 4, 62, 20, 4)
    lg.setColor(1, 1, 1, 0.85)
    lg.printf("SOURCE", x - 74, labelY, 62, "center")
    lg.printf("OUTPUT", x + 12, labelY, 62, "center")
end

function Overlay.draw()
    local dt = UI.dt()
    local sw, sh = lg.getDimensions()

    -- Drag ghost for library → chain
    if App.dragEntry then
        local mx, my = UI.mouse()
        local f = Theme.fonts.medium
        local text = "+ " .. (App.dragEntry.name or "")
        local w = f:getWidth(text) + 20
        UI.rect(C.popup, mx + 12, my + 6, w, 28, 6)
        lg.setColor(C.accent)
        lg.setLineWidth(1)
        lg.rectangle("line", mx + 12.5, my + 6.5, w - 1, 27, 6)
        UI.textMid(text, mx + 22, my + 6, 28, f, C.text)
        if not UI.mouseDown(1) then App.dragEntry = nil end
    end

    -- Toasts (bottom center)
    local y = sh - 24
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        t.age = t.age + dt
        if t.age > t.life then table.remove(toasts, i) end
    end
    for i, t in ipairs(toasts) do
        local a = math.min(1, t.age * 6) * math.min(1, (t.life - t.age) * 2)
        local f = Theme.fonts.body
        local text = t.text .. (t.count and t.count > 1 and ("  ×" .. t.count) or "")
        local maxW = math.min(720, sw - 80)
        text = UI.fit(f, text, maxW - 50)
        local w = f:getWidth(text) + 44
        local h = 34
        local slide = (1 - math.min(1, t.age * 6)) * 12
        y = y - h - 8
        local x = math.floor(sw / 2 - w / 2)
        local ty = y + slide
        local id = "toast:" .. i
        local r = UI.interact(id, x, ty, w, h)
        UI.registerRect(x, ty, w, h)
        if r.hot then t.age = math.min(t.age, t.life - 1) end
        if r.clicked and t.path then FS.openInOS(t.path) end
        if r.hot and t.path then UI.setCursor("hand") end
        lg.setColor(C.popup[1], C.popup[2], C.popup[3], 0.94 * a)
        lg.rectangle("fill", x, ty, w, h, 8)
        local kc = KIND_COLOR[t.kind] or C.accent
        lg.setColor(kc[1], kc[2], kc[3], a)
        lg.circle("fill", x + 18, ty + h / 2, 4, 14)
        lg.setColor(1, 1, 1, 0.06 * a)
        lg.setLineWidth(1)
        lg.rectangle("line", x + 0.5, ty + 0.5, w - 1, h - 1, 8)
        lg.setFont(f)
        lg.setColor(C.text[1], C.text[2], C.text[3], a)
        lg.print(text, x + 32, math.floor(ty + (h - f:getHeight()) / 2))
        if t.path then UI.tooltip(id, "Click to open") end
    end

    -- Hint when the UI is hidden
    if not App.uiVisible then
        hiddenHintT = hiddenHintT + dt
        local a = math.max(0, 1 - math.max(0, hiddenHintT - 1.5))
        if a > 0 then
            local f = Theme.fonts.small
            local text = "Tab shows the interface"
            local w = f:getWidth(text) + 24
            lg.setColor(0, 0, 0, 0.4 * a)
            lg.rectangle("fill", sw / 2 - w / 2, 20, w, 26, 13)
            lg.setFont(f)
            lg.setColor(1, 1, 1, 0.8 * a)
            lg.printf(text, sw / 2 - w / 2, 26, w, "center")
        end
    else
        hiddenHintT = 0
    end
end

return Overlay
