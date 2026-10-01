--[[
    Scripted input for UI smoke tests:  lovec . --script tests/ui_smoke.lua

    A script returns a list of steps, each run when its `at` time (seconds
    since start) has passed:
        { at = 1.0, move = { x, y } }       virtual mouse (the real cursor is untouched)
        { at = 1.1, press = 1 }             mouse button down at the virtual position
        { at = 1.2, release = 1 }
        { at = 1.3, wheel = -2 }
        { at = 1.4, key = "tab" }           key press (ctrl = true / shift = true supported)
        { at = 1.5, text = "hello" }        text input
        { at = 1.6, shot = "name" }         window screenshot to the save dir
        { at = 1.7, check = function(App) return ok, msg end }
        { at = 2.0, quit = true }
    Coordinates may be negative to count from the right/bottom edge.
]]

local UI = require("src.ui.core")

local Script = {}

local steps, index, clock, App
local failures = {}
local heldKeys = {}

function Script.load(path, app)
    App = app
    local chunk, err = love.filesystem.load(path)
    if not chunk then error("script: " .. tostring(err)) end
    steps = chunk()
    index, clock = 1, 0
    UI.state.virtualMouse = { 0, 0 }
    -- Let scripted modifier keys be seen by widgets.
    local isDown = love.keyboard.isDown
    love.keyboard.isDown = function(...)
        for _, k in ipairs({ ... }) do
            if heldKeys[k] then return true end
        end
        return isDown(...)
    end
end

function Script.active()
    return steps ~= nil
end

local function resolve(x, y)
    local w, h = love.graphics.getDimensions()
    if x < 0 then x = w + x end
    if y < 0 then y = h + y end
    return x, y
end

-- Find the center of the first widget whose id matches a Lua pattern.
local function findWidget(pattern)
    local best
    for id, r in pairs(UI.state.rects or {}) do
        if id:match(pattern) then
            if not best or id < best.id then best = { id = id, r = r } end
        end
    end
    if not best then return nil end
    local r = best.r
    return r[1] + r[3] / 2, r[2] + r[4] / 2, best.id
end

-- Insert follow-up steps (used by click/drag) right after the current one.
local function insertSteps(list)
    for i = #list, 1, -1 do
        table.insert(steps, index, list[i])
    end
end

-- spec: widget id pattern | {x, y} | {dx=, dy=} (relative to `from`) | function(App) -> spec
local function target(spec, fromX, fromY)
    if type(spec) == "function" then spec = spec(App) end
    if type(spec) == "table" then
        if spec.dx then return fromX + spec.dx, fromY + (spec.dy or 0) end
        return resolve(spec[1], spec[2])
    end
    if type(spec) ~= "string" then return nil end
    return findWidget(spec)
end

function Script.update(dt)
    if not steps then return end
    -- Fixed step so hitches (shader compiles, screenshots) can't bunch steps
    -- together, and at most one input event per frame so the UI sees each.
    clock = clock + 1 / 60
    local handledInput = false
    while steps[index] and clock >= (steps[index].at or 0) do
        local nxt = steps[index]
        local isInput = nxt.press or nxt.release or nxt.click or nxt.drag or nxt.key or nxt.text or nxt.wheel
        if isInput and handledInput then break end
        handledInput = handledInput or isInput ~= nil
        local s = steps[index]
        index = index + 1
        if os.getenv("SCRIPT_TRACE") then
            print(string.format("    [%.3f] step at=%.3f %s%s%s%s", clock, s.at or 0, s.click and ("click " .. tostring(s.click)) or "",
                s.press and "press" or "", s.release and "release" or "", s.move and "move" or ""))
        end
        local vm = UI.state.virtualMouse
        if s.move then
            vm[1], vm[2] = resolve(s.move[1], s.move[2])
        end
        if s.click then
            local x, y, id = target(s.click)
            if x then
                vm[1], vm[2] = x, y
                local b = s.button or 1
                if s.double then
                    insertSteps({
                        { at = clock + 0.03, press = b }, { at = clock + 0.06, release = b },
                        { at = clock + 0.09, press = b }, { at = clock + 0.12, release = b },
                    })
                else
                    insertSteps({ { at = clock + 0.03, press = b }, { at = clock + 0.08, release = b } })
                end
            else
                print("  FAIL no widget matches '" .. tostring(s.click) .. "'")
                table.insert(failures, "no widget " .. tostring(s.click))
            end
        end
        if s.drag then
            local x1, y1 = target(s.drag[1])
            local x2, y2
            if x1 then x2, y2 = target(s.drag[2], x1, y1) end
            if x1 and x2 then
                vm[1], vm[2] = x1, y1
                local list = { { at = clock + 0.03, press = 1 } }
                for k = 1, 8 do
                    local t = k / 8
                    list[#list + 1] = { at = clock + 0.03 + k * 0.03, move = { x1 + (x2 - x1) * t, y1 + (y2 - y1) * t } }
                end
                list[#list + 1] = { at = clock + 0.35, release = 1 }
                insertSteps(list)
            else
                print("  FAIL drag target missing")
                table.insert(failures, "drag target missing")
            end
        end
        if s.ctrl ~= nil then heldKeys.lctrl = s.ctrl or nil end
        if s.shift ~= nil then heldKeys.lshift = s.shift or nil end
        if s.press then App.mousepressed(vm[1], vm[2], s.press) end
        if s.release then App.mousereleased(vm[1], vm[2], s.release) end
        if s.wheel then App.wheelmoved(0, s.wheel) end
        if s.key then App.keypressed(s.key) end
        if s.text then App.textinput(s.text) end
        if s.check then
            local ok, msg = s.check(App)
            print((ok and "  ok   " or "  FAIL ") .. (msg or ("step " .. (index - 1))))
            if not ok then table.insert(failures, msg or ("step " .. (index - 1))) end
        end
        if s.shot then
            local name = s.shot
            love.graphics.captureScreenshot(function(data)
                data:encode("png", name .. ".png")
                print("[script] shot " .. love.filesystem.getSaveDirectory() .. "/" .. name .. ".png")
            end)
        end
        if s.quit then
            print(#failures == 0 and "[script] OK" or ("[script] FAILED (" .. #failures .. ")"))
            love.event.quit(#failures == 0 and 0 or 1)
        end
    end
end

return Script
