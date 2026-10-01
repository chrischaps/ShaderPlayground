--[[
    Immediate-mode UI core.

    Every frame the app calls UI.beginFrame(dt), draws its panels by calling
    widget functions, then UI.endFrame(). Widgets are identified by string ids.

        hot     the widget under the mouse this frame
        active  the widget being pressed/dragged (keeps the mouse until release)
        focus   the widget receiving text input

    Layers: popups are drawn last (deferred) and block the widgets beneath
    them, using the popup rectangle from the previous frame. Panels register
    their rectangles so the app knows when the UI wants the mouse.
]]

local Theme = require("src.ui.theme")

local lg = love.graphics

local UI = {}

local S = {
    time = 0, dt = 0,
    mx = 0, my = 0, pmx = 0, pmy = 0,
    down = {}, pressed = {}, released = {},
    wheel = 0, wheelUsed = false,
    hot = nil, hotPrev = nil, active = nil, focus = nil,
    hoverTime = 0,
    lastPressId = nil, lastPressTime = -1,
    anims = {},
    clips = {},
    panels = {}, panelsPrev = {},
    popup = nil, popupRectPrev = nil, popupOpenedThisFrame = false,
    layer = 0,
    tooltip = nil,
    text = "", textEvents = {}, keyEvents = {},
    scrolls = {},
    data = {},       -- per-widget scratch state
    cursor = "arrow",
    backdrop = nil,  -- { image, x, y, w, h } blurred scene for glass panels
}
UI.state = S

----------------------------------------------------------------------
-- Input (forwarded from love callbacks)
----------------------------------------------------------------------

function UI.mousepressed(x, y, b)
    S.pressed[b] = true
    S.down[b] = true
end

function UI.mousereleased(x, y, b)
    S.released[b] = true
    S.down[b] = false
end

function UI.wheelmoved(x, y)
    S.wheel = S.wheel + y
end

function UI.textinput(t)
    if S.focus then
        table.insert(S.textEvents, t)
        return true
    end
    return false
end

function UI.keypressed(key)
    if S.focus then
        table.insert(S.keyEvents, key)
        return true
    end
    if S.popup and key == "escape" then
        S.popup = nil
        return true
    end
    return false
end

-- Does the UI want the mouse at this point? (panel, popup, or a drag)
function UI.wantsMouse(x, y)
    x, y = x or S.mx, y or S.my
    if S.active then return true end
    if S.popupRectPrev then
        local r = S.popupRectPrev
        if x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] then return true end
    end
    for _, r in ipairs(S.panelsPrev) do
        if x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] then return true end
    end
    return false
end

function UI.wantsKeyboard()
    return S.focus ~= nil
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------

function UI.beginFrame(dt)
    S.dt = dt
    S.time = S.time + dt
    S.pmx, S.pmy = S.mx, S.my
    if S.virtualMouse then
        S.mx, S.my = S.virtualMouse[1], S.virtualMouse[2]
        S.rects = S.rectsNext or {}
        S.rectsNext = {}
    else
        S.mx, S.my = love.mouse.getPosition()
    end
    S.hotPrev = S.hot
    S.hot = nil
    if #S.clips > 0 then
        -- unbalanced push/pop last frame; never let it leak into this one
        S.clips = {}
        lg.setScissor()
    end
    S.panelsPrev = S.panels
    S.panels = {}
    S.wheelUsed = false
    S.tooltip = nil
    S.layer = 0
    S.cursor = "arrow"
    S.popupOpenedThisFrame = false
    if S.popup then
        S.popupRectPrev = { S.popup.x, S.popup.y, S.popup.w, S.popup.h }
    else
        S.popupRectPrev = nil
    end
    if S.hotPrev ~= nil then
        S.hoverTime = S.hoverTime + dt
    else
        S.hoverTime = 0
    end
end

