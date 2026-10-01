--[[
    Shader Playground
    A tool for building, stacking and tweaking GLSL effects in LÖVE.

    Run:       love .
    Self test: lovec . --selftest

    Shaders live in shaders/sources and shaders/effects and hot-reload on
    save. See README.md for the file format and controls.
]]

local App

function love.load(args)
    for _, a in ipairs(args or {}) do
        if a == "--selftest" then
            local ok = require("src.selftest").run()
            love.event.quit(ok and 0 or 1)
            return
        end
    end
    App = require("src.app")
    App.load(args)
end

local callbacks = {
    "update", "draw", "keypressed", "keyreleased", "textinput",
    "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
    "resize", "filedropped", "directorydropped", "focus", "quit",
}

for _, name in ipairs(callbacks) do
    love[name] = function(...)
        if App and App[name] then return App[name](...) end
    end
end
