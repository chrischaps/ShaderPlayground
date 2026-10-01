--[[
    Right panel: the chain (source + ordered effects) and the inspector for
    the selected node.
]]

local UI = require("src.ui.core")
local W = require("src.ui.widgets")
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local FS = require("src.util.fs")

local lg = love.graphics
local C = Theme.colors
local M = Theme.metrics

local ChainPanel = {}
local App

local aboutOpen = {}

function ChainPanel.init(app)
    App = app
end

function ChainPanel.rect()
    local sw, sh = lg.getDimensions()
    local y = M.margin * 2 + M.topBarH
    return sw - M.margin - M.rightW, y, M.rightW, sh - y - M.margin
end

local function hasProblem(node)
    return node.entry.errors ~= nil
end

local function nodeRow(node, index, x, y, w, h, isSource)
    local id = "chain:" .. node.uid
    -- Child buttons interact before the row so they get first claim on clicks.
    local over = UI.hover(x, y, w, h)
    local selected = App.selected == node
    local hov = UI.anim(id .. ":h", over and 1 or 0, 20)
    if selected then
        UI.rect(C.accentSoft, x, y, w, h, 7)
    elseif hov > 0.01 then
        lg.setColor(1, 1, 1, 0.06 * hov)
        lg.rectangle("fill", x, y, w, h, 7)
    end
    local enabled = isSource or node.enabled
    local textCol = enabled and (selected and C.text or C.textDim) or C.textFaint

    local cx = x + 8
    if isSource then
        lg.setColor(C.accent2)
        lg.circle("fill", cx + 6, y + h / 2, 4, 14)
        cx = cx + 18
    else
        -- drag grip
        lg.setColor(C.textFaint)
        Icons.grip(cx + 5, y + h / 2, 12)
        cx = cx + 16
        -- enable eye
        local eyeClicked = W.iconButton(id .. ":eye", Icons.eye, cx, y + (h - 24) / 2, 24,
            { arg = not node.enabled, tip = node.enabled and "Disable (B)" or "Enable (B)",
              color = node.enabled and C.textDim or C.textFaint })
        if eyeClicked then node.enabled = not node.enabled end
        cx = cx + 28
    end

    local nameW = w - (cx - x) - (over and 60 or 14)
    UI.textMid(node.entry.name or node.entry.id, cx, y, h, isSource and Theme.fonts.medium or Theme.fonts.body,
        textCol, "left", nameW)
    if isSource then
        local nw = math.min(Theme.fonts.medium:getWidth(node.entry.name or ""), nameW)
        UI.textMid("SOURCE", cx + nw + 8, y, h, Theme.fonts.tiny, C.textFaint, "left", 60)
    end
    if hasProblem(node) then
        lg.setColor(C.error)
        lg.circle("fill", x + w - 10, y + h / 2, 3.5, 12)
    end

    -- hover actions
    if over then
        if not isSource then
            local isSolo = App.pipeline.solo == node
            if W.iconButton(id .. ":solo", Icons.solo, x + w - 56, y + (h - 24) / 2, 24,
                { active = isSolo, tip = "Solo: show the chain only up to here" }) then
                App.pipeline.solo = isSolo and nil or node
            end
            if W.iconButton(id .. ":x", Icons.close, x + w - 30, y + (h - 24) / 2, 24, { tip = "Remove (Delete)" }) then
                App.removeNode(node)
            end
        end
    end
    if App.pipeline.solo == node and not over then
        lg.setColor(C.accent)
        Icons.solo(x + w - 24, y + h / 2, 20)
    end

    local r = UI.interact(id, x, y, w, h)
    if r.pressed then
        App.select(node)
        local d = UI.data(id)
        d.sy = select(2, UI.mouse())
    end
    if r.held and not isSource then
        local d = UI.data(id)
        local _, my = UI.mouse()
        if d.sy and math.abs(my - d.sy) > 5 then
            ChainPanel.dragging = node
        end
    end
    if r.released and ChainPanel.dragging == node then
        if ChainPanel.dropIndex then
            -- dropIndex counts positions with the dragged node still in place
            local from
            for i, n in ipairs(App.pipeline.chain) do if n == node then from = i end end
            local to = ChainPanel.dropIndex
            if from and to > from then to = to - 1 end
            App.pipeline:moveEffectTo(node, to)
        end
        ChainPanel.dragging = nil
    end
    if r.hot then UI.setCursor(ChainPanel.dragging and "sizens" or "hand") end
    UI.tooltip(id, node.entry.desc)
end

