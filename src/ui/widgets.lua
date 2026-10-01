--[[
    Widgets built on the UI core. Each returns its (possibly new) value plus
    a `changed` flag, and draws itself. Param widgets also return the height
    they used so panels can stack them.
]]

local UI = require("src.ui.core")
local Theme = require("src.ui.theme")
local Icons = require("src.ui.icons")
local Params = require("src.params")
local Color = require("src.util.color")

local lg = love.graphics
local C = Theme.colors

local W = {}

local svShader, hueShader
local function pickerShaders()
    if svShader then return end
    svShader = lg.newShader([[
        uniform float hue;
        vec3 hsv2rgb(vec3 c) {
            vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
            return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
        }
        vec4 effect(vec4 col, Image t, vec2 uv, vec2 sc) {
            return vec4(hsv2rgb(vec3(hue, uv.x, 1.0 - uv.y)), col.a);
        }
    ]])
    hueShader = lg.newShader([[
        vec3 hsv2rgb(vec3 c) {
            vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
            return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
        }
        vec4 effect(vec4 col, Image t, vec2 uv, vec2 sc) {
            return vec4(hsv2rgb(vec3(uv.x, 1.0, 1.0)), col.a);
        }
    ]])
end

local white1
local function quad(x, y, w, h)
    if not white1 then
        local d = love.image.newImageData(1, 1)
        d:setPixel(0, 0, 1, 1, 1, 1)
        white1 = lg.newImage(d)
    end
    lg.draw(white1, x, y, 0, w, h)
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------

-- style: "ghost" (default), "solid", "accent", "danger"
function W.button(id, label, x, y, w, h, opts)
    opts = opts or {}
    local r = UI.interact(id, x, y, w, h)
    local hov = UI.anim(id .. ":h", r.hot and 1 or 0, 20)
    local base = opts.style == "accent" and C.accentSoft or C.surface
    local col = { base[1], base[2], base[3], base[4] + hov * 0.06 + (r.held and 0.06 or 0) }
    if opts.active then col = C.accentSoft end
    UI.rect(col, x, y, w, h, 6)
    local tc = opts.style == "accent" and C.accent or (opts.dim and C.textDim or C.text)
    if opts.color then tc = opts.color end
    local f = opts.font or Theme.fonts.medium
    if opts.icon then
        local iw = h
        lg.setColor(tc)
        opts.icon(x + 4 + iw / 2, y + h / 2, iw * 0.9)
        UI.textMid(label, x + iw + 2, y, h, f, tc, "left", w - iw - 8)
    else
        UI.textMid(label, x, y, h, f, tc, "center", w)
    end
    UI.tooltip(id, opts.tip)
    if r.hot then UI.setCursor("hand") end
    return r.clicked, r
end

function W.iconButton(id, icon, x, y, size, opts)
    opts = opts or {}
    local r = UI.interact(id, x, y, size, size)
    local hov = UI.anim(id .. ":h", r.hot and 1 or 0, 20)
    if opts.active then
        UI.rect(opts.activeBg or C.accentSoft, x, y, size, size, 6)
    end
    if hov > 0.01 then
        lg.setColor(1, 1, 1, 0.08 * hov + (r.held and 0.05 or 0))
        lg.rectangle("fill", x, y, size, size, 6)
    end
    local col = opts.color or (opts.active and C.accent or C.textDim)
    if hov > 0.5 and not opts.color and not opts.active then col = C.text end
    lg.setColor(col)
    icon(x + size / 2, y + size / 2, size, opts.arg)
    UI.tooltip(id, opts.tip)
    if r.hot then UI.setCursor("hand") end
    return r.clicked, r
end

----------------------------------------------------------------------
-- Text field
----------------------------------------------------------------------

