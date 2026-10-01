--[[
    App: owns the pipeline, clock and UI state; routes input; exposes the
    actions that panels and shortcuts call.
]]

local Registry = require("src.shaderlib.registry")
local Pipeline = require("src.render.pipeline")
local Clock = require("src.clock")
local Params = require("src.params")
local Presets = require("src.presets")
local Capture = require("src.capture")
local Images = require("src.images")
local FS = require("src.util.fs")
local Backdrop = require("src.backdrop")
local Gallery = require("src.gallery")
local UI = require("src.ui.core")
local Theme = require("src.ui.theme")
local TopBar = require("src.ui.panels.topbar")
local Library = require("src.ui.panels.library")
local ChainPanel = require("src.ui.panels.chain")
local Overlay = require("src.ui.panels.overlay")
local Preview = require("src.ui.preview")
local Settings = require("libs.core.settings")
local Debug = require("libs.core.debug")

local lg = love.graphics

local App = {
    uiVisible = true,
    selected = nil,       -- selected node (source or effect)
    keyParam = 1,         -- keyboard-selected param in the inspector
    compare = false,
    compareSplit = 0.5,
    view = { x = 0, y = 0, w = 1, h = 1 },
    mouse = { 0.5, 0.5, 0, 0 },
    fpsHistory = {},
    leftTab = "library",
}

App.OUTPUT_MODES = {
    { label = "Fit window", w = nil, h = nil },
    { label = "1280 × 720", w = 1280, h = 720 },
    { label = "1920 × 1080", w = 1920, h = 1080 },
    { label = "1080 × 1080", w = 1080, h = 1080 },
    { label = "1080 × 1920", w = 1080, h = 1920 },
}
App.SCALES = { 1, 0.75, 0.5, 0.25 }
App.SPEEDS = { 0.25, 0.5, 1, 2, 4 }

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------

function App.toast(text, kind, path)
    Overlay.toast(text, kind, path)
end

----------------------------------------------------------------------
-- Selection & chain actions
----------------------------------------------------------------------

function App.select(node)
    if App.selected ~= node then
        App.selected = node
        App.keyParam = 1
    end
end

function App.selectedIsSource()
    return App.selected ~= nil and App.selected == App.pipeline.source
end

function App.setSource(entry)
    local node = App.pipeline:setSource(entry)
    App.select(node)
    return node
end

function App.addEffect(entry)
    local p = App.pipeline
    local index = #p.chain + 1
    for i, n in ipairs(p.chain) do
        if n == App.selected then index = i + 1 end
    end
    local node = p:addEffect(entry, index)
    App.select(node)
    return node
end