function UI.endFrame()
    -- Popups draw last, on top of everything.
    if S.popup then
        local p = S.popup
        S.layer = 1
        local clickedOutside = (S.pressed[1] or S.pressed[2]) and not S.popupOpenedThisFrame
            and not UI.pointIn(p.x, p.y, p.w, p.h)
            and not (p.anchor and UI.pointIn(p.anchor[1], p.anchor[2], p.anchor[3], p.anchor[4]))
        UI.shadowRect(p.x, p.y, p.w, p.h, 8)
        UI.rect(Theme.colors.popup, p.x, p.y, p.w, p.h, 8)
        lg.setColor(Theme.colors.glassEdge)
        lg.setLineWidth(1)
        lg.rectangle("line", p.x + 0.5, p.y + 0.5, p.w - 1, p.h - 1, 8)
        local keep = p.draw(p)
        if keep == false or clickedOutside then
            if S.popup == p then S.popup = nil end
        end
        S.layer = 0
    end

    -- Tooltip
    if S.tooltip and S.hoverTime > 0.55 and not S.active then
        UI.drawTooltip(S.tooltip)
    end

    if S.released[1] then
        S.active = nil
    end
    if S.released[2] and S.active and S.data.activeButton == 2 then
        S.active = nil
    end
    -- Clicking anywhere that isn't the focused widget drops focus (but not
    -- the very click that gave it focus).
    if S.pressed[1] and S.focus and S.hot ~= S.focus and S.focusCommit and S.focusTime ~= S.time then
        local commit = S.focusCommit
        S.focusCommit = nil
        S.focus = nil
        commit()
    end

    S.pressed = {}
    S.released = {}
    S.wheel = 0
    S.textEvents = {}
    S.keyEvents = {}

    local want = S.cursor
    if S.lastCursor ~= want then
        local ok, c = pcall(love.mouse.getSystemCursor, want)
        if ok then love.mouse.setCursor(c) end
        S.lastCursor = want
    end
end

function UI.setCursor(name)
    S.cursor = name
end

----------------------------------------------------------------------
-- Hit testing / interaction
----------------------------------------------------------------------

function UI.pointIn(x, y, w, h)
    return S.mx >= x and S.mx < x + w and S.my >= y and S.my < y + h
end

