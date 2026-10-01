--[[
    Left panel: the library (sources + effects by category, searchable) and
    the preset browser.
]]

local UI = require("src.ui.core")
local W = require("src.ui.widgets")
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local Registry = require("src.shaderlib.registry")
local Presets = require("src.presets")
local Preview = require("src.ui.preview")

local lg = love.graphics
local C = Theme.colors
local M = Theme.metrics

local Library = {}
local App
local search = ""
local presetList = nil
local saveName = ""
local wantSaveFocus = false

function Library.init(app)
    App = app
end

function Library.refreshPresets()
    presetList = Presets.list()
end

function Library.promptSave()
    App.leftTab = "presets"
    App.uiVisible = true
    wantSaveFocus = true
end

function Library.rect()
    local sh = lg.getHeight()
    local y = M.margin * 2 + M.topBarH
    return M.margin, y, M.leftW, sh - y - M.margin
end

local function matches(entry, q)
    if q == "" then return true end
    q = q:lower()
    local hay = ((entry.name or "") .. " " .. (entry.category or "") .. " " .. (entry.desc or "")):lower()
    for word in q:gmatch("%S+") do
        if not hay:find(word, 1, true) then return false end
    end
    return true
end

local function entryRow(e, x, y, w, h)
    local id = "lib:" .. e.id
    local r = UI.interact(id, x, y, w, h)
    local isSource = e.kind == "source"
    local current = isSource and App.pipeline.source and App.pipeline.source.entry == e
    local hov = UI.anim(id .. ":h", r.hot and 1 or 0, 20)
    if current then
        UI.rect(C.accentSoft, x, y, w, h, 6)
    elseif hov > 0.01 then
        lg.setColor(1, 1, 1, 0.07 * hov)
        lg.rectangle("fill", x, y, w, h, 6)
    end
    local dot = isSource and C.accent2 or C.accent
    lg.setColor(dot[1], dot[2], dot[3], current and 1 or 0.65)
    lg.circle("fill", x + 12, y + h / 2, 3, 12)
    UI.textMid(e.name or e.id, x + 24, y, h, Theme.fonts.body, current and C.text or (r.hot and C.text or C.textDim), "left", w - 50)
    if e.errors then
        lg.setColor(C.error)
        lg.circle("fill", x + w - 12, y + h / 2, 3.5, 12)
    elseif r.hot and not isSource then
        lg.setColor(C.textDim)
        Icons.plus(x + w - 14, y + h / 2, 20)
    end
    if r.hot then UI.setCursor("hand") end

    if r.hot and not r.held then
        -- live preview card beside the panel
        local px = select(1, Library.rect()) + M.leftW + 10
        Preview.request(e, px, y)
    end
    if e.errors then UI.tooltip(id, "⚠ " .. (e.errors[1].msg or "error")) end

    -- Effects can be dragged into the chain panel.
    if r.pressed then
        local d = UI.data(id)
        d.sx, d.sy = UI.mouse()
    end
    if r.held and not isSource then
        local d = UI.data(id)
        local mx, my = UI.mouse()
        if d.sx and (math.abs(mx - d.sx) + math.abs(my - d.sy)) > 6 then
            App.dragEntry = e
        end
    end
    if r.released then
        if App.dragEntry == e then
            -- dropped: the chain panel resolves the target
            App.dropEntry = e
            App.dragEntry = nil
        elseif r.clicked then
            if isSource then App.setSource(e) else App.addEffect(e) end
        end
    end
end