local function drawChain(x, y, w, maxH)
    local p = App.pipeline
    local rowH = 34
    local count = #p.chain
    W.heading("Chain", x, y, w, count == 1 and "1 effect" or (count .. " effects"))
    y = y + 22

    local listH = math.min(maxH - 22, (count + 1) * rowH + (count == 0 and 40 or 6))
    local top = UI.beginScroll("chain:scroll", x - 4, y, w + 8, listH)
    local cy = top

    if p.source then
        nodeRow(p.source, 0, x, cy, w, rowH - 2, true)
    end
    cy = cy + rowH

    -- connector line
    lg.setColor(1, 1, 1, 0.06)
    if count > 0 then lg.rectangle("fill", x + 13, top + rowH - 4, 1, count * rowH) end

    -- dropEntry: a library drag released this very frame still needs a target
    local dragging = ChainPanel.dragging or App.dragEntry or App.dropEntry
    local _, my = UI.mouse()
    local mx = UI.mouse()
    local overList = UI.pointIn(x - 4, y, w + 8, listH + 30)
    ChainPanel.dropIndex = nil
    if dragging and overList then
        local idx = math.floor((my - (top + rowH) + rowH / 2) / rowH) + 1
        ChainPanel.dropIndex = math.max(1, math.min(count + 1, idx))
    end

    for i, node in ipairs(p.chain) do
        local ry = cy + (i - 1) * rowH
        if ChainPanel.dragging == node then
            lg.setColor(1, 1, 1, 0.03)
            lg.rectangle("fill", x, ry, w, rowH - 2, 7)
        end
        nodeRow(node, i, x, ry, w, rowH - 2, false)
    end
    cy = cy + count * rowH

    if ChainPanel.dropIndex then
        local ly = top + rowH + (ChainPanel.dropIndex - 1) * rowH - 2
        lg.setColor(C.accent)
        lg.rectangle("fill", x + 4, ly - 1, w - 8, 2, 1)
        lg.circle("fill", x + 4, ly, 3, 10)
    end

    if count == 0 then
        UI.text("Click an effect in the library to add it here.", x + 4, cy + 2, Theme.fonts.small, C.textFaint, "left", w - 8)
        cy = cy + 34
    end
    UI.endScroll("chain:scroll", cy)

    -- Library drag dropped this frame
    if App.dropEntry then
        if overList and ChainPanel.dropIndex then
            local node = p:addEffect(App.dropEntry, ChainPanel.dropIndex)
            App.select(node)
        end
        App.dropEntry = nil
    end
    if not UI.mouseDown(1) then ChainPanel.dragging = nil end
    return y + listH
end

local function wrapText(text, font, w)
    local _, lines = font:getWrap(text, w)
    return lines
end