function W.textField(id, text, x, y, w, h, opts)
    opts = opts or {}
    local r = UI.interact(id, x, y, w, h)
    local focused = UI.hasFocus(id)
    if r.pressed and not focused then
        UI.focus(id, text, function() end)
        focused = true
    end
    if r.hot then UI.setCursor("ibeam") end
    local event
    if focused then
        text, event = UI.editText(id)
        if opts.live == false and event ~= "submit" then
            -- caller only wants committed text
        end
    end
    UI.rect(focused and C.surfaceAct or (r.hot and C.surfaceHi or C.surface), x, y, w, h, 6)
    if focused then
        lg.setColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
        lg.setLineWidth(1)
        lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6)
    end
    local tx = x + 10
    if opts.icon then
        lg.setColor(C.textFaint)
        opts.icon(x + 14, y + h / 2, h * 0.8)
        tx = x + 28
    end
    local f = opts.font or Theme.fonts.body
    local shown = text
    if shown == "" and not focused and opts.placeholder then
        UI.textMid(opts.placeholder, tx, y, h, f, C.textFaint, "left", w - (tx - x) - 8)
    else
        -- keep the end of long text visible while typing
        local avail = w - (tx - x) - 10
        while f:getWidth(shown) > avail and #shown > 0 do shown = shown:sub(2) end
        UI.textMid(shown, tx, y, h, f, C.text)
        if focused and (UI.time() - (UI.data(id).caretTime or 0)) % 1 < 0.6 then
            local cx = tx + f:getWidth(shown) + 1
            lg.setColor(C.accent)
            lg.rectangle("fill", cx, y + h * 0.22, 1.5, h * 0.56)
        end
    end
    return text, event, focused
end

----------------------------------------------------------------------
-- Slider
----------------------------------------------------------------------

local function toT(def, v)
    local lo, hi = def.min, def.max
    if hi == lo then return 0 end
    if def.log and lo > 0 then
        return (math.log(v) - math.log(lo)) / (math.log(hi) - math.log(lo))
    end
    return (v - lo) / (hi - lo)
end

local function fromT(def, t)
    t = math.max(0, math.min(1, t))
    local lo, hi = def.min, def.max
    if def.log and lo > 0 then
        return math.exp(math.log(lo) + (math.log(hi) - math.log(lo)) * t)
    end
    return lo + (hi - lo) * t
end

local function snap(def, v)
    local step = def.step or (def.max - def.min) / 100
    if step <= 0 then return v end
    return def.min + math.floor((v - def.min) / step + 0.5) * step
end