local function drawLibrary(x, y, w, h)
    local fieldH = 30
    local text, ev = W.textField("lib:search", search, x, y, w, fieldH, { placeholder = "Search effects and sources", icon = Icons.search })
    search = text
    if ev == "cancel" then search = "" end
    y = y + fieldH + 10

    local top = UI.beginScroll("lib:scroll", x - 4, y, w + 8, h - (fieldH + 10))
    local cy = top
    local rowH = 28
    for _, kind in ipairs({ "source", "effect" }) do
        local list = {}
        for _, e in ipairs(Registry.list(kind)) do
            if matches(e, search) then list[#list + 1] = e end
        end
        if #list > 0 then
            cy = cy + W.heading(kind == "source" and "Sources" or "Effects", x, cy + 4, w, tostring(#list)) + 6
            local lastCat
            for _, e in ipairs(list) do
                if e.category ~= lastCat then
                    lastCat = e.category
                    UI.text(e.category or "", x + 2, cy + 4, Theme.fonts.tiny, C.textFaint)
                    cy = cy + 20
                end
                entryRow(e, x, cy, w, rowH)
                cy = cy + rowH
            end
            cy = cy + 14
        end
    end
    if cy == top then
        UI.text("Nothing matches “" .. search .. "”", x, cy + 8, Theme.fonts.small, C.textFaint)
        cy = cy + 30
    end
    -- footer hint
    UI.text("Shaders live in shaders/ and reload when you save them.", x, cy + 6, Theme.fonts.small, C.textFaint, "left", w)
    cy = cy + 44
    UI.endScroll("lib:scroll", cy)
end

local function drawPresets(x, y, w, h)
    if not presetList then Library.refreshPresets() end
    local fieldH = 30
    local saveId = "lib:savename"
    if wantSaveFocus then
        UI.focus(saveId, saveName ~= "" and saveName or (App.currentPreset or ""), function() end)
        wantSaveFocus = false
    end
    local text, ev = W.textField(saveId, saveName, x, y, w - 74, fieldH, { placeholder = "Name this look…" })
    saveName = text
    local clicked = W.button("lib:save", "Save", x + w - 68, y, 68, fieldH, { style = "accent", tip = "Save the source, chain and every param (Ctrl+S)" })
    if (clicked or ev == "submit") and saveName ~= "" then
        App.savePreset(saveName)
        saveName = ""
    end
    y = y + fieldH + 10

    local top = UI.beginScroll("lib:presets", x - 4, y, w + 8, h - (fieldH + 10) - 44)
    local cy = top
    local rowH = 46
    for i, info in ipairs(presetList) do
        local id = "lib:preset:" .. info.file
        local r = UI.interact(id, x, cy, w, rowH - 4)
        local current = App.currentPreset == info.name
        if current then
            UI.rect(C.accentSoft, x, cy, w, rowH - 4, 6)
        elseif r.hot then
            UI.rect(C.surfaceHi, x, cy, w, rowH - 4, 6)
        end
        UI.text(UI.fit(Theme.fonts.medium, info.name, w - 30), x + 10, cy + 5, Theme.fonts.medium, current and C.text or C.text)
        if info.desc then
            UI.text(UI.fit(Theme.fonts.small, info.desc, w - 20), x + 10, cy + 23, Theme.fonts.small, C.textFaint)
        end
        if info.gallery then
            lg.setColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
            Icons.dot(x + w - 12, cy + 13, 22)
        end
        if r.hot then UI.setCursor("hand") end
        UI.tooltip(id, (info.desc or info.name) .. (info.gallery and "\n\nPart of the gallery" or "") ..
            (info.user and "\n\nSaved in your save folder" or ""))
        if r.clicked then App.loadPreset(info) end
        cy = cy + rowH
    end
    if #presetList == 0 then
        UI.text("No presets yet. Build a look, then save it.", x, cy + 8, Theme.fonts.small, C.textFaint, "left", w)
        cy = cy + 40
    end
    UI.endScroll("lib:presets", cy)

    if W.button("lib:gallery", "Play gallery", x, y + h - (fieldH + 10) - 36, w, 32,
        { icon = Icons.play, tip = "Full-screen slideshow of curated presets (G)" }) then
        require("src.gallery").start()
    end
end

function Library.draw()
    local x, y, w, h = Library.rect()
    UI.panel(x, y, w, h)
    local pad = M.pad
    local ix, iy, iw = x + pad, y + pad, w - pad * 2

    -- Tabs
    local tabs = { "Library", "Presets" }
    local idx = App.leftTab == "presets" and 1 or 0
    local def = { label = "", options = tabs, kind = "enum" }
    local tabH = 28
    UI.rect(C.surface, ix, iy, iw, tabH, 7)
    local segW = iw / 2
    local selX = UI.anim("lib:tabsel", ix + idx * segW, 22)
    UI.rect(C.surfaceAct, selX + 2, iy + 2, segW - 4, tabH - 4, 6)
    for i, t in ipairs(tabs) do
        local sx = ix + (i - 1) * segW
        local r = UI.interact("lib:tab" .. i, sx, iy, segW, tabH)
        if r.clicked then
            App.leftTab = i == 1 and "library" or "presets"
            if i == 2 then Library.refreshPresets() end
        end
        if r.hot then UI.setCursor("hand") end
        UI.textMid(t, sx, iy, tabH, Theme.fonts.medium, (i - 1 == idx) and C.text or C.textDim, "center", segW)
    end
    iy = iy + tabH + 12
    local ih = y + h - pad - iy

    if App.leftTab == "presets" then
        drawPresets(ix, iy, iw, ih)
    else
        drawLibrary(ix, iy, iw, ih)
    end
end

return Library