function App.removeNode(node)
    local p = App.pipeline
    if node == p.source then return end
    local i = p:removeEffect(node)
    if App.selected == node then
        App.select(p.chain[math.min(i or 1, #p.chain)] or p.source)
    end
end

function App.moveSelected(delta)
    local n = App.selected
    if n and n ~= App.pipeline.source then
        App.pipeline:moveEffect(n, delta)
    end
end

-- Select the previous/next node in the chain (source counts as index 0).
function App.cycleSelection(delta)
    local p = App.pipeline
    local list = { p.source }
    for _, n in ipairs(p.chain) do list[#list + 1] = n end
    local idx = 1
    for i, n in ipairs(list) do if n == App.selected then idx = i end end
    idx = math.max(1, math.min(#list, idx + delta))
    App.select(list[idx])
end

-- A/D: swap the selected slot for the previous/next library entry.
function App.swapSelected(delta)
    local p = App.pipeline
    local node = App.selected or p.source
    if not node then return end
    local kind = node.entry.kind
    local list = Registry.list(kind)
    if #list == 0 then return end
    local idx = 0
    for i, e in ipairs(list) do if e == node.entry then idx = i end end
    idx = ((idx - 1 + delta) % #list) + 1
    local e = list[idx]
    if kind == "source" then
        App.setSource(e)
    else
        App.select(p:replaceEffect(node, e))
    end
    App.toast(e.name, "info")
end

function App.visibleParams(node)
    local out = {}
    if not node then return out end
    for _, def in ipairs(node.entry.params or {}) do
        if not def.hidden then out[#out + 1] = def end
    end
    return out
end

function App.nudgeParam(steps)
    local node = App.selected
    local defs = App.visibleParams(node)
    local def = defs[App.keyParam]
    if not def then return end
    node.values[def.name] = Params.nudge(def, node.values[def.name], steps, UI.shift())
end

function App.randomize(node, amount)
    node = node or App.selected
    if not node then return end
    amount = amount or 0.35
    for _, def in ipairs(App.visibleParams(node)) do
        local v = node.values[def.name]
        local k = def.kind
        local function jitter(x, lo, hi)
            local span = (hi - lo) * amount
            return math.max(lo, math.min(hi, x + (love.math.random() * 2 - 1) * span))
        end
        if k == "float" or k == "angle" or k == "int" then
            node.values[def.name] = Params.clamp(def, jitter(v, def.min, def.max))
        elseif k == "color" then
            local c = {}
            for i = 1, def.size do c[i] = jitter(v[i], 0, 1) end
            node.values[def.name] = c
        elseif k == "xy" or k == "vec" then
            local c = {}
            for i = 1, def.size do c[i] = jitter(v[i], def.min, def.max) end
            node.values[def.name] = c
        end
    end
end

----------------------------------------------------------------------
-- Presets
----------------------------------------------------------------------

function App.loadPreset(info)
    local preset, err = Presets.read(info)
    if not preset then
        App.toast("Preset error: " .. tostring(err), "error")
        return
    end
    local ok, warnings = Presets.apply(App.pipeline, preset, Registry)
    if not ok then
        App.toast("Preset error: " .. tostring(warnings), "error")
        return
    end
    App.select(App.pipeline.chain[#App.pipeline.chain] or App.pipeline.source)
    App.currentPreset = preset.name
    for _, w in ipairs(warnings) do App.toast(w, "warn") end
    App.toast("Loaded “" .. (preset.name or info.file) .. "”", "info")
end

function App.savePreset(name)
    if not name or name:match("^%s*$") then return end
    local path, err = Presets.save(App.pipeline, name)
    if path then
        App.currentPreset = name
        App.toast("Saved preset “" .. name .. "”", "ok", path)
    else
        App.toast("Could not save preset: " .. tostring(err), "error")
    end
    Library.refreshPresets()
end

----------------------------------------------------------------------
-- Capture
----------------------------------------------------------------------

function App.screenshot(withUI)
    if withUI then
        Capture.screenshotWindow()
    else
        Capture.screenshot(App.pipeline.outputCanvas)
    end
end

function App.toggleRecording()
    if Capture.recording then
        Capture.stopRecording()
        App.clock:setFixed(nil)
        App.toast("Recording stopped", "info")
    else
        Capture.startRecording(30)
        App.clock:setFixed(30)
        App.toast("Recording at 30 fps (fixed step). F9 to stop.", "record")
    end
end

----------------------------------------------------------------------
-- Output sizing
----------------------------------------------------------------------

function App.setOutputMode(i)
    App.outputMode = math.max(1, math.min(#App.OUTPUT_MODES, i))
    Settings.set("outputMode", App.outputMode)
    App.layoutDirty = true
end

function App.setRenderScale(s)
    App.pipeline:setRenderScale(s)
    Settings.set("renderScale", s)
end

-- Compute the on-screen view rect and keep the output size in step with it.
function App.updateLayout(dt)
    local W, H = lg.getDimensions()
    local mode = App.OUTPUT_MODES[App.outputMode]
    local ow, oh
    if mode.w then
        ow, oh = mode.w, mode.h
    else
        ow, oh = W, H
    end
    local s = math.min(W / ow, H / oh)
    local vw, vh = ow * s, oh * s
    App.view = { x = math.floor((W - vw) / 2), y = math.floor((H - vh) / 2), w = math.floor(vw), h = math.floor(vh) }

    -- Debounce reallocation while the window is being resized.
    local p = App.pipeline
    if p.outW ~= ow or p.outH ~= oh then
        App.resizeTimer = (App.resizeTimer or 0) + dt
        if App.resizeTimer > 0.15 or App.layoutDirty then
            p:setOutputSize(ow, oh)
            App.resizeTimer = 0
        end
    else
        App.resizeTimer = 0
    end
    App.layoutDirty = false
end

----------------------------------------------------------------------
-- Love callbacks
----------------------------------------------------------------------

function App.load(args)
    lg.setDefaultFilter("linear", "linear")
    Theme.load()
    Settings.init({
        renderScale = 1,
        outputMode = 1,
        leftTab = "library",
        dither = true,
    }, "settings.dat")
    Settings.load()

    Images.init()
    Registry.init()
    Registry.onChange(function(entry, event)
        if event == "reloaded" then
            App.toast("Reloaded " .. entry.file, "ok")
        elseif event == "error" then
            local e = entry.errors and entry.errors[1]
            if e then
                local file = (e.file or entry.path):match("([^/]+)$")
                App.toast(string.format("%s:%d  %s", file, e.line or 0, e.msg), "error")
            end
        elseif event == "added" then
            App.toast("New shader: " .. (entry.name or entry.file), "info")
        end
    end)

    Capture.init()
    Capture.onEvent(function(kind, msg, path)
        App.toast(msg, kind == "error" and "error" or (kind == "info" and "info" or "ok"), path)
    end)

    App.clock = Clock.new()
    App.outputMode = Settings.get("outputMode")
    if not App.OUTPUT_MODES[App.outputMode] then App.outputMode = 1 end
    App.pipeline = Pipeline.new({
        width = lg.getWidth(), height = lg.getHeight(),
        renderScale = Settings.get("renderScale"),
    })
    App.pipeline.dither = Settings.get("dither") and 1 or 0
    App.leftTab = Settings.get("leftTab")

    Backdrop.init()
    Gallery.init(App)

    Debug.addGlobalInfo("Output", function()
        local p = App.pipeline
        local w, h = p:workSize()
        return string.format("%dx%d (work %dx%d %s)", p.outW, p.outH, w, h, p.format)
    end)
    Debug.addGlobalInfo("Pool canvases", function() return App.pipeline.pool.allocated end)
    Debug.addGlobalInfo("Chain", function() return #App.pipeline.chain .. " effects" end)

    -- Dev flags: --fresh (ignore session), --shot <seconds> [name] (window
    -- screenshot to the save dir, then quit), --preset <file>, --select <n>
    local fresh = false
    args = args or {}
    for i, a in ipairs(args) do
        if a == "--fresh" then fresh = true end
        if a == "--shot" then
            App.autoShot = { t = tonumber(args[i + 1]) or 3, name = args[i + 2] or "autoshot" }
        end
    end
    local session = not fresh and Presets.loadSession()
    if session and session.source then
        Presets.apply(App.pipeline, session, Registry)
        App.select(App.pipeline.chain[#App.pipeline.chain] or App.pipeline.source)
        if session.extra and session.extra.selected then
            App.select(App.pipeline.chain[session.extra.selected] or App.selected)
        end
    else
        local list = Presets.list()
        local first = list[1]
        if first then
            App.loadPreset(first)
        else
            App.setSource(Registry.get("lua/orbs") or Registry.list("source")[1])
        end
    end

    for i, a in ipairs(args) do
        if a == "--preset" and args[i + 1] then
            for _, info in ipairs(Presets.list()) do
                if info.file == args[i + 1] or info.file == args[i + 1] .. ".lua" then App.loadPreset(info) end
            end
        elseif a == "--select" and args[i + 1] then
            local n = tonumber(args[i + 1])
            App.select(n == 0 and App.pipeline.source or App.pipeline.chain[n] or App.selected)
        elseif a == "--tab" and args[i + 1] then
            App.leftTab = args[i + 1]
        elseif a == "--compare" then
            App.compare = true
        elseif a == "--hide-ui" then
            App.uiVisible = false
        elseif a == "--script" and args[i + 1] then
            App.script = require("src.script")
            App.script.load(args[i + 1], App)
            App.autoShot = App.autoShot or { t = math.huge, name = "unused" } -- don't save the session
        end
    end

    Library.init(App)
    ChainPanel.init(App)
    TopBar.init(App)
    Overlay.init(App)
    Preview.init(App)
    App.updateLayout(1)
end

function App.update(dt)
    if App.script then App.script.update(dt) end
    Registry.poll(dt)
    Capture.update()

    table.insert(App.fpsHistory, dt)
    if #App.fpsHistory > 90 then table.remove(App.fpsHistory, 1) end

    if Gallery.active then
        Gallery.update(dt)
        return
    end

    -- While recording, the clock steps exactly 1/fps per captured frame. When
    -- rendering is faster than that, wait for real time to catch up so the
    -- preview plays at normal speed; when slower, never drop a frame.
    App.renderThisFrame = true
    if Capture.recording then
        local step = 1 / App.clock.fixedFps
        App.recordAcc = (App.recordAcc or 0) + dt
        if App.recordAcc >= step then
            App.recordAcc = math.min(App.recordAcc - step, step)
            App.clock:update(dt)
        else
            App.renderThisFrame = false
        end
    else
        App.recordAcc = 0
        App.clock:update(dt)
    end
    App.updateLayout(dt)

    -- iMouse follows Shadertoy semantics: xy is the last position dragged on
    -- the image (so hovering on the way to the panels changes nothing).
    if App.viewportDrag then
        local mx, my = UI.pointer()
        local v = App.view
        App.mouse[1] = math.max(0, math.min(1, (mx - v.x) / v.w))
        App.mouse[2] = math.max(0, math.min(1, (my - v.y) / v.h))
    end
    App.mouse[3] = App.viewportDrag and 1 or 0
    if App.renderThisFrame then
        local ctx = { time = App.clock.time, dt = App.clock.dt, mouse = App.mouse }
        App.pipeline:update(App.clock.dt, ctx)
    end
    App.mouse[4] = 0
end

function App.draw()
    if Gallery.active then
        Gallery.draw()
        return
    end

    local p = App.pipeline
    local ctx = { time = App.clock.time, dt = App.clock.dt, mouse = { App.mouse[1], App.mouse[2], App.mouse[3], App.clickFlag and 1 or 0 } }
    if App.renderThisFrame ~= false then
        App.clickFlag = false
        p:render(ctx)
        if Capture.recording then
            Capture.recordFrame(p.outputCanvas)
        end
    end

    lg.clear(0.02, 0.02, 0.025, 1)
    local v = App.view
    p:draw(v.x, v.y, v.w, v.h, App.compare and App.compareSplit or nil)

    UI.beginFrame(love.timer.getDelta())
    if App.uiVisible then
        Backdrop.update(p.outputCanvas)
        UI.setBackdrop(Backdrop.image(), v.x, v.y, v.w, v.h)
        Overlay.drawCompare()
        TopBar.draw()
        Library.draw()
        ChainPanel.draw()
        Preview.draw()
    else
        Overlay.drawCompare()
    end
    Overlay.draw()
    UI.endFrame()

    Debug.draw()

    if App.autoShot then
        App.autoShot.t = App.autoShot.t - love.timer.getDelta()
        if App.autoShot.t <= 0 and not App.autoShot.taken then
            App.autoShot.taken = true
            local name = App.autoShot.name
            love.graphics.captureScreenshot(function(data)
                data:encode("png", name .. ".png")
                print("[shot] " .. love.filesystem.getSaveDirectory() .. "/" .. name .. ".png")
                love.event.quit()
            end)
        end
    end
end

function App.resize(w, h)
    App.layoutDirty = false
end

local function shortcuts(key)
    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    local shift = love.keyboard.isDown("lshift", "rshift")
    local p = App.pipeline

    if key == "escape" then
        love.event.quit()
    elseif key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "tab" then
        App.uiVisible = not App.uiVisible
    elseif key == "space" then
        p.bypass = not p.bypass
        App.toast(p.bypass and "Bypass on (source only)" or "Bypass off", "info")
    elseif key == "p" or key == "k" then
        App.clock:togglePause()
    elseif key == "." then
        App.clock:step(1)
    elseif key == "f5" then
        Registry.reloadAll()
        App.toast("Reloaded all shaders", "info")
    elseif key == "f9" then
        App.toggleRecording()
    elseif key == "f12" then
        App.screenshot(shift)
    elseif key == "f3" then
        Debug.toggle()
    elseif key == "g" then
        Gallery.start()
    elseif key == "c" then
        App.compare = not App.compare
    elseif key == "s" and ctrl then
        Library.promptSave()
    elseif key == "r" then
        if App.selected then
            if shift then App.selected:restart() else App.selected:resetParams() end
        end
    elseif key == "x" and App.selected then
        App.randomize(App.selected)
    elseif key == "b" and App.selected and App.selected ~= p.source then
        App.selected.enabled = not App.selected.enabled
    elseif key == "delete" and App.selected then
        App.removeNode(App.selected)
    elseif (key == "up" or key == "down") and ctrl then
        App.moveSelected(key == "up" and -1 or 1)
    elseif key == "[" then
        App.cycleSelection(-1)
    elseif key == "]" then
        App.cycleSelection(1)
    elseif key == "left" or key == "a" then
        App.swapSelected(-1)
    elseif key == "right" or key == "d" then
        App.swapSelected(1)
    elseif key == "up" or key == "w" then
        local n = #App.visibleParams(App.selected)
        if n > 0 then App.keyParam = (App.keyParam - 2) % n + 1 end
    elseif key == "down" or key == "s" then
        local n = #App.visibleParams(App.selected)
        if n > 0 then App.keyParam = App.keyParam % n + 1 end
    elseif key == "=" or key == "e" or key == "kp+" then
        App.nudgeParam(1)
    elseif key == "-" or key == "q" or key == "kp-" then
        App.nudgeParam(-1)
    elseif key == "1" then
        App.setSource(Registry.get("lua/orbs"))
    elseif key == "2" then
        App.setSource(Registry.get("lua/geometry"))
    elseif key == "3" then
        App.setSource(Registry.get("lua/image"))
    elseif key == "4" then
        App.setSource(Registry.get("lua/test_card"))
    end
end

function App.keypressed(key, scancode, isrepeat)
    if Gallery.active then
        Gallery.stop()
        return
    end
    if UI.keypressed(key) then return end
    shortcuts(key)
end

function App.textinput(t)
    UI.textinput(t)
end

function App.mousepressed(x, y, b)
    if Gallery.active then
        Gallery.stop()
        return
    end
    UI.mousepressed(x, y, b)
    if b == 1 and not (App.uiVisible and UI.wantsMouse(x, y)) then
        local v = App.view
        if x >= v.x and x <= v.x + v.w and y >= v.y and y <= v.y + v.h then
            App.viewportDrag = true
            App.clickFlag = true
            App.mouse[1] = (x - v.x) / v.w
            App.mouse[2] = (y - v.y) / v.h
        end
    end
end

function App.mousereleased(x, y, b)
    UI.mousereleased(x, y, b)
    if b == 1 then App.viewportDrag = false end
end

function App.wheelmoved(x, y)
    if UI.wantsMouse() then
        UI.wheelmoved(x, y)
    else
        -- Wheel over the image nudges the keyboard-selected param.
        App.nudgeParam(y > 0 and 1 or -1)
    end
end

function App.filedropped(file)
    local name = file:getFilename()
    if Images.isImageFile(name) then
        local index, err = Images.addDropped(file)
        if not index then
            App.toast("Could not load image: " .. tostring(err), "error")
            return
        end
        local entry = Registry.get("lua/image")
        local node = App.pipeline.source
        if not node or node.entry ~= entry then node = App.setSource(entry) end
        node.values.image = index
        App.toast("Added image “" .. Images.names[index + 1] .. "”", "ok")
    elseif name:match("%.glsl$") then
        file:open("r")
        local text = file:read()
        file:close()
        local kind = text:match("//%s*@kind%s+(%a+)") or (text:find("Texel%s*%(%s*tex") and "effect" or "source")
        local dir = kind == "source" and "shaders/sources/" or "shaders/effects/"
        local base = name:match("([^/\\]+)$")
        local path = FS.writeProject(dir .. base, text)
        if path then
            App.toast("Imported " .. base .. " into " .. dir, "ok", path)
        end
    else
        App.toast("Drop an image (.png, .jpg) or a shader (.glsl)", "warn")
    end
end

function App.quit()
    if App.autoShot then
        Capture.quit()
        return
    end
    local idx
    for i, n in ipairs(App.pipeline.chain) do if n == App.selected then idx = i end end
    Presets.saveSession(App.pipeline, { selected = idx })
    Settings.set("leftTab", App.leftTab)
    Settings.save()
    Capture.quit()
end

return App