local function parseNumber(def, s)
    s = s:gsub("°", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(s)
    if not n then
        -- allow simple expressions like 1/3 or pi/2
        local fn = loadstring("return " .. s:gsub("pi", tostring(math.pi)))
        if fn then
            setfenv(fn, {})
            local ok, r = pcall(fn)
            if ok and type(r) == "number" then n = r end
        end
    end
    if n and def.kind == "angle" then n = math.rad(n) end
    return n
end

-- A bare track (used by slider and vec rows). Returns value, changed.
local function track(id, def, v, x, y, w, h, opts)
    local r = UI.interact(id, x, y - 6, w, h + 12)
    local changed = false
    local isInt = def.kind == "int"
    if r.pressed then
        local d = UI.data(id)
        d.fineAnchor = v
        if not UI.shift() then
            local nv = fromT(def, (UI.state.mx - x) / w)
            if isInt or UI.ctrl() then nv = snap(def, nv) end
            if isInt then nv = math.floor(nv + 0.5) end
            if nv ~= v then v, changed = nv, true end
        end
    elseif r.held then
        if UI.shift() then
            local dt = (r.dx or 0) / w * 0.1
            local nv = fromT(def, toT(def, v) + dt)
            if nv ~= v then v, changed = nv, true end
        else
            local nv = fromT(def, (UI.state.mx - x) / w)
            if isInt or UI.ctrl() then nv = snap(def, nv) end
            if isInt then nv = math.floor(nv + 0.5) end
            if nv ~= v then v, changed = nv, true end
        end
    end
    if r.hot or r.held then UI.setCursor("sizewe") end

    local t = math.max(0, math.min(1, toT(def, v)))
    local hov = UI.anim(id .. ":h", (r.hot or r.held) and 1 or 0, 18)
    local th = 4 + hov
    local ty = y + (h - th) / 2
    UI.rect(C.track, x, ty, w, th, th / 2)
    -- fill grows from the default (or from min for one-sided ranges)
    local acc = opts and opts.color or C.accent
    lg.setColor(acc[1], acc[2], acc[3], 0.85)
    local t0 = 0
    if def.min < 0 and def.max > 0 then t0 = toT(def, 0) end
    local a, b = math.min(t0, t), math.max(t0, t)
    lg.rectangle("fill", x + w * a, ty, math.max(2, w * (b - a)), th, th / 2)
    -- default tick
    if type(def.default) == "number" then
        local dt = toT(def, def.default)
        lg.setColor(1, 1, 1, 0.35)
        lg.rectangle("fill", x + w * dt - 0.5, ty - 3, 1, th + 6)
    end
    -- knob
    local kr = 5 + hov * 2 + (r.held and 1 or 0)
    lg.setColor(0, 0, 0, 0.35)
    lg.circle("fill", x + w * t, ty + th / 2 + 1, kr + 1, 20)
    lg.setColor(C.text)
    lg.circle("fill", x + w * t, ty + th / 2, kr, 20)
    return v, changed, r
end

-- Numeric slider with label and value. Returns value, changed, height.
function W.slider(id, def, v, x, y, w, opts)
    opts = opts or {}
    local label = opts.label or def.label
    local lh = 18
    local changed = false
    local editId = id .. ":edit"
    local f = Theme.fonts.mono

    -- value text / inline editor
    local valueStr = Params.format(def, v)
    local vw = math.max(f:getWidth(valueStr) + 12, 54)
    local vx = x + w - vw
    local vr = UI.interact(id .. ":val", vx, y, vw, lh)
    UI.textMid(label, x, y, lh, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w - vw - 6)
    if opts.selected then
        lg.setColor(C.accent)
        lg.circle("fill", x - 7, y + lh / 2, 2.2, 10)
    end

    local editing = UI.hasFocus(editId)
    local function commitText(s)
        local n = parseNumber(def, s)
        if n then
            n = Params.clamp(def, n)
            if n ~= v then v, changed = n, true end
        end
    end
    local ed = UI.data(editId)
    if ed.pending then
        -- focus was lost by clicking elsewhere: apply what was typed
        commitText(ed.pending)
        ed.pending = nil
    end
    if (vr.pressed and vr.double) and not editing then
        local text
        if def.kind == "angle" then
            text = tostring(math.floor(math.deg(v) * 100 + 0.5) / 100)
        else
            text = (Params.format(def, v):gsub("°", ""))
        end
        UI.focus(editId, text, function() ed.pending = ed.text end)
        editing = true
    end
    if editing then
        local text, ev = UI.editText(editId)
        if ev == "submit" then commitText(text) end
        UI.rect(C.surfaceAct, vx, y, vw, lh, 4)
        UI.textMid(text, vx + 6, y, lh, f, C.text)
        if (UI.time() % 1) < 0.6 then
            lg.setColor(C.accent)
            lg.rectangle("fill", vx + 7 + f:getWidth(text), y + 3, 1.5, lh - 6)
        end
    else
        if vr.hot then
            UI.rect(C.surface, vx, y, vw, lh, 4)
            UI.setCursor("ibeam")
        end
        UI.textMid(valueStr, vx, y, lh, f, opts.selected and C.text or C.textDim, "right", vw - 4)
    end
    UI.tooltip(id .. ":val", "Double-click to type a value")

    local tr = {}
    local nv, tchanged
    nv, tchanged, tr = track(id, def, v, x, y + lh + 2, w, 14, opts)
    if tchanged then v, changed = nv, true end

    if tr.rclicked or vr.rclicked then
        v, changed = Params.defaultValue(def), true
    end
    if tr.hot then
        local wheel = UI.ctrl() and UI.takeWheel(x, y, w, lh + 16) or 0
        if wheel ~= 0 then
            v, changed = Params.nudge(def, v, wheel, UI.shift()), true
        end
    end
    UI.tooltip(id, def.tip and (def.tip .. "\n\nShift: fine · Ctrl: snap · Right-click: reset") or
        "Shift: fine · Ctrl: snap · Right-click: reset")
    if changed then v = Params.clamp(def, v) end
    return v, changed, lh + 18
end

----------------------------------------------------------------------
-- Toggle
----------------------------------------------------------------------

function W.toggle(id, label, v, x, y, w, opts)
    opts = opts or {}
    local h = 24
    local r = UI.interact(id, x, y, w, h)
    local changed = false
    if r.clicked then v, changed = not v, true end
    if r.rclicked and opts.default ~= nil then v, changed = opts.default, true end
    UI.textMid(label, x, y, h, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w - 50)
    local sw, sh = 32, 18
    local sx, sy = x + w - sw, y + (h - sh) / 2
    local t = UI.anim(id .. ":t", v and 1 or 0, 16)
    local hov = UI.anim(id .. ":h", r.hot and 1 or 0, 18)
    local on = C.accent
    lg.setColor(
        C.track[1] + (on[1] - C.track[1]) * t,
        C.track[2] + (on[2] - C.track[2]) * t,
        C.track[3] + (on[3] - C.track[3]) * t,
        0.12 + t * 0.75 + hov * 0.08)
    lg.rectangle("fill", sx, sy, sw, sh, sh / 2)
    lg.setColor(C.text)
    lg.circle("fill", sx + sh / 2 + (sw - sh) * t, sy + sh / 2, sh / 2 - 3, 20)
    if r.hot then UI.setCursor("hand") end
    UI.tooltip(id, opts.tip)
    return v, changed, h + 4
end

----------------------------------------------------------------------
-- Enum: segmented control when it fits, otherwise a dropdown
----------------------------------------------------------------------

function W.dropdown(id, options, index, x, y, w, h, opts)
    opts = opts or {}
    local changed = false
    local r = UI.interact(id, x, y, w, h)
    local open = UI.popupOpen(id)
    UI.rect(open and C.surfaceAct or (r.hot and C.surfaceHi or C.surface), x, y, w, h, 6)
    UI.textMid(tostring(options[index + 1] or "?"), x + 10, y, h, opts.font or Theme.fonts.body, C.text, "left", w - 30)
    lg.setColor(C.textDim)
    Icons.chevron(x + w - 14, y + h / 2, 22, true)
    if r.hot then UI.setCursor("hand") end
    if r.clicked then
        if open then
            UI.closePopup()
        else
            local rowH = 26
            local ph = math.min(#options * rowH + 8, 360)
            local selected = index
            local f = Theme.fonts.body
            local widest = 0
            for _, o in ipairs(options) do widest = math.max(widest, f:getWidth(tostring(o))) end
            UI.openPopup(id, x, y + h + 4, math.max(w, opts.popupW or 0, widest + 40), ph, function(p)
                local sy = UI.beginScroll(id .. ":scroll", p.x, p.y + 4, p.w, p.h - 8)
                local close = nil
                for i, o in ipairs(options) do
                    local ry = sy + (i - 1) * rowH
                    local rr = UI.interact(id .. ":opt" .. i, p.x + 4, ry, p.w - 8, rowH)
                    if rr.hot then UI.rect(C.surfaceHi, p.x + 4, ry, p.w - 8, rowH, 5) end
                    if i - 1 == selected then
                        lg.setColor(C.accent)
                        lg.circle("fill", p.x + 14, ry + rowH / 2, 3, 12)
                    end
                    UI.textMid(tostring(o), p.x + 24, ry, rowH, Theme.fonts.body,
                        i - 1 == selected and C.text or C.textDim, "left", p.w - 32)
                    if rr.clicked then
                        UI.data(id).picked = i - 1
                        close = false
                    end
                end
                UI.endScroll(id .. ":scroll", sy + #options * rowH)
                return close
            end, { x, y, w, h })
        end
    end
    local d = UI.data(id)
    if d.picked ~= nil then
        if d.picked ~= index then index, changed = d.picked, true end
        d.picked = nil
    end
    return index, changed
end

function W.enum(id, def, v, x, y, w, opts)
    opts = opts or {}
    local options = def.options or {}
    local changed = false
    local lh = 18
    UI.textMid(def.label, x, y, lh, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w)
    local cy = y + lh + 2
    local h = 26
    local f = Theme.fonts.small
    local total = 0
    for _, o in ipairs(options) do total = total + f:getWidth(o) + 16 end
    if #options <= 5 and total <= w then
        -- segmented control
        UI.rect(C.surface, x, cy, w, h, 6)
        local segW = w / #options
        local selX = UI.anim(id .. ":sel", x + v * segW, 22)
        UI.rect(C.accentSoft, selX + 2, cy + 2, segW - 4, h - 4, 5)
        for i, o in ipairs(options) do
            local sx = x + (i - 1) * segW
            local r = UI.interact(id .. ":" .. i, sx, cy, segW, h)
            if r.clicked and v ~= i - 1 then v, changed = i - 1, true end
            if r.hot then UI.setCursor("hand") end
            UI.textMid(o, sx, cy, h, f, (i - 1 == v) and C.text or C.textDim, "center", segW)
        end
    else
        local nv, ch = W.dropdown(id, options, v, x, cy, w, h)
        if ch then v, changed = nv, true end
    end
    if opts.rclickReset then
        local r = UI.interact(id .. ":lbl", x, y, w, lh)
        if r.rclicked then v, changed = def.default, true end
    end
    UI.tooltip(id .. ":lbl", def.tip)
    return v, changed, lh + h + 8
end

----------------------------------------------------------------------
-- Color
----------------------------------------------------------------------

local function colorPopup(id, value, x, y)
    pickerShaders()
    local d = UI.data(id)
    local h0, s0, v0 = Color.rgbToHsv(value[1], value[2], value[3])
    d.h, d.s, d.v = h0, s0, v0
    d.hex = Color.toHex(value[1], value[2], value[3])
    UI.openPopup(id, x, y, 232, 262, function(p)
        local pad = 12
        local sq = p.w - pad * 2
        local sqH = 150
        local sx, sy = p.x + pad, p.y + pad
        -- SV square
        local r = UI.interact(id .. ":sv", sx, sy, sq, sqH)
        if r.held then
            d.s = math.max(0, math.min(1, (UI.state.mx - sx) / sq))
            d.v = 1 - math.max(0, math.min(1, (UI.state.my - sy) / sqH))
            d.dirty = true
        end
        lg.setShader(svShader)
        svShader:send("hue", d.h)
        lg.setColor(1, 1, 1, 1)
        quad(sx, sy, sq, sqH)
        lg.setShader()
        local kx, ky = sx + d.s * sq, sy + (1 - d.v) * sqH
        lg.setColor(0, 0, 0, 0.5)
        lg.setLineWidth(3)
        lg.circle("line", kx, ky, 6, 20)
        lg.setColor(1, 1, 1, 1)
        lg.setLineWidth(1.5)
        lg.circle("line", kx, ky, 6, 20)
        if r.hot or r.held then UI.setCursor("crosshair") end

        -- Hue bar
        local hy = sy + sqH + 10
        local hr = UI.interact(id .. ":hue", sx, hy - 3, sq, 18)
        if hr.held then
            d.h = math.max(0, math.min(0.9999, (UI.state.mx - sx) / sq))
            d.dirty = true
        end
        lg.setShader(hueShader)
        lg.setColor(1, 1, 1, 1)
        quad(sx, hy, sq, 12)
        lg.setShader()
        local hx = sx + d.h * sq
        lg.setColor(1, 1, 1, 1)
        lg.setLineWidth(2)
        lg.rectangle("line", hx - 3, hy - 2, 6, 16, 2)

        -- Hex + swatch
        local ry = hy + 24
        local rr, rg, rb = Color.hsvToRgb(d.h, d.s, d.v)
        UI.rect({ rr, rg, rb, 1 }, sx, ry, 40, 28, 6)
        local hexId = id .. ":hex"
        if not UI.hasFocus(hexId) and d.dirty then
            d.hex = Color.toHex(rr, rg, rb)
        end
        local text, ev = W.textField(hexId, d.hex, sx + 48, ry, sq - 48, 28, { font = Theme.fonts.mono })
        d.hex = text
        if ev == "submit" then
            local r2, g2, b2 = Color.fromHex(text)
            if r2 then
                d.h, d.s, d.v = Color.rgbToHsv(r2, g2, b2)
                d.dirty = true
            end
        end
        if d.dirty then
            local a, b, c = Color.hsvToRgb(d.h, d.s, d.v)
            d.result = { a, b, c }
            d.dirty = false
        end
    end)
end

function W.color(id, def, v, x, y, w, opts)
    opts = opts or {}
    local h = 26
    local changed = false
    local sw = 64
    local sx = x + w - sw
    UI.textMid(def.label, x, y, h, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w - sw - 70)
    local r = UI.interact(id, x, y, w, h)
    -- checker for alpha-less swatch background
    UI.rect({ v[1], v[2], v[3], 1 }, sx, y + 3, sw, h - 6, 5)
    lg.setColor(1, 1, 1, r.hot and 0.4 or 0.15)
    lg.setLineWidth(1)
    lg.rectangle("line", sx + 0.5, y + 3.5, sw - 1, h - 7, 5)
    UI.textMid(Color.toHex(v[1], v[2], v[3]), sx - 70, y, h, Theme.fonts.monoSmall, C.textFaint, "right", 64)
    if r.hot then UI.setCursor("hand") end
    if r.clicked then
        if UI.popupOpen(id) then UI.closePopup() else colorPopup(id, v, sx - 232 + sw, y + h + 4) end
    end
    if r.rclicked then v, changed = Params.defaultValue(def), true end
    local d = UI.data(id)
    if d.result then
        local nv = { d.result[1], d.result[2], d.result[3] }
        if def.size == 4 then nv[4] = v[4] or 1 end
        v, changed = nv, true
        d.result = nil
    end
    UI.tooltip(id, def.tip)
    return v, changed, h + 6
end

----------------------------------------------------------------------
-- XY pad
----------------------------------------------------------------------

function W.xy(id, def, v, x, y, w, opts)
    opts = opts or {}
    local lh = 18
    local changed = false
    UI.textMid(def.label, x, y, lh, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w - 100)
    UI.textMid(Params.format(def, v), x, y, lh, Theme.fonts.mono, C.textDim, "right", w)
    local ph = opts.padH or 84
    local py = y + lh + 4
    local r = UI.interact(id, x, py, w, ph)
    local lo, hi = def.min, def.max
    if r.held then
        local tx = math.max(0, math.min(1, (UI.state.mx - x) / w))
        local ty = math.max(0, math.min(1, (UI.state.my - py) / ph))
        local nv = { lo + (hi - lo) * tx, lo + (hi - lo) * ty }
        if UI.ctrl() then
            local step = (hi - lo) / 20
            nv[1] = lo + math.floor((nv[1] - lo) / step + 0.5) * step
            nv[2] = lo + math.floor((nv[2] - lo) / step + 0.5) * step
        end
        v, changed = nv, true
    end
    if r.rclicked then v, changed = Params.defaultValue(def), true end
    UI.rect(r.hot and C.surfaceHi or C.surface, x, py, w, ph, 6)
    -- grid
    lg.setColor(1, 1, 1, 0.05)
    for i = 1, 3 do
        lg.line(x + w * i / 4, py + 4, x + w * i / 4, py + ph - 4)
        lg.line(x + 4, py + ph * i / 4, x + w - 4, py + ph * i / 4)
    end
    local tx = (v[1] - lo) / (hi - lo)
    local ty = (v[2] - lo) / (hi - lo)
    local kx, ky = x + tx * w, py + ty * ph
    lg.setColor(C.accent[1], C.accent[2], C.accent[3], 0.35)
    lg.line(kx, py + 2, kx, py + ph - 2)
    lg.line(x + 2, ky, x + w - 2, ky)
    lg.setColor(C.text)
    lg.circle("fill", kx, ky, r.held and 6 or 5, 20)
    if r.hot or r.held then UI.setCursor("crosshair") end
    UI.tooltip(id, (def.tip and def.tip .. "\n\n" or "") .. "Drag to move · Ctrl: snap · Right-click: reset")
    return v, changed, lh + ph + 10
end

-- vec2/3/4 shown as stacked mini sliders
function W.vec(id, def, v, x, y, w, opts)
    opts = opts or {}
    local lh = 18
    local changed = false
    UI.textMid(def.label, x, y, lh, Theme.fonts.small, opts.selected and C.text or C.textDim, "left", w)
    local cy = y + lh + 2
    local names = { "x", "y", "z", "w" }
    local out = Params.copy(v)
    local sub = { kind = "float", min = def.min, max = def.max, step = def.step, default = nil }
    for i = 1, def.size do
        UI.textMid(names[i], x, cy, 16, Theme.fonts.monoSmall, C.textFaint, "left", 12)
        local nv, ch = track(id .. ":" .. i, sub, out[i], x + 16, cy + 1, w - 70, 14)
        if ch then out[i], changed = nv, true end
        UI.textMid(string.format("%.3f", out[i]), x + w - 50, cy, 16, Theme.fonts.monoSmall, C.textDim, "right", 50)
        cy = cy + 20
    end
    local rr = UI.interact(id .. ":lbl", x, y, w, lh)
    if rr.rclicked then out, changed = Params.defaultValue(def), true end
    return changed and Params.clamp(def, out) or v, changed, lh + def.size * 20 + 6
end

----------------------------------------------------------------------
-- Param dispatcher
----------------------------------------------------------------------

function W.param(id, def, v, x, y, w, opts)
    local k = def.kind
    if k == "float" or k == "int" or k == "angle" then
        return W.slider(id, def, v, x, y, w, opts)
    elseif k == "bool" then
        return W.toggle(id, def.label, v, x, y, w, { tip = def.tip, default = def.default, selected = opts and opts.selected })
    elseif k == "enum" then
        return W.enum(id, def, v, x, y, w, { selected = opts and opts.selected, rclickReset = true })
    elseif k == "color" then
        return W.color(id, def, v, x, y, w, opts)
    elseif k == "xy" then
        return W.xy(id, def, v, x, y, w, opts)
    elseif k == "vec" then
        return W.vec(id, def, v, x, y, w, opts)
    end
    return v, false, 0
end

-- Section heading (small caps) with an optional right-side count.
function W.heading(text, x, y, w, right)
    UI.text(text:upper(), x, y, Theme.fonts.heading, C.textFaint)
    if right then
        UI.text(right, x, y, Theme.fonts.heading, C.textFaint, "right", w)
    end
    return 18
end

function W.separator(x, y, w)
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("fill", x, y, w, 1)
end

return W
