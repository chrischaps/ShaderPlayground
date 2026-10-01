--[[
    Render every curated preset full-window, UI hidden, to the save folder
    (showcase_<file>.png). Handy for checking looks and for README images.

        lovec . --fresh --hide-ui --script tests/showcase_shots.lua
]]

local Presets = require("src.presets")

local steps = {}
local t = 0.5
for _, info in ipairs(Presets.list()) do
    if info.gallery then
        steps[#steps + 1] = { at = t, check = function(App)
            App.loadPreset(info)
            App.clock:reset()
            return true, "load " .. info.name
        end }
        -- let simulations and feedback develop before the shot
        steps[#steps + 1] = { at = t + 3.5, shot = "showcase_" .. info.file:gsub("%.lua$", "") }
        t = t + 4
    end
end
steps[#steps + 1] = { at = t + 0.5, quit = true }
return steps