local function inClip()
    local c = S.clips[#S.clips]
    if not c then return true end
    return S.mx >= c[1] and S.mx < c[1] + c[3] and S.my >= c[2] and S.my < c[2] + c[4]
end

local function blockedByPopup()
    if S.layer >= 1 then return false end
    local r = S.popupRectPrev
    if not r then return false end
    return S.mx >= r[1] and S.mx <= r[1] + r[3] and S.my >= r[2] and S.my <= r[2] + r[4]
end

function UI.hover(x, y, w, h)
    return UI.pointIn(x, y, w, h) and inClip() and not blockedByPopup()
end

--[[
    Core interaction for a rectangle. Returns a table:
      over, hot, pressed, held, clicked, released, rclicked, double, dx, dy
]]
function UI.interact(id, x, y, w, h)
    if S.virtualMouse then
        -- remember visible widget rects so test scripts can target them by id
        local c = S.clips[#S.clips]
        local cx, cy = x + w / 2, y + h / 2
        if not c or (cx >= c[1] and cx < c[1] + c[3] and cy >= c[2] and cy < c[2] + c[4]) then
            S.rectsNext[id] = { x, y, w, h }
        end
    end
    local over = UI.hover(x, y, w, h)
    local r = { over = over }
    if over and (S.active == nil or S.active == id) then
        S.hot = id
        r.hot = true
    end
    if over and S.active == nil then
        if S.pressed[1] then
            S.active = id
            S.data.activeButton = 1
            r.pressed = true
            if S.lastPressId == id and S.time - S.lastPressTime < 0.35 then
                r.double = true
                S.lastPressId = nil
            else
                S.lastPressId = id
                S.lastPressTime = S.time
            end
        elseif S.pressed[2] then
            r.rclicked = true
        end
    end
    if S.active == id then
        r.held = true
        r.dx, r.dy = S.mx - S.pmx, S.my - S.pmy
        if S.released[1] then
            r.released = true
            r.clicked = over
        end
    end
    return r
end

-- Button state as the UI saw it (works with scripted input too).
function UI.mouseDown(b) return S.down[b or 1] == true end

-- Current pointer position (virtual when a script is driving).
function UI.pointer()
    if S.virtualMouse then return S.virtualMouse[1], S.virtualMouse[2] end
    return love.mouse.getPosition()
end

function UI.isActive(id) return S.active == id end
function UI.isHot(id) return S.hot == id or S.hotPrev == id end
function UI.mouse() return S.mx, S.my end
function UI.time() return S.time end
function UI.dt() return S.dt end
function UI.shift() return love.keyboard.isDown("lshift", "rshift") end
function UI.ctrl() return love.keyboard.isDown("lctrl", "rctrl") end

function UI.setActive(id) S.active = id end

-- Consume wheel movement if the mouse is over (x,y,w,h). Returns wheel delta.
function UI.takeWheel(x, y, w, h)
    if S.wheel ~= 0 and not S.wheelUsed and UI.hover(x, y, w, h) then
        S.wheelUsed = true
        return S.wheel
    end
    return 0
end

-- Smoothly animated value per key.
function UI.anim(key, target, rate)
    local v = S.anims[key]
    if v == nil then
        v = target
    else
        v = target + (v - target) * math.exp(-(rate or 18) * S.dt)
        if math.abs(v - target) < 0.001 then v = target end
    end
    S.anims[key] = v
    return v
end

function UI.data(id)
    local d = S.data[id]
    if not d then
        d = {}
        S.data[id] = d
    end
    return d
end

function UI.tooltip(id, text)
    if text and S.hot == id and S.hotPrev == id then
        S.tooltip = text
    end
end

----------------------------------------------------------------------
-- Text focus
----------------------------------------------------------------------

-- Begin editing: commit is called when focus is lost by clicking away.
function UI.focus(id, initialText, commit)
    S.focus = id
    S.focusTime = S.time
    S.data[id] = S.data[id] or {}
    S.data[id].text = initialText or ""
    S.data[id].caretTime = S.time
    S.focusCommit = commit
end

function UI.unfocus()
    S.focus = nil
    S.focusCommit = nil
end

function UI.hasFocus(id)
    return S.focus == id
end

-- Apply this frame's typing to the focused widget. Returns text, event
-- where event is "submit", "cancel" or nil.
function UI.editText(id)
    local d = S.data[id]
    local text = d.text or ""
    local event
    for _, t in ipairs(S.textEvents) do
        text = text .. t
        d.caretTime = S.time
    end
    for _, k in ipairs(S.keyEvents) do
        if k == "backspace" then
            if UI.ctrl() then
                text = text:gsub("%S*%s*$", "")
            else
                -- remove one UTF-8 character
                local i = #text
                while i > 0 do
                    local b = text:byte(i)
                    i = i - 1
                    if b < 0x80 or b >= 0xC0 then break end
                end
                text = text:sub(1, i)
            end
            d.caretTime = S.time
        elseif k == "return" or k == "kpenter" then
            event = "submit"
        elseif k == "escape" then
            event = "cancel"
        elseif k == "v" and UI.ctrl() then
            text = text .. (love.system.getClipboardText() or ""):gsub("[\r\n]", "")
        elseif k == "a" and UI.ctrl() then
            text = ""
        end
    end
    d.text = text
    if event then
        S.focus = nil
        S.focusCommit = nil
    end
    return text, event
end

----------------------------------------------------------------------
-- Clipping and scrolling
----------------------------------------------------------------------

function UI.pushClip(x, y, w, h)
    local c = S.clips[#S.clips]
    if c then
        local x2, y2 = math.min(x + w, c[1] + c[3]), math.min(y + h, c[2] + c[4])
        x, y = math.max(x, c[1]), math.max(y, c[2])
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
    end
    table.insert(S.clips, { x, y, w, h })
    lg.setScissor(x, y, w, h)
end

function UI.popClip()
    table.remove(S.clips)
    local c = S.clips[#S.clips]
    if c then lg.setScissor(c[1], c[2], c[3], c[4]) else lg.setScissor() end
end

-- Returns the content y-origin (top - scroll). Call UI.endScroll(id, contentBottom).
function UI.beginScroll(id, x, y, w, h)
    local s = S.scrolls[id]
    if not s then
        s = { pos = 0, target = 0, content = 0, view = h }
        S.scrolls[id] = s
    end
    s.x, s.y, s.w, s.h = x, y, w, h
    s.view = h
    local wheel = UI.takeWheel(x, y, w, h)
    if wheel ~= 0 then
        s.target = s.target - wheel * 48
    end
    local maxScroll = math.max(0, s.content - h)
    s.target = math.max(0, math.min(maxScroll, s.target))
    s.pos = s.target + (s.pos - s.target) * math.exp(-20 * S.dt)
    if math.abs(s.pos - s.target) < 0.5 then s.pos = s.target end
    UI.pushClip(x, y, w, h)
    return y - math.floor(s.pos + 0.5)
end

function UI.endScroll(id, contentBottom)
    local s = S.scrolls[id]
    UI.popClip()
    s.content = contentBottom - (s.y - math.floor(s.pos + 0.5))
    -- Scrollbar
    if s.content > s.view + 1 then
        local frac = s.view / s.content
        local barH = math.max(24, s.view * frac)
        local t = s.pos / (s.content - s.view)
        local by = s.y + (s.view - barH) * t
        local c = Theme.colors.textFaint
        lg.setColor(c[1], c[2], c[3], 0.5)
        lg.rectangle("fill", s.x + s.w + 1, by, 3, barH, 1.5)
    end
end

function UI.scrollTo(id, y)
    local s = S.scrolls[id]
    if s then s.target = y end
end

-- Make sure a y-range (in content coordinates) is visible.
function UI.scrollIntoView(id, top, bottom)
    local s = S.scrolls[id]
    if not s then return end
    if top < s.target then s.target = top
    elseif bottom > s.target + s.view then s.target = bottom - s.view end
end

----------------------------------------------------------------------
-- Popups
----------------------------------------------------------------------

-- Open a popup. draw(p) is called each frame inside the popup layer and may
-- return false to close. anchor = rect that toggles the popup (not "outside").
function UI.openPopup(id, x, y, w, h, draw, anchor)
    local sw, sh = lg.getDimensions()
    x = math.max(4, math.min(sw - w - 4, x))
    if y + h > sh - 4 then y = math.max(4, sh - h - 4) end
    S.popup = { id = id, x = x, y = y, w = w, h = h, draw = draw, anchor = anchor }
    S.popupOpenedThisFrame = true
end

function UI.popupOpen(id)
    return S.popup ~= nil and S.popup.id == id
end

function UI.closePopup()
    S.popup = nil
end

----------------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------------

function UI.rect(color, x, y, w, h, r)
    lg.setColor(color)
    lg.rectangle("fill", x, y, w, h, r or 0, r or 0, 8)
end

function UI.shadowRect(x, y, w, h, r)
    for i = 1, 4 do
        lg.setColor(0, 0, 0, 0.07)
        lg.rectangle("fill", x - i, y - i + 3, w + i * 2, h + i * 2, r + i, r + i, 8)
    end
end

-- Truncate text to a width with an ellipsis.
function UI.fit(font, text, w)
    if font:getWidth(text) <= w then return text end
    local ell = "…"
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if font:getWidth(text:sub(1, mid) .. ell) <= w then lo = mid else hi = mid - 1 end
    end
    -- avoid cutting a UTF-8 sequence
    local s = text:sub(1, lo)
    while #s > 0 and s:byte(#s) >= 0x80 and s:byte(#s) < 0xC0 do s = s:sub(1, -2) end
    if #s > 0 and s:byte(#s) >= 0xC0 then s = s:sub(1, -2) end
    return s .. ell
end

function UI.text(text, x, y, font, color, align, w)
    lg.setFont(font or Theme.fonts.body)
    lg.setColor(color or Theme.colors.text)
    if align and w then
        lg.printf(text, math.floor(x), math.floor(y), w, align)
    else
        lg.print(text, math.floor(x), math.floor(y))
    end
end

-- Text vertically centered in a box of height h.
function UI.textMid(text, x, y, h, font, color, align, w)
    font = font or Theme.fonts.body
    local ty = y + (h - font:getHeight()) / 2
    if w and align ~= "left" then
        UI.text(UI.fit(font, text, w), x, ty, font, color, align, w)
    else
        UI.text(w and UI.fit(font, text, w) or text, x, ty, font, color)
    end
end

function UI.drawTooltip(text)
    local f = Theme.fonts.small
    local maxW = 280
    local _, lines = f:getWrap(text, maxW)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, f:getWidth(l)) end
    local h = #lines * f:getHeight() + 12
    w = w + 20
    local sw, sh = lg.getDimensions()
    local x = math.min(S.mx + 14, sw - w - 6)
    local y = S.my + 20
    if y + h > sh - 6 then y = S.my - h - 8 end
    UI.shadowRect(x, y, w, h, 6)
    UI.rect(Theme.colors.popup, x, y, w, h, 6)
    lg.setColor(Theme.colors.glassEdge)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6)
    UI.text(table.concat(lines, "\n"), x + 10, y + 6, f, Theme.colors.text)
end

-- Register a panel rect (for mouse routing) and draw frosted glass.
function UI.panel(x, y, w, h, opts)
    table.insert(S.panels, { x, y, w, h })
    opts = opts or {}
    local r = opts.radius or Theme.metrics.radius + 4
    UI.shadowRect(x, y, w, h, r)
    local bd = S.backdrop
    if bd then
        lg.stencil(function() lg.rectangle("fill", x, y, w, h, r, r, 10) end, "replace", 1)
        lg.setStencilTest("greater", 0)
        lg.setColor(1, 1, 1, 1)
        local iw, ih = bd.image:getDimensions()
        lg.draw(bd.image, bd.x, bd.y, 0, bd.w / iw, bd.h / ih)
        lg.setStencilTest()
    end
    UI.rect(opts.tint or Theme.colors.glass, x, y, w, h, r)
    lg.setLineWidth(1)
    lg.setColor(Theme.colors.glassEdge)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r, 10)
    -- subtle top highlight
    lg.setColor(Theme.colors.glassHi)
    lg.line(x + r, y + 1.5, x + w - r, y + 1.5)
end

function UI.registerRect(x, y, w, h)
    table.insert(S.panels, { x, y, w, h })
end

function UI.setBackdrop(image, x, y, w, h)
    if image then
        S.backdrop = { image = image, x = x, y = y, w = w, h = h }
    else
        S.backdrop = nil
    end
end

return UI