-- A few lines of source around an error, read fresh from disk.
local function sourceContext(file, line, radius)
    local text = file and FS.read(file)
    if not text or not line or line < 1 then return nil end
    local all = {}
    for l in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do all[#all + 1] = l end
    local out = {}
    for n = math.max(1, line - radius), math.min(#all, line + radius) do
        out[#out + 1] = { n = n, text = all[n]:gsub("\t", "    "), hit = n == line }
    end
    return out
end

local function drawErrors(node, x, y, w)
    local errs = node.entry.errors
    if not errs then return 0 end
    local f = Theme.fonts.monoSmall
    local fh = f:getHeight()
    local inner = w - 20
    local rows = {}   -- { text, color, bg }
    for i, e in ipairs(errs) do
        if i > 4 then rows[#rows + 1] = { "…", C.textDim } break end
        local file = (e.file or ""):match("([^/]+)$") or ""
        rows[#rows + 1] = { string.format("%s:%d%s", file, e.line or 0, e.pass and (" [" .. e.pass .. "]") or ""), C.warn }
        for _, l in ipairs(wrapText(e.msg or "", f, inner - 12)) do rows[#rows + 1] = { "  " .. l, C.text } end
        if i == 1 then
            local ctx = sourceContext(e.file, e.line, 1)
            if ctx then
                for _, c in ipairs(ctx) do
                    local s = string.format("%4d │ %s", c.n, c.text)
                    rows[#rows + 1] = { UI.fit(f, s, inner), c.hit and C.text or C.textFaint, c.hit }
                end
            end
        end
    end
    local h = #rows * fh + 36
    UI.rect({ C.error[1], C.error[2], C.error[3], 0.12 }, x, y, w, h, 7)
    lg.setColor(C.error[1], C.error[2], C.error[3], 0.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 7)
    UI.text(node.entry.passes and "Compile error (showing last good version)" or "Compile error",
        x + 10, y + 7, Theme.fonts.medium, C.error)
    local ry = y + 28
    for _, r in ipairs(rows) do
        if r[3] then
            UI.rect({ C.error[1], C.error[2], C.error[3], 0.22 }, x + 4, ry - 1, w - 8, fh + 2, 3)
        end
        UI.text(r[1], x + 10, ry, f, r[2])
        ry = ry + fh
    end
    return h + 10
end

local function drawInspector(x, y, w, h)
    local node = App.selected
    if not node then
        UI.text("Select something in the chain to tweak it.", x, y + 10, Theme.fonts.small, C.textFaint, "left", w)
        return
    end
    local e = node.entry

    -- Header
    UI.text(UI.fit(Theme.fonts.title, e.name or e.id, w - 100), x, y, Theme.fonts.title, C.text)
    UI.text((e.category or ""):upper(), x, y + 22, Theme.fonts.heading,
        e.kind == "source" and C.accent2 or C.accent)

    -- action icons
    local bs = 26
    local ax = x + w - bs
    if W.iconButton("insp:file", Icons.file, ax, y, bs, { tip = "Open " .. (e.path or "") .. " in your editor" }) then
        local path = FS.realPath(e.path)
        if path then FS.openInOS(path) end
    end
    ax = ax - bs - 2
    if W.iconButton("insp:dice", Icons.dice, ax, y, bs, { tip = "Randomize params (X): a nudge toward happy accidents" }) then
        App.randomize(node)
    end
    ax = ax - bs - 2
    if W.iconButton("insp:reset", Icons.reset, ax, y, bs, { tip = "Reset params to defaults (R) · Shift+R restarts the simulation" }) then
        if UI.shift() then node:restart() else node:resetParams() end
    end
    y = y + 42

    if e.desc then
        local lines = wrapText(e.desc, Theme.fonts.small, w)
        UI.text(table.concat(lines, "\n"), x, y, Theme.fonts.small, C.textDim)
        y = y + #lines * Theme.fonts.small:getHeight() + 8
    end

    -- About (the "how it works" note)
    if e.about then
        local open = aboutOpen[e.id]
        local r = UI.interact("insp:about", x, y, w, 22)
        lg.setColor(r.hot and C.text or C.textDim)
        Icons.chevron(x + 6, y + 11, 22, open)
        UI.textMid("How it works", x + 16, y, 22, Theme.fonts.small, r.hot and C.text or C.textDim)
        if r.hot then UI.setCursor("hand") end
        if r.clicked then aboutOpen[e.id] = not open end
        y = y + 24
        if open then
            local lines = wrapText(e.about, Theme.fonts.small, w - 14)
            local th = #lines * Theme.fonts.small:getHeight()
            UI.rect(C.surface, x, y, w, th + 16, 7)
            lg.setColor(C.accent[1], C.accent[2], C.accent[3], 0.5)
            lg.rectangle("fill", x, y + 6, 2, th + 4)
            UI.text(table.concat(lines, "\n"), x + 10, y + 8, Theme.fonts.small, C.text)
            y = y + th + 24
        end
    end

    y = y + drawErrors(node, x, y, w)

    W.separator(x, y, w)
    y = y + 10

    -- Params
    local top = UI.beginScroll("insp:scroll:" .. node.uid, x - 10, y, w + 20, h - (y - (ChainPanel.inspectorTop or y)))
    local cy = top + 4
    local visibleIndex = 0
    for _, def in ipairs(e.params or {}) do
        if not def.hidden then
            visibleIndex = visibleIndex + 1
            local selected = visibleIndex == App.keyParam
            local v = node.values[def.name]
            local nv, changed, used = W.param("p:" .. node.uid .. ":" .. def.name, def, v, x, cy, w, { selected = selected })
            if changed then
                node.values[def.name] = nv
                App.keyParam = visibleIndex
            end
            if selected then
                UI.scrollIntoView("insp:scroll:" .. node.uid, cy - top, cy - top + used)
            end
            cy = cy + used + 8
        end
    end
    if visibleIndex == 0 then
        UI.text("No adjustable parameters.", x, cy, Theme.fonts.small, C.textFaint)
        cy = cy + 24
    end
    UI.endScroll("insp:scroll:" .. node.uid, cy + 6)
end

function ChainPanel.draw()
    local x, y, w, h = ChainPanel.rect()
    UI.panel(x, y, w, h)
    local pad = M.pad
    local ix, iw = x + pad, w - pad * 2
    local cy = y + pad
    local chainMax = math.floor(h * 0.4)
    cy = drawChain(ix, cy, iw, chainMax) + 12
    W.separator(ix, cy - 6, iw)
    ChainPanel.inspectorTop = cy + 8
    drawInspector(ix, cy + 8, iw, y + h - pad - (cy + 8))
end

return ChainPanel
